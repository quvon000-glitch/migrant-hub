import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/local_store.dart';
import '../core/supa.dart';

class FxSnapshot {
  final String date;
  /// 'cbu' = official Central Bank of Uzbekistan rate, 'cross' = calculated from the Bank of Russia rates
  final String basis;
  final Map<String, ({double rate, double diff})> rates; // so'm per unit
  final List<({String date, double rate})> rubHistory;
  final Map<String, ({double rate, double diff})> cbr; // rubles per unit
  final Map<String, ({double buy, double sell})> nbuCash;
  final Map<String, ({double buy, double sell})> nbuApp;

  FxSnapshot(this.date, this.basis, this.rates, this.rubHistory, this.cbr, this.nbuCash, this.nbuApp);

  static double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;

  factory FxSnapshot.fromJson(Map<String, dynamic> j) {
    Map<String, ({double rate, double diff})> rd(dynamic m) => ((m as Map?) ?? {}).map((k, v) => MapEntry(k as String, (rate: _d(v['rate']), diff: _d(v['diff']))));
    Map<String, ({double buy, double sell})> bs(dynamic m) => ((m as Map?) ?? {}).map((k, v) => MapEntry(k as String, (buy: _d(v['buy']), sell: _d(v['sell']))));
    final cbr = j['cbr'] as Map?;
    final nbu = j['nbu'] as Map?;
    return FxSnapshot(
      j['date'] as String? ?? '',
      j['basis'] as String? ?? 'cbu',
      rd(j['rates']),
      ((j['rub_history'] as List?) ?? []).map((h) => (date: h['date'] as String, rate: _d(h['rate']))).toList(),
      rd(cbr?['rates']),
      bs(nbu?['cash']),
      bs(nbu?['app']),
    );
  }
}

class FxStore extends ChangeNotifier {
  FxStore._();
  static final instance = FxStore._();

  FxSnapshot? fx;
  bool loading = false;

  Future<void> refresh() async {
    final cached = LocalStore.getJson('fx');
    if (fx == null && cached is Map<String, dynamic>) {
      fx = FxSnapshot.fromJson(cached);
      notifyListeners();
    }
    loading = true;
    try {
      final j = await supa.rpc('fx_snapshot');
      if (j is Map<String, dynamic>) {
        fx = FxSnapshot.fromJson(j);
        unawaited(LocalStore.setJson('fx', j));
      }
    } catch (e) {
      debugPrint('fx: $e');
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
