import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../models/news.dart';
import '../../state/news_store.dart';
import '../../theme.dart';
import '../widgets/common.dart';

const _tagIcons = {
  'Qonunchilik': Icons.gavel_rounded,
  'Patent': Icons.badge_outlined,
  'Hujjatlar': Icons.description_outlined,
  'Ish': Icons.work_outline_rounded,
  'Kirish-chiqish': Icons.flight_takeoff_rounded,
  'Jarimalar': Icons.report_gmailerrorred_rounded,
  'Imtihon': Icons.school_outlined,
  'Boshqa': Icons.campaign_outlined,
};

class NewsThumb extends StatelessWidget {
  const NewsThumb({super.key, required this.item, this.size = 64});
  final NewsItem item;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(colors: [AppColors.sky, AppColors.teal.withValues(alpha: .8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Icon(_tagIcons[item.tag] ?? Icons.campaign_outlined, color: AppColors.navy, size: size * .45),
    );
    if (item.imageUrl == null) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: CachedNetworkImage(imageUrl: item.imageUrl!, width: size, height: size, fit: BoxFit.cover, errorWidget: (_, _, _) => fallback, placeholder: (_, _) => fallback),
    );
  }
}

class NewsCard extends StatelessWidget {
  const NewsCard({super.key, required this.item});
  final NewsItem item;

  @override
  Widget build(BuildContext context) {
    return Glass(
      padding: const EdgeInsets.all(12),
      onTap: () => showNews(context, item),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        NewsThumb(item: item),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (item.pinned) const Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.push_pin, size: 14, color: AppColors.primary)),
              Text(item.tag, style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(ago(item.publishedAt), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            ]),
            const SizedBox(height: 4),
            Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, height: 1.3)),
            const SizedBox(height: 4),
            Text(item.summary, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 13.5, height: 1.35)),
          ]),
        ),
      ]),
    );
  }
}

void showNews(BuildContext context, NewsItem n) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (c) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .72,
      maxChildSize: .95,
      builder: (c, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppColors.sky.withValues(alpha: .5), borderRadius: BorderRadius.circular(20)),
              child: Text(n.tag, style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w700, fontSize: 12.5)),
            ),
            const Spacer(),
            Text(ago(n.publishedAt), style: const TextStyle(color: AppColors.muted)),
          ]),
          const SizedBox(height: 14),
          Text(n.title, style: Theme.of(c).textTheme.titleLarge),
          const SizedBox(height: 12),
          Text(n.summary, style: const TextStyle(fontSize: 16, height: 1.55)),
          const SizedBox(height: 16),
          Text('Manba: ${n.sourceName}', style: const TextStyle(color: AppColors.muted)),
          if (n.url.isNotEmpty) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => launchUrl(Uri.parse(n.url), mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.open_in_new_rounded),
              label: Text(n.official ? 'Rasmiy manbani ochish' : 'Asl maqolani ochish'),
            ),
          ],
        ],
      ),
    ),
  );
}

class NewsListScreen extends StatefulWidget {
  const NewsListScreen({super.key});

  @override
  State<NewsListScreen> createState() => _NewsListScreenState();
}

class _NewsListScreenState extends State<NewsListScreen> {
  String q = '';
  String tag = 'Barchasi';

  @override
  void initState() {
    super.initState();
    NewsStore.instance.markSeen();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yangiliklar')),
      body: ListenableBuilder(
        listenable: NewsStore.instance,
        builder: (context, _) {
          final s = NewsStore.instance;
          final tags = ['Barchasi', ...{for (final n in s.items) n.tag}];
          final list = s.items.where((n) => (tag == 'Barchasi' || n.tag == tag) && '${n.title} ${n.summary} ${n.tag}'.toLowerCase().contains(q.toLowerCase())).toList();
          return RefreshIndicator(
            onRefresh: s.refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                TextField(onChanged: (v) => setState(() => q = v), decoration: const InputDecoration(hintText: 'Yangilik qidirish…', prefixIcon: Icon(Icons.search))),
                const SizedBox(height: 10),
                SizedBox(
                  height: 38,
                  child: ListView(scrollDirection: Axis.horizontal, children: [
                    for (final t in tags)
                      Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(t), selected: t == tag, onSelected: (_) => setState(() => tag = t))),
                  ]),
                ),
                const SizedBox(height: 10),
                if (list.isEmpty) EmptyState(icon: Icons.newspaper_rounded, title: s.loading ? 'Yuklanmoqda…' : 'Yangilik topilmadi'),
                for (final n in list) Padding(padding: const EdgeInsets.only(bottom: 10), child: NewsCard(item: n)),
              ],
            ),
          );
        },
      ),
    );
  }
}
