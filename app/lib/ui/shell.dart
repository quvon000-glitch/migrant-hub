import 'dart:async';

import 'package:flutter/material.dart';

import '../state/ads_store.dart';
import '../state/chat_hub.dart';
import '../state/fx_store.dart';
import '../state/inbox.dart';
import '../state/news_store.dart';
import '../state/profiles.dart';
import '../state/session.dart';
import '../theme.dart';
import 'ads/listings_screen.dart';
import 'chat/chat_tab.dart';
import 'home/home_screen.dart';
import 'misc/coming_soon.dart';

/// Bottom navigation with 5 sections. Tabs keep their state (IndexedStack).
class Shell extends StatefulWidget {
  const Shell({super.key});

  static void goTo(BuildContext context, int tab) => context.findAncestorStateOfType<_ShellState>()?.select(tab);

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;
  StreamSubscription? _newsSub;

  @override
  void initState() {
    super.initState();
    NewsStore.instance.start();
    AdsStore.instance.start();
    Inbox.instance.start();
    FxStore.instance.refresh();
    ChatHub.instance.sync();
    AppSession.instance.addListener(_onSession);
    // a fresh news item arriving while the app is open is announced right away
    _newsSub = NewsStore.instance.onFresh.listen((n) {
      if (!mounted || tab == 0) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Yangilik: ${n.title}', maxLines: 2, overflow: TextOverflow.ellipsis),
        action: SnackBarAction(label: 'Ochish', onPressed: () => select(0)),
      ));
    });
  }

  void _onSession() {
    if (!AppSession.instance.signedIn) {
      ChatHub.instance.stop();
      Inbox.instance.stop();
      Profiles.instance.clear();
    } else {
      ChatHub.instance.sync();
    }
  }

  @override
  void dispose() {
    AppSession.instance.removeListener(_onSession);
    _newsSub?.cancel();
    super.dispose();
  }

  void select(int i) => setState(() => tab = i);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) select(0);
      },
      child: Scaffold(
        body: IndexedStack(index: tab, children: [
          HomeScreen(onOpenTab: select),
          const ListingsScreen(),
          const ChatTab(),
          const ComingSoonScreen(title: 'Yuridik yordam', icon: Icons.gavel_rounded, text: 'AI yurist tez orada ishga tushadi. Migratsiya, patent, ro‘yxat va mehnat huquqlari bo‘yicha savollaringizga javob beradi.'),
          const ComingSoonScreen(title: 'Video qo‘llanma', icon: Icons.play_circle_outline_rounded, text: 'Migrantlar uchun video qo‘llanmalar tayyorlanmoqda: ro‘yxatdan o‘tish, patent, imtihon va boshqalar.'),
        ]),
        bottomNavigationBar: ListenableBuilder(
          listenable: Listenable.merge([ChatHub.instance, Inbox.instance]),
          builder: (context, _) {
            final unread = (ChatHub.instance.group?.unread ?? 0) + Inbox.instance.unreadTotal;
            return NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: select,
              height: 66,
              destinations: [
                const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Bosh sahifa'),
                const NavigationDestination(icon: Icon(Icons.work_outline_rounded), selectedIcon: Icon(Icons.work_rounded), label: 'E’lonlar'),
                NavigationDestination(
                  icon: Badge(isLabelVisible: unread > 0, label: Text(unread > 99 ? '99+' : '$unread'), backgroundColor: AppColors.danger, child: const Icon(Icons.chat_bubble_outline_rounded)),
                  selectedIcon: Badge(isLabelVisible: unread > 0, label: Text(unread > 99 ? '99+' : '$unread'), backgroundColor: AppColors.danger, child: const Icon(Icons.chat_bubble_rounded)),
                  label: 'Chat',
                ),
                const NavigationDestination(icon: Icon(Icons.gavel_outlined), selectedIcon: Icon(Icons.gavel_rounded), label: 'Yuridik'),
                const NavigationDestination(icon: Icon(Icons.play_circle_outline), selectedIcon: Icon(Icons.play_circle_fill), label: 'Videolar'),
              ],
            );
          },
        ),
      ),
    );
  }
}

