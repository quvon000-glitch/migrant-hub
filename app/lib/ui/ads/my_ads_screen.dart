import 'package:flutter/material.dart';

import '../../state/ads_store.dart';
import '../../theme.dart';
import '../widgets/common.dart';
import 'ad_form_screen.dart';
import 'listings_screen.dart';

class MyAdsScreen extends StatelessWidget {
  const MyAdsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mening e’lonlarim'),
          bottom: const TabBar(tabs: [Tab(text: 'E’lonlarim'), Tab(text: 'Saralanganlar')], labelColor: AppColors.primary, indicatorColor: AppColors.primary),
        ),
        body: ListenableBuilder(
          listenable: AdsStore.instance,
          builder: (context, _) {
            final s = AdsStore.instance;
            final favs = s.ads.where((a) => s.favorites.contains(a.id)).toList();
            Widget grid(List list, Widget empty) => list.isEmpty
                ? Center(child: SingleChildScrollView(child: empty))
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 240, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: .72),
                    itemCount: list.length,
                    itemBuilder: (context, i) => Opacity(opacity: list[i].active ? 1 : .55, child: AdCard(ad: list[i])),
                  );
            return TabBarView(children: [
              grid(
                s.mine,
                EmptyState(
                  icon: Icons.campaign_outlined,
                  title: 'Hali e’lon joylamagansiz',
                  action: FilledButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdFormScreen())), child: const Text('E’lon qo‘shish')),
                ),
              ),
              grid(favs, const EmptyState(icon: Icons.favorite_border, title: 'Saralangan e’lon yo‘q', text: 'E’londagi ♡ belgisini bosing.')),
            ]);
          },
        ),
      ),
    );
  }
}
