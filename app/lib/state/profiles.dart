import 'package:flutter/foundation.dart';

import '../core/supa.dart';
import '../models/profile.dart';

/// Public profiles of other members, fetched in batches and kept in memory.
class Profiles extends ChangeNotifier {
  Profiles._();
  static final instance = Profiles._();

  final Map<String, PublicProfile> _cache = {};
  final Set<String> _pending = {};
  bool _scheduled = false;

  PublicProfile? get(String id) => _cache[id];

  /// Returns what is known now and schedules a fetch for the rest (one request per frame).
  PublicProfile of(String id) {
    final p = _cache[id];
    if (p != null) return p;
    _pending.add(id);
    if (!_scheduled) {
      _scheduled = true;
      Future.microtask(_flush);
    }
    return PublicProfile.unknown;
  }

  Future<void> ensure(Iterable<String> ids) async {
    final missing = ids.where((id) => !_cache.containsKey(id)).toSet();
    if (missing.isEmpty) return;
    _pending.addAll(missing);
    await _flush();
  }

  Future<PublicProfile?> fetch(String id) async {
    try {
      final row = await supa.from('public_profiles').select().eq('id', id).maybeSingle();
      if (row == null) return null;
      final p = PublicProfile.fromJson(row);
      _cache[id] = p;
      notifyListeners();
      return p;
    } catch (_) {
      return _cache[id];
    }
  }

  Future<void> _flush() async {
    _scheduled = false;
    if (_pending.isEmpty) return;
    final ids = _pending.toList();
    _pending.clear();
    try {
      final rows = await supa.from('public_profiles').select().inFilter('id', ids);
      for (final r in rows) {
        final p = PublicProfile.fromJson(r);
        _cache[p.id] = p;
      }
      for (final id in ids) {
        _cache.putIfAbsent(id, () => PublicProfile(id: id, displayName: 'Foydalanuvchi'));
      }
      notifyListeners();
    } catch (e) {
      debugPrint('profiles fetch failed: $e');
    }
  }

  void put(PublicProfile p) {
    _cache[p.id] = p;
    notifyListeners();
  }

  void clear() => _cache.clear();
}
