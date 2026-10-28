import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../core/lifecycle.dart';
import '../core/local_store.dart';
import '../core/supa.dart';
import '../models/conversation.dart';
import '../models/group_message.dart' show SendState;

/// Ad chats list with unread counters, updated live (Realtime on conversations).
class Inbox extends ChangeNotifier with WidgetsBindingObserverMixin {
  Inbox._();
  static final instance = Inbox._();

  List<Conversation> items = [];
  bool loading = false;
  RealtimeChannel? _channel;
  Timer? _debounce;
  int? openConversation; // the thread on screen doesn't count as unread

  int get unreadTotal => items.where((c) => c.id != openConversation).fold(0, (a, c) => a + c.unread);

  void start() {
    final cached = LocalStore.getJson('u:inbox');
    if (cached is List) {
      items = cached.whereType<Map<String, dynamic>>().map(Conversation.fromJson).toList();
      notifyListeners();
    }
    refresh();
    _channel = supa
        .channel('inbox:${myId ?? ''}')
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'conversations', callback: (_) => _soon())
        .subscribe((status, _) {
      if (status == RealtimeSubscribeStatus.subscribed) _soon();
    });
    bindLifecycle(onResume: refresh);
  }

  void stop() {
    unbindLifecycle();
    final ch = _channel;
    if (ch != null) unawaited(supa.removeChannel(ch));
    _channel = null;
    items = [];
  }

  void _soon() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), refresh);
  }

  Future<void> refresh() async {
    if (myId == null) return;
    loading = true;
    try {
      final rows = await supa.rpc('chat_list') as List<dynamic>;
      items = rows.cast<Map<String, dynamic>>().map(Conversation.fromJson).toList();
      unawaited(LocalStore.setJson('u:inbox', items.map((c) => c.toJson()).toList()));
    } catch (e) {
      debugPrint('inbox: $e');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> hide(Conversation c) async {
    items = items.where((x) => x.id != c.id).toList();
    notifyListeners();
    await supa.rpc('conversation_hide', params: {'p_conv': c.id});
  }

  Future<int> start_(int adId) async => (await supa.rpc('conversation_start', params: {'p_ad': adId}) as num).toInt();
}

/// One ad chat: messages with instant local echo, live delivery, ✓✓ when the other side has read.
class DmThread extends ChangeNotifier with WidgetsBindingObserverMixin {
  DmThread(this.conversationId);
  final int conversationId;

  final List<DmMessage> messages = [];
  Map<String, dynamic>? conv;
  DateTime otherReadAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool otherTyping = false;
  bool loading = true;
  bool hasMore = false;
  String? error;
  RealtimeChannel? _channel;
  Timer? _typingOff, _readTimer;
  DateTime _lastTyping = DateTime.fromMillisecondsSinceEpoch(0);
  bool _disposed = false;

  String get _cacheKey => 'u:dm:$conversationId';
  String? get otherId => conv == null ? null : (conv!['buyer_id'] == myId ? conv!['seller_id'] : conv!['buyer_id']) as String?;
  bool get iAmSeller => conv?['seller_id'] == myId;
  DateTime? get myHiddenAt {
    final v = iAmSeller ? (conv?['seller_hidden_at']) : (conv?['buyer_hidden_at']);
    return v == null ? null : DateTime.parse(v as String);
  }

  bool isSeen(DmMessage m) => m.id > 0 && !otherReadAt.isBefore(m.createdAt);

  Future<void> start() async {
    Inbox.instance.openConversation = conversationId;
    final cached = LocalStore.getJson(_cacheKey);
    if (cached is List) {
      messages.addAll(cached.whereType<Map<String, dynamic>>().map(DmMessage.fromJson));
      loading = messages.isEmpty;
      _notify();
    }
    _subscribe();
    await reload();
    bindLifecycle(onResume: reload);
  }

  Future<void> reload() async {
    try {
      conv = await supa.from('conversations').select().eq('id', conversationId).single();
      _readOther();
      var q = supa.from('dm_messages').select().eq('conversation_id', conversationId);
      final hidden = myHiddenAt;
      if (hidden != null) q = q.gt('created_at', hidden.toIso8601String());
      final rows = await q.order('id', ascending: false).limit(201);
      hasMore = rows.length > 200;
      final fresh = rows.take(200).map(DmMessage.fromJson).toList().reversed.toList();
      final locals = messages.where((m) => m.id < 0 && !fresh.any((f) => f.clientId == m.clientId)).toList();
      messages
        ..clear()
        ..addAll(fresh)
        ..addAll(locals);
      error = null;
      _persist();
      markRead();
    } catch (e) {
      error = errorText(e);
    } finally {
      loading = false;
      _notify();
    }
  }

  void _readOther() {
    final v = iAmSeller ? (conv?['buyer_read_at']) : (conv?['seller_read_at']);
    if (v != null) otherReadAt = DateTime.parse(v as String);
  }

  void _subscribe() {
    final filter = PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'conversation_id', value: conversationId);
    _channel = supa
        .channel('dm:$conversationId', opts: const RealtimeChannelConfig(self: false))
        .onPostgresChanges(event: PostgresChangeEvent.insert, schema: 'public', table: 'dm_messages', filter: filter, callback: (p) => _onRow(p.newRecord))
        .onPostgresChanges(event: PostgresChangeEvent.update, schema: 'public', table: 'dm_messages', filter: filter, callback: (p) => _onRow(p.newRecord))
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'conversations',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'id', value: conversationId),
          callback: (p) {
            conv = p.newRecord;
            _readOther();
            _notify();
          },
        )
        .onBroadcast(
          event: 'typing',
          callback: (raw) {
            final p = raw['payload'] is Map ? Map<String, dynamic>.from(raw['payload'] as Map) : raw;
            if (p['user_id'] == myId) return;
            otherTyping = true;
            _typingOff?.cancel();
            _typingOff = Timer(const Duration(seconds: 5), () {
              otherTyping = false;
              _notify();
            });
            _notify();
          },
        )
        .subscribe((status, _) {
      if (status == RealtimeSubscribeStatus.subscribed && !loading) reload();
    });
  }

  void _onRow(Map<String, dynamic> row) {
    if (row.isEmpty) return;
    final m = DmMessage.fromJson(row);
    final i = messages.indexWhere((x) => x.id == m.id || (m.senderId == myId && x.clientId == m.clientId));
    if (i >= 0) {
      messages[i] = m;
    } else {
      messages.add(m);
      if (m.senderId != myId) {
        otherTyping = false;
        markRead();
      }
    }
    _persist();
    _notify();
  }

  void markRead() {
    if (_readTimer != null) return;
    _readTimer = Timer(const Duration(milliseconds: 500), () async {
      _readTimer = null;
      try {
        await supa.rpc('conversation_read', params: {'p_conv': conversationId});
        unawaited(Inbox.instance.refresh());
      } catch (_) {}
    });
  }

  void typing() {
    final now = DateTime.now();
    if (now.difference(_lastTyping).inMilliseconds < 2500) return;
    _lastTyping = now;
    unawaited(_channel?.sendBroadcastMessage(event: 'typing', payload: {'user_id': myId}));
  }

  int _seq = -1;

  Future<void> send(String text, {int? replyTo}) async {
    final body = text.trim();
    if (body.isEmpty) return;
    final m = DmMessage(id: _seq--, clientId: const Uuid().v4(), conversationId: conversationId, senderId: myId!, body: body, replyToId: replyTo, createdAt: DateTime.now(), state: SendState.sending);
    messages.add(m);
    _notify();
    await _deliver(m);
  }

  Future<void> retry(DmMessage m) async {
    final i = messages.indexWhere((x) => x.clientId == m.clientId);
    if (i >= 0) messages[i] = m.copyWith(state: SendState.sending);
    _notify();
    await _deliver(m);
  }

  Future<void> _deliver(DmMessage m) async {
    try {
      final row = await supa
          .from('dm_messages')
          .upsert({'conversation_id': conversationId, 'client_id': m.clientId, 'body': m.body, 'reply_to_id': m.replyToId}, onConflict: 'sender_id,client_id', ignoreDuplicates: true)
          .select()
          .maybeSingle();
      if (row != null) _onRow(row);
    } catch (e) {
      final i = messages.indexWhere((x) => x.clientId == m.clientId);
      if (e is PostgrestException && e.code == 'P0001') {
        if (i >= 0) messages.removeAt(i);
        error = e.message;
      } else if (i >= 0) {
        messages[i] = m.copyWith(state: SendState.failed);
      }
      _notify();
    }
  }

  Future<void> edit(DmMessage m, String text) async {
    await supa.rpc('dm_action', params: {'p_id': m.id, 'p_action': 'edit', 'p_body': text});
  }

  Future<void> delete(DmMessage m) async {
    await supa.rpc('dm_action', params: {'p_id': m.id, 'p_action': 'delete'});
  }

  void discard(DmMessage m) {
    messages.removeWhere((x) => x.clientId == m.clientId);
    _notify();
  }

  void _persist() {
    final keep = messages.where((m) => m.id > 0).toList();
    final tail = keep.length > 80 ? keep.sublist(keep.length - 80) : keep;
    unawaited(LocalStore.setJson(_cacheKey, tail.map((m) => m.toJson()).toList()));
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    if (Inbox.instance.openConversation == conversationId) Inbox.instance.openConversation = null;
    unbindLifecycle();
    _typingOff?.cancel();
    _readTimer?.cancel();
    final ch = _channel;
    if (ch != null) unawaited(supa.removeChannel(ch));
    super.dispose();
  }
}
