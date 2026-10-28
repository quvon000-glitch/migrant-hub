import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../core/lifecycle.dart';
import '../core/local_store.dart';
import '../core/supa.dart';
import '../models/group_message.dart';
import 'profiles.dart';

const groupCities = {
  'moskva': (name: 'Moskva', region: 'Moskva va Moskva viloyati', initials: 'MSK'),
  'spb': (name: 'Sankt-Peterburg', region: 'Sankt-Peterburg va Leningrad viloyati', initials: 'SPB'),
};

const groupRules = [
  'Bank kartasi sotib olish, sotish yoki ijaraga berish e’lonlari taqiqlangan.',
  'Kunlik 8 000 ₽ dan yuqori ish haqi va’da qilingan e’lonlar taqiqlangan.',
  'Fohishabozlik va intim xizmatlar reklamasi uchun darhol doimiy ban beriladi.',
  'Havola joylashga faqat admin ruxsat etilgan.',
  'Bir xil e’lonni kuniga ko‘pi bilan 3 marta joylash mumkin.',
  'Ovozli xabar: kuniga 1 ta, 30 soniyagacha. Video: 60 soniyagacha.',
  'Yangi hisoblar birinchi 24 soat faqat matn yozadi.',
  'Qoida buzilsa: ogohlantirish → 24 soat → 7 kun → doimiy ban.',
  'Xabarlar 48 soatdan keyin o‘chadi (mahkamlanganlari qoladi).',
];

const groupReportReasons = ['Firibgarlik', 'Bank karta reklamasi', 'Fohishabozlik reklamasi', 'Spam yoki takror e’lon', 'Haqorat', 'Boshqa'];

class GroupMe {
  final bool isAdmin;
  final String? blockedText;
  final DateTime? textOnlyUntil;
  final int voiceLeftToday;
  const GroupMe({this.isAdmin = false, this.blockedText, this.textOnlyUntil, this.voiceLeftToday = 0});

  factory GroupMe.fromJson(Map<String, dynamic> j) => GroupMe(
        isAdmin: j['is_admin'] as bool? ?? false,
        blockedText: j['blocked_text'] as String?,
        textOnlyUntil: j['text_only_until'] == null ? null : DateTime.parse(j['text_only_until'] as String),
        voiceLeftToday: (j['voice_left_today'] as num?)?.toInt() ?? 0,
      );

  bool get textOnly => textOnlyUntil != null && textOnlyUntil!.isAfter(DateTime.now());
}

/// One city group: messages, live updates, sending with instant local echo, read receipts,
/// typing indicator and online counter. Works offline from the last cached page.
class GroupChat extends ChangeNotifier with WidgetsBindingObserverMixin {
  GroupChat(this.city);
  final String city;

  static const pageSize = 50;
  static const ttl = Duration(hours: 48);

  final List<GroupMessage> _all = [];
  final Set<int> saved = {};
  GroupMe me = const GroupMe();
  GroupMessage? pinned;
  int members = 0;
  int unread = 0;
  int online = 0;
  DateTime othersReadAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool loading = true;
  bool loadingOlder = false;
  bool hasMore = true;
  bool connected = false;
  String? error;
  final Map<String, DateTime> _typing = {};

  RealtimeChannel? _channel;
  Timer? _readTimer, _typingTick;
  DateTime _lastTypingSent = DateTime.fromMillisecondsSinceEpoch(0);
  bool _disposed = false;
  bool _visible = false;

  /// Messages from others that arrived while the list was not at the bottom.
  final _incoming = StreamController<GroupMessage>.broadcast();
  Stream<GroupMessage> get onIncoming => _incoming.stream;
  final _notices = StreamController<String>.broadcast();
  Stream<String> get notices => _notices.stream;

  String get _cacheKey => 'u:group:$city';

  List<GroupMessage> get messages => _all.where(_shown).toList(growable: false);

  bool _shown(GroupMessage m) {
    if (m.deleted) return false;
    if (m.hidden && m.userId != myId && !me.isAdmin) return false;
    if (!m.pinned && !m.isLocal && DateTime.now().difference(m.createdAt) > ttl) return false;
    return true;
  }

  List<String> get typingNames {
    final now = DateTime.now();
    _typing.removeWhere((_, until) => until.isBefore(now));
    return _typing.keys.map((id) => Profiles.instance.of(id).displayName).toList();
  }

  GroupMessage? byId(int id) {
    for (final m in _all) {
      if (m.id == id) return m;
    }
    return null;
  }

  bool isSeen(GroupMessage m) => !m.isLocal && !othersReadAt.isBefore(m.createdAt);

  // ---------------- lifecycle ----------------

  Future<void> start() async {
    final cached = LocalStore.getJson(_cacheKey);
    if (cached is List) {
      _all
        ..clear()
        ..addAll(cached.whereType<Map<String, dynamic>>().map(GroupMessage.fromJson));
      loading = _all.isEmpty;
      _notify();
    }
    _subscribe();
    await reload();
    bindLifecycle(onResume: () => _catchUp(full: true));
    _typingTick = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_typing.isNotEmpty) _notify();
    });
  }

  Future<void> reload() async {
    try {
      final rows = await supa.from('group_messages').select().eq('city', city).order('id', ascending: false).limit(pageSize + 1);
      final page = rows.map(GroupMessage.fromJson).toList();
      hasMore = page.length > pageSize;
      final fresh = page.take(pageSize).toList().reversed.toList();
      final locals = _all.where((m) => m.isLocal).toList();
      _all
        ..clear()
        ..addAll(fresh)
        ..addAll(locals.where((l) => !fresh.any((f) => f.clientId == l.clientId)));
      error = null;
      await Future.wait([_loadState(), _loadPinned(), _loadSaved()]);
      await Profiles.instance.ensure(_all.map((m) => m.userId));
      _persist();
      markRead();
    } catch (e) {
      error = errorText(e);
    } finally {
      loading = false;
      _notify();
    }
  }

  Future<void> _loadState() async {
    final s = await supa.rpc('group_state', params: {'p_city': city}) as Map<String, dynamic>;
    members = (s['members'] as num?)?.toInt() ?? 0;
    final o = s['others_read_at'];
    if (o != null) othersReadAt = DateTime.parse(o as String);
    unread = _visible ? 0 : (s['unread'] as num?)?.toInt() ?? 0;
    if (s['me'] is Map<String, dynamic>) me = GroupMe.fromJson(s['me'] as Map<String, dynamic>);
  }

  Future<void> _loadPinned() async {
    final row = await supa.from('group_messages').select().eq('city', city).not('pinned_at', 'is', null).isFilter('deleted_at', null).order('pinned_at', ascending: false).limit(1).maybeSingle();
    pinned = row == null ? null : GroupMessage.fromJson(row);
  }

  Future<void> _loadSaved() async {
    final rows = await supa.from('group_saved').select('message_id');
    saved
      ..clear()
      ..addAll(rows.map((r) => (r['message_id'] as num).toInt()));
  }

  Future<void> loadOlder() async {
    if (loadingOlder || !hasMore) return;
    final oldest = _all.where((m) => !m.isLocal).map((m) => m.id).fold<int?>(null, (a, b) => a == null || b < a ? b : a);
    if (oldest == null) return;
    loadingOlder = true;
    _notify();
    try {
      final rows = await supa.from('group_messages').select().eq('city', city).lt('id', oldest).order('id', ascending: false).limit(pageSize + 1);
      final page = rows.map(GroupMessage.fromJson).toList();
      hasMore = page.length > pageSize;
      _all.insertAll(0, page.take(pageSize).toList().reversed);
      await Profiles.instance.ensure(page.map((m) => m.userId));
    } catch (e) {
      _notices.add(errorText(e));
    } finally {
      loadingOlder = false;
      _notify();
    }
  }

  /// After a reconnect or coming back to the app: fetch what was missed.
  Future<void> _catchUp({bool full = false}) async {
    final last = _all.where((m) => !m.isLocal).map((m) => m.id).fold<int>(0, (a, b) => b > a ? b : a);
    if (last == 0 || full) {
      await reload();
      return;
    }
    try {
      final rows = await supa.from('group_messages').select().eq('city', city).gt('id', last).order('id').limit(200);
      for (final r in rows) {
        _upsert(GroupMessage.fromJson(r));
      }
      await _loadState();
      _persist();
      _notify();
    } catch (_) {}
  }

  void _subscribe() {
    final ch = supa.channel('group:$city', opts: const RealtimeChannelConfig(self: false));
    ch
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'group_messages',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'city', value: city),
          callback: (p) => _onRow(p.newRecord, inserted: true),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'group_messages',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'city', value: city),
          callback: (p) => _onRow(p.newRecord, inserted: false),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'group_members',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'city', value: city),
          callback: (p) {
            final r = p.newRecord;
            if (r.isEmpty || r['user_id'] == myId) return;
            final t = DateTime.parse(r['last_read_at'] as String);
            if (t.isAfter(othersReadAt)) {
              othersReadAt = t;
              _notify();
            }
            if (p.eventType == PostgresChangeEvent.insert) members++;
          },
        )
        .onBroadcast(
          event: 'typing',
          callback: (raw) {
            final p = raw['payload'] is Map ? Map<String, dynamic>.from(raw['payload'] as Map) : raw;
            final uid = p['user_id'] as String?;
            if (uid == null || uid == myId) return;
            _typing[uid] = DateTime.now().add(const Duration(seconds: 5));
            _notify();
          },
        )
        .onPresenceSync((_) {
          final ids = <String>{};
          for (final s in ch.presenceState()) {
            for (final p in s.presences) {
              final id = p.payload['user_id'];
              if (id is String) ids.add(id);
            }
          }
          online = ids.length;
          _notify();
        })
        .subscribe((status, err) async {
          final was = connected;
          connected = status == RealtimeSubscribeStatus.subscribed;
          if (connected) {
            await ch.track({'user_id': myId});
            if (!was && !loading) unawaited(_catchUp());
          }
          _notify();
        });
    _channel = ch;
  }

  void _onRow(Map<String, dynamic> row, {required bool inserted}) {
    if (row.isEmpty) return;
    final m = GroupMessage.fromJson(row);
    final isNew = inserted && !_all.any((x) => x.id == m.id || (x.clientId == m.clientId && m.userId == myId));
    _upsert(m);
    if (m.pinned) pinned = m;
    if (pinned?.id == m.id && (!m.pinned || m.deleted)) pinned = null;
    if (isNew && m.userId != myId) {
      _typing.remove(m.userId);
      Profiles.instance.of(m.userId);
      _incoming.add(m);
      if (!_visible && !m.hidden) unread++;
      markRead();
    }
    _persist();
    _notify();
  }

  /// Replaces the local echo (same client id) or an older copy, keeps the list ordered.
  void _upsert(GroupMessage m) {
    final i = _all.indexWhere((x) => x.id == m.id || (m.userId == myId && x.clientId == m.clientId));
    if (i >= 0) {
      _all[i] = m;
    } else {
      final at = _all.indexWhere((x) => x.isLocal || x.id > m.id);
      if (at < 0) {
        _all.add(m);
      } else {
        _all.insert(at, m);
      }
    }
  }

  void setVisible(bool v) {
    _visible = v;
    if (v) markRead();
  }

  /// Read receipts: one request per burst of incoming messages, only while the chat is on screen.
  void markRead() {
    if (!_visible) return;
    if (unread != 0) {
      unread = 0;
      _notify();
    }
    if (_readTimer != null) return;
    _readTimer = Timer(const Duration(milliseconds: 700), () async {
      _readTimer = null;
      try {
        await supa.rpc('group_mark_read', params: {'p_city': city});
      } catch (_) {}
    });
  }

  void typing() {
    final now = DateTime.now();
    if (now.difference(_lastTypingSent).inMilliseconds < 2500 || !connected) return;
    _lastTypingSent = now;
    unawaited(_channel?.sendBroadcastMessage(event: 'typing', payload: {'user_id': myId}));
  }

  // ---------------- sending ----------------

  int _localSeq = -1;

  GroupMessage _local(String kind, String body, {int? replyTo, String? file, int? duration, int? w, int? h}) => GroupMessage(
        id: _localSeq--,
        clientId: const Uuid().v4(),
        city: city,
        userId: myId!,
        kind: kind,
        body: body,
        replyToId: replyTo,
        durationSec: duration,
        width: w,
        height: h,
        createdAt: DateTime.now(),
        state: SendState.sending,
        localFile: file,
      );

  Future<void> sendText(String text, {int? replyTo}) async {
    final body = text.trim();
    if (body.isEmpty) return;
    final m = _local('text', body, replyTo: replyTo);
    _all.add(m);
    _notify();
    await _deliver(m);
  }

  Future<void> sendMedia(String kind, File file, {String caption = '', int? replyTo, int? duration, int? width, int? height}) async {
    final m = _local(kind, caption.trim(), replyTo: replyTo, file: file.path, duration: duration, w: width, h: height);
    _all.add(m);
    _notify();
    await _deliver(m);
  }

  Future<void> retry(GroupMessage m) async {
    _replaceLocal(m.copyWith(state: SendState.sending));
    await _deliver(_all.firstWhere((x) => x.clientId == m.clientId));
  }

  void discard(GroupMessage m) {
    _all.removeWhere((x) => x.clientId == m.clientId);
    _notify();
  }

  Future<void> _deliver(GroupMessage m) async {
    try {
      String? mediaPath, thumbPath;
      if (m.kind != 'text' && m.localFile != null) {
        mediaPath = await _upload(File(m.localFile!), m.kind);
      }
      final res = await supa.rpc('group_send', params: {
        'p_city': city,
        'p_kind': m.kind,
        'p_body': m.body,
        'p_client_id': m.clientId,
        'p_media_path': mediaPath,
        'p_thumb_path': thumbPath,
        'p_duration_sec': m.durationSec,
        'p_reply_to': m.replyToId,
        'p_width': m.width,
        'p_height': m.height,
      }) as Map<String, dynamic>;
      if (res['error'] != null) {
        _all.removeWhere((x) => x.clientId == m.clientId);
        _notices.add(res['error'] as String);
        unawaited(_loadState());
        _notify();
        return;
      }
      _upsert(GroupMessage.fromJson(res['message'] as Map<String, dynamic>));
      if (m.kind == 'voice') me = GroupMe(isAdmin: me.isAdmin, blockedText: me.blockedText, textOnlyUntil: me.textOnlyUntil, voiceLeftToday: (me.voiceLeftToday - 1).clamp(0, 99));
      _persist();
      _notify();
    } catch (e) {
      final text = errorText(e);
      final rejected = e is PostgrestException && e.code == 'P0001';
      if (rejected) {
        _all.removeWhere((x) => x.clientId == m.clientId);
        _notices.add(text);
      } else {
        _replaceLocal(m.copyWith(state: SendState.failed, error: text));
      }
      _notify();
    }
  }

  void _replaceLocal(GroupMessage m) {
    final i = _all.indexWhere((x) => x.clientId == m.clientId);
    if (i >= 0) _all[i] = m;
    _notify();
  }

  Future<String> _upload(File file, String kind) async {
    final uid = myId!;
    final id = const Uuid().v4();
    if (kind == 'image') {
      final bytes = await FlutterImageCompress.compressWithFile(file.path, minWidth: 1600, minHeight: 1600, quality: 82);
      final path = '$uid/$id.jpg';
      await supa.storage.from('chat-media').uploadBinary(path, bytes ?? await file.readAsBytes(), fileOptions: const FileOptions(contentType: 'image/jpeg', cacheControl: '31536000'));
      return path;
    }
    if (kind == 'video') {
      final path = '$uid/$id.mp4';
      await supa.storage.from('chat-media').upload(path, file, fileOptions: const FileOptions(contentType: 'video/mp4', cacheControl: '31536000'));
      return path;
    }
    final path = '$uid/$id.m4a';
    await supa.storage.from('chat-media').upload(path, file, fileOptions: const FileOptions(contentType: 'audio/mp4', cacheControl: '31536000'));
    return path;
  }

  // ---------------- actions ----------------

  Future<String?> _action(int id, String action, {String? body, String? rule}) async {
    final res = await supa.rpc('group_action', params: {'p_id': id, 'p_action': action, 'p_body': body, 'p_rule': rule}) as Map<String, dynamic>;
    if (res['error'] != null) throw PostgrestException(message: res['error'] as String, code: 'P0001');
    return res['note'] as String?;
  }

  Future<void> edit(GroupMessage m, String text) async {
    final old = m;
    _replace(m.copyWith(body: text.trim(), editedAt: DateTime.now()));
    try {
      await _action(m.id, 'edit', body: text);
    } catch (e) {
      _replace(old);
      rethrow;
    }
  }

  Future<void> delete(GroupMessage m) async {
    final i = _all.indexWhere((x) => x.id == m.id);
    final old = i >= 0 ? _all[i] : null;
    if (i >= 0) _all.removeAt(i);
    if (pinned?.id == m.id) pinned = null;
    _notify();
    try {
      await _action(m.id, 'delete');
      _persist();
    } catch (e) {
      if (old != null) _upsert(old);
      _notify();
      rethrow;
    }
  }

  Future<String?> punish(GroupMessage m, String rule) async {
    _all.removeWhere((x) => x.id == m.id);
    _notify();
    return _action(m.id, 'punish', rule: rule);
  }

  Future<void> toggleSave(GroupMessage m) async {
    if (saved.contains(m.id)) {
      saved.remove(m.id);
      _notify();
      await supa.from('group_saved').delete().eq('message_id', m.id).eq('user_id', myId!);
    } else {
      saved.add(m.id);
      _notify();
      await _action(m.id, 'save');
    }
  }

  Future<void> pin(GroupMessage m, bool on) async {
    await _action(m.id, on ? 'pin' : 'unpin');
    pinned = on ? m : null;
    _notify();
  }

  Future<void> restore(GroupMessage m) => _action(m.id, 'restore');

  Future<void> report(GroupMessage m, String reason) async {
    await supa.rpc('group_report', params: {'p_id': m.id, 'p_reason': reason});
  }

  void _replace(GroupMessage m) {
    final i = _all.indexWhere((x) => x.id == m.id);
    if (i >= 0) _all[i] = m;
    _notify();
  }

  /// Search / filters (server side, newest first).
  Future<List<GroupMessage>> search({String q = '', String filter = 'all'}) async {
    var query = supa.from('group_messages').select().eq('city', city).isFilter('deleted_at', null);
    if (q.trim().isNotEmpty) query = query.ilike('body', '%${q.trim().replaceAll('%', r'\%').replaceAll('_', r'\_')}%');
    if (filter == 'media') query = query.inFilter('kind', ['image', 'video']).eq('media_expired', false);
    if (filter == 'voice') query = query.eq('kind', 'voice').eq('media_expired', false);
    if (filter == 'links') query = query.or('body.ilike.%http%,body.ilike.%www.%,body.ilike.%t.me/%');
    if (filter == 'saved') query = query.inFilter('id', saved.toList());
    final rows = await query.order('id', ascending: false).limit(100);
    final list = rows.map(GroupMessage.fromJson).where(_shown).toList();
    await Profiles.instance.ensure(list.map((m) => m.userId));
    return list;
  }

  void _persist() {
    final keep = _all.where((m) => !m.isLocal && !m.deleted).toList();
    final tail = keep.length > 60 ? keep.sublist(keep.length - 60) : keep;
    unawaited(LocalStore.setJson(_cacheKey, tail.map((m) => m.toJson()).toList()));
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unbindLifecycle();
    _readTimer?.cancel();
    _typingTick?.cancel();
    final ch = _channel;
    if (ch != null) unawaited(supa.removeChannel(ch));
    _incoming.close();
    _notices.close();
    super.dispose();
  }
}
