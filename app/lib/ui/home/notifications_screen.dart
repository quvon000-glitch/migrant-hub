import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/supa.dart';
import '../../state/news_store.dart';
import '../../theme.dart';
import '../news/news_screens.dart';
import '../widgets/common.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> broadcasts = [];

  @override
  void initState() {
    super.initState();
    NewsStore.instance.markSeen();
    supa.from('broadcasts').select().isFilter('deleted_at', null).order('created_at', ascending: false).limit(30).then((rows) {
      if (mounted) setState(() => broadcasts = rows);
    }, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    final news = NewsStore.instance.items.take(20).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Bildirishnomalar')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          if (broadcasts.isEmpty && news.isEmpty) const EmptyState(icon: Icons.notifications_none_rounded, title: 'Hozircha bildirishnoma yo‘q'),
          if (broadcasts.isNotEmpty) const SectionTitle('Migrant Hub xabarlari'),
          for (final b in broadcasts)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Glass(
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.campaign_rounded, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(b['title'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(b['body'] as String, style: const TextStyle(height: 1.4)),
                      const SizedBox(height: 6),
                      Text(ago(DateTime.parse(b['created_at'] as String)), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                    ]),
                  ),
                ]),
              ),
            ),
          if (news.isNotEmpty) const SectionTitle('Yangiliklar'),
          for (final n in news) Padding(padding: const EdgeInsets.only(bottom: 10), child: NewsCard(item: n)),
        ],
      ),
    );
  }
}
