import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/lifecycle.dart';
import '../core/local_store.dart';
import '../core/supa.dart';
import '../models/news.dart';

/// Migrant news. Shown from cache instantly, then refreshed; new and edited items arrive live
/// through Realtime while the app is open, and the list is re-checked whenever the app comes back.
class NewsStore extends ChangeNotifier with WidgetsBindingObserverMixin {
  NewsStore._();
  static final instance = NewsStore._();

  List<NewsItem> items = [];
  bool loading = false;
  String? error;
  int freshCount = 0; // arrived live since the user last looked at the list
  RealtimeChannel? _channel;
  final _fresh = StreamController<NewsItem>.broadcast();
  Stream<NewsItem> get onFresh => _fresh.stream;

  void start() {
    final cached = LocalStore.getJson('news');
    if (cached is List) {
      items = cached.whereType<Map<String, dynamic>>().map(NewsItem.fromJson).toList();
      notifyListeners();
    }
    refresh();
    _subscribe();
    bindLifecycle(onResume: () {
      refresh();
      if (_channel == null) _subscribe();
    });
  }

  Future<void> refresh() async {
    loading = true;
    notifyListeners();
    try {
      final rows = await supa
          .from('news_items')
          .select('id, title, original_title, summary, tag, url, source, image_url, published_at, pinned_at')
          .eq('relevant', true)
          .isFilter('hidden_at', null)
          .order('pinned_at', ascending: false, nullsFirst: false)
          .order('published_at', ascending: false)
          .limit(80);
      items = rows.map(NewsItem.fromJson).toList();
      error = null;
      unawaited(LocalStore.setJson('news', items.map((n) => n.toJson()).toList()));
    } catch (e) {
      error = errorText(e);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void _subscribe() {
    _channel = supa
        .channel('news-feed')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'news_items',
          callback: (p) => _onChange(p),
        )
        .subscribe((status, err) {
      if (status == RealtimeSubscribeStatus.channelError || status == RealtimeSubscribeStatus.timedOut) {
        // the socket reconnects by itself; make sure nothing was missed meanwhile
        Future.delayed(const Duration(seconds: 3), refresh);
      }
    });
  }

  void _onChange(PostgresChangePayload p) {
    final row = p.newRecord;
    if (p.eventType == PostgresChangeEvent.delete) {
      final id = (p.oldRecord['id'] as num?)?.toInt();
      items = items.where((n) => n.id != id).toList();
      notifyListeners();
      return;
    }
    if (row.isEmpty) return;
    final visible = row['relevant'] == true && row['hidden_at'] == null;
    final id = (row['id'] as num).toInt();
    final existed = items.any((n) => n.id == id);
    if (!visible) {
      if (existed) {
        items = items.where((n) => n.id != id).toList();
        notifyListeners();
      }
      return;
    }
    final item = NewsItem.fromJson(row);
    final list = [...items.where((n) => n.id != id), item];
    list.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.publishedAt.compareTo(a.publishedAt);
    });
    items = list;
    if (!existed) {
      freshCount++;
      _fresh.add(item);
    }
    unawaited(LocalStore.setJson('news', items.map((n) => n.toJson()).toList()));
    notifyListeners();
  }

  void markSeen() {
    if (freshCount == 0) return;
    freshCount = 0;
    notifyListeners();
  }
}
