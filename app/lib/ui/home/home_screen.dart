import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../state/fx_store.dart';
import '../../state/news_store.dart';
import '../../state/session.dart';
import '../../theme.dart';
import '../misc/coming_soon.dart';
import '../news/news_screens.dart';
import '../profile/profile_screen.dart';
import '../widgets/common.dart';
import 'fx_screen.dart';
import 'notifications_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onOpenTab});
  final void Function(int) onOpenTab;

  void _soon(BuildContext context, String title, IconData icon) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ComingSoonScreen(title: title, icon: icon, text: 'Bu bo‘lim yangi ilovaga ko‘chirilmoqda va tez orada ishga tushadi.', showBack: true)),
      );

  @override
  Widget build(BuildContext context) {
    final services = [
      (Icons.account_balance_wallet_outlined, 'Aqlli hamyon', 'Xarajatlaringizni boshqaring'),
      (Icons.notifications_active_outlined, 'Eslatmalar', 'Muhim sanalar va vaqtlar'),
      (Icons.schedule_outlined, 'Kun tartibim', 'Bugungi rejangiz'),
      (Icons.family_restroom_outlined, 'Ota-ona nazorati', '14 yoshgacha bolalar xavfsizligi'),
      (Icons.timer_outlined, 'Soat hisoblagich', 'Ish va haq hisoblash'),
      (Icons.verified_user_outlined, 'Ish bo‘yicha izohlar', 'Ish joylari haqida tajriba'),
      (Icons.fact_check_outlined, 'Hujjat tekshiruvi', 'Taqiqlarni tekshirish'),
      (Icons.school_outlined, 'Sertifikat imtihoni', 'Rus tili testiga tayyorgarlik'),
    ];
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => Future.wait([NewsStore.instance.refresh(), FxStore.instance.refresh()]),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Row(children: [
                Text('Migrant Hub', style: Theme.of(context).textTheme.headlineSmall),
                const Spacer(),
                ListenableBuilder(
                  listenable: NewsStore.instance,
                  builder: (context, _) => IconButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
                    icon: Badge(isLabelVisible: NewsStore.instance.freshCount > 0, label: Text('${NewsStore.instance.freshCount}'), child: const Icon(Icons.notifications_none_rounded, size: 27)),
                  ),
                ),
                const SizedBox(width: 4),
                ListenableBuilder(
                  listenable: AppSession.instance,
                  builder: (context, _) {
                    final p = AppSession.instance.profile;
                    return GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
                      child: UserAvatar(id: p?.id ?? '', name: p?.displayName ?? '?', url: p?.avatarUrl, size: 42),
                    );
                  },
                ),
              ]),
              const SizedBox(height: 14),
              const _FxCard(),
              const SectionTitle('Tezkor xizmatlar'),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.45,
                children: [
                  for (final (icon, title, sub) in services)
                    Glass(
                      padding: const EdgeInsets.all(14),
                      onTap: () => _soon(context, title, icon),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(color: AppColors.sky.withValues(alpha: .45), borderRadius: BorderRadius.circular(12)),
                          child: Icon(icon, color: AppColors.navy, size: 21),
                        ),
                        const Spacer(),
                        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                        const SizedBox(height: 2),
                        Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                      ]),
                    ),
                ],
              ),
              SectionTitle('Yangiliklar', action: 'Barchasi', onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NewsListScreen()))),
              ListenableBuilder(
                listenable: NewsStore.instance,
                builder: (context, _) {
                  final s = NewsStore.instance;
                  if (s.items.isEmpty) {
                    return Glass(
                      child: Text(
                        s.loading ? 'Yuklanmoqda…' : s.error ?? 'Bugun migrantlarga oid yangi rasmiy qaror yo‘q. Yangiliklar har 30 daqiqada tekshiriladi.',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    );
                  }
                  return Column(children: [for (final n in s.items.take(3)) Padding(padding: const EdgeInsets.only(bottom: 10), child: NewsCard(item: n))]);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FxCard extends StatelessWidget {
  const _FxCard();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FxStore.instance,
      builder: (context, _) {
        final fx = FxStore.instance.fx;
        final rub = fx?.rates['RUB'];
        final app = fx?.nbuApp['RUB'] ?? fx?.nbuCash['RUB'];
        final text = rub != null ? '1000 RUB = ${fmtNum((rub.rate * 1000).round())} UZS' : app != null ? '1000 RUB = ${fmtNum((app.buy * 1000).round())} UZS' : '1000 RUB = … UZS';
        return Material(
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FxScreen())),
            child: Ink(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(gradient: LinearGradient(colors: [AppColors.primary, AppColors.navy], begin: Alignment.topLeft, end: Alignment.bottomRight)),
              child: Row(children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(15)),
                  child: const Text('₽', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(fx?.basis == 'cross' ? 'Bugungi kurs · Rossiya MB orqali hisoblangan' : 'Bugungi kurs · O‘zbekiston Markaziy banki', style: TextStyle(color: Colors.white.withValues(alpha: .8), fontSize: 12.5)),
                    const SizedBox(height: 3),
                    Text(text, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(fx == null ? 'Yuklanmoqda…' : '${fx.date} · ${fx.basis == 'cross' ? 'taxminiy kurs' : 'rasmiy kurs'}', style: TextStyle(color: Colors.white.withValues(alpha: .75), fontSize: 12)),
                  ]),
                ),
                const Icon(Icons.chevron_right, color: Colors.white),
              ]),
            ),
          ),
        );
      },
    );
  }
}
