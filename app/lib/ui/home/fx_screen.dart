import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../state/fx_store.dart';
import '../../theme.dart';
import '../widgets/common.dart';

class FxScreen extends StatefulWidget {
  const FxScreen({super.key});

  @override
  State<FxScreen> createState() => _FxScreenState();
}

class _FxScreenState extends State<FxScreen> {
  final amount = TextEditingController(text: '10000');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Valyuta kurslari')),
      body: ListenableBuilder(
        listenable: FxStore.instance,
        builder: (context, _) {
          final fx = FxStore.instance.fx;
          if (fx == null) return Center(child: FxStore.instance.loading ? const CircularProgressIndicator() : const Text('Kurslar hozircha yo‘q'));
          final rub = fx.rates['RUB'];
          final a = double.tryParse(amount.text.replaceAll(' ', '')) ?? 0;
          return RefreshIndicator(
            onRefresh: FxStore.instance.refresh,
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
              Glass(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Kalkulyator (Markaziy bank kursi)', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  TextField(controller: amount, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}), decoration: const InputDecoration(suffixText: '₽')),
                  const SizedBox(height: 10),
                  Text(rub == null ? '—' : '= ${fmtNum((a * rub.rate).round())} so‘m', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.navy)),
                ]),
              ),
              const SectionTitle('O‘zbekiston Markaziy banki (1 birlik = so‘m)'),
              Glass(child: Column(children: [for (final e in fx.rates.entries) _row(e.key, moneyShort(e.value.rate), e.value.diff)])),
              if (fx.nbuApp.isNotEmpty || fx.nbuCash.isNotEmpty) ...[
                const SectionTitle('Milliy bank: sotib olish / sotish'),
                Glass(
                  child: Column(children: [
                    for (final e in (fx.nbuApp.isNotEmpty ? fx.nbuApp : fx.nbuCash).entries) _row(e.key, '${moneyShort(e.value.buy)} / ${moneyShort(e.value.sell)}', 0),
                  ]),
                ),
              ],
              if (fx.cbr.isNotEmpty) ...[
                const SectionTitle('Rossiya Markaziy banki (1 birlik = ₽)'),
                Glass(child: Column(children: [for (final e in fx.cbr.entries) _row(e.key, moneyShort(e.value.rate, digits: 4), e.value.diff)])),
              ],
              const SizedBox(height: 10),
              Text('Sana: ${fx.date}', style: const TextStyle(color: AppColors.muted)),
            ]),
          );
        },
      ),
    );
  }

  Widget _row(String ccy, String value, double diff) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          SizedBox(width: 52, child: Text(ccy, style: const TextStyle(fontWeight: FontWeight.w700))),
          Expanded(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontSize: 15.5))),
          const SizedBox(width: 10),
          SizedBox(
            width: 64,
            child: Text(
              diff == 0 ? '' : '${diff > 0 ? '▲' : '▼'} ${moneyShort(diff.abs())}',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 12, color: diff > 0 ? AppColors.success : AppColors.danger),
            ),
          ),
        ]),
      );
}
