import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../core/files.dart';
import '../core/local_store.dart';
import '../core/supa.dart';
import '../models/ad.dart';

/// Marketplace: active ads (live), my ads, favorites.
class AdsStore extends ChangeNotifier {
  AdsStore._();
  static final instance = AdsStore._();

  List<Ad> ads = [];
  List<Ad> mine = [];
  Set<int> favorites = {};
  bool loading = false;
  String? error;
  RealtimeChannel? _channel;
  Timer? _debounce;

  void start() {
    final cached = LocalStore.getJson('ads');
    if (cached is List) {
      ads = cached.whereType<Map<String, dynamic>>().map(Ad.fromJson).toList();
      notifyListeners();
    }
    refresh();
    _channel ??= supa
        .channel('ads-feed')
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'ads', callback: (_) {
          _debounce?.cancel();
          _debounce = Timer(const Duration(milliseconds: 400), refresh);
        })
        .subscribe();
  }

  Future<void> refresh() async {
    loading = true;
    notifyListeners();
    try {
      final rows = await supa.from('ads').select().eq('status', 'active').order('created_at', ascending: false).limit(500);
      ads = rows.map(Ad.fromJson).toList();
      unawaited(LocalStore.setJson('ads', ads.take(150).map((a) => a.toJson()).toList()));
      if (myId != null) {
        final my = await supa.from('ads').select().eq('user_id', myId!).order('created_at', ascending: false);
        mine = my.map(Ad.fromJson).toList();
        final fav = await supa.from('ad_favorites').select('ad_id');
        favorites = fav.map((r) => (r['ad_id'] as num).toInt()).toSet();
      }
      error = null;
    } catch (e) {
      error = errorText(e);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Ad? byId(int id) {
    for (final a in [...ads, ...mine]) {
      if (a.id == id) return a;
    }
    return null;
  }

  Future<Ad?> fetch(int id) async {
    final row = await supa.from('ads').select().eq('id', id).maybeSingle();
    return row == null ? null : Ad.fromJson(row);
  }

  Future<void> toggleFavorite(int adId) async {
    final on = !favorites.contains(adId);
    on ? favorites.add(adId) : favorites.remove(adId);
    notifyListeners();
    try {
      if (on) {
        await supa.from('ad_favorites').upsert({'ad_id': adId}, onConflict: 'user_id,ad_id', ignoreDuplicates: true);
      } else {
        await supa.from('ad_favorites').delete().eq('ad_id', adId).eq('user_id', myId!);
      }
    } catch (e) {
      on ? favorites.remove(adId) : favorites.add(adId);
      notifyListeners();
      rethrow;
    }
  }

  Future<String> uploadPhoto(String local) async {
    final bytes = await jpegForUpload(local, maxSide: 1400, quality: 80);
    final path = '$myId/${const Uuid().v4()}.jpg';
    await supa.storage.from('ad-photos').uploadBinary(path, bytes, fileOptions: const FileOptions(contentType: 'image/jpeg', cacheControl: '31536000'));
    return publicUrl('ad-photos', path);
  }

  Future<Ad> save({int? id, required Map<String, dynamic> values}) async {
    final row = id == null
        ? await supa.from('ads').insert(values).select().single()
        : await supa.from('ads').update(values).eq('id', id).select().single();
    final ad = Ad.fromJson(row);
    unawaited(refresh());
    return ad;
  }

  Future<void> setStatus(Ad ad, String status) async {
    await supa.from('ads').update({'status': status}).eq('id', ad.id);
    await refresh();
  }

  Future<void> remove(Ad ad) async {
    await supa.from('ads').delete().eq('id', ad.id);
    await refresh();
  }

  void view(int id) => unawaited(supa.rpc('ad_view', params: {'p_id': id}).then((_) {}, onError: (_) {}));

  Future<void> report({required String reason, String? userId, int? adId, int? conversationId}) =>
      supa.from('user_reports').insert({'reason': reason, 'target_user_id': userId, 'ad_id': adId, 'conversation_id': conversationId});
}
