import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/supa.dart';
import '../../models/ad.dart';
import '../../state/ads_store.dart';
import '../../state/inbox.dart';
import '../../state/profiles.dart';
import '../../theme.dart';
import '../chat/chat_tab.dart';
import '../chat/media.dart';
import '../chat/user_profile_sheet.dart';
import '../widgets/common.dart';
import 'ad_form_screen.dart';
import 'listings_screen.dart' show categoryIcons;

class AdDetailScreen extends StatefulWidget {
  const AdDetailScreen({super.key, required this.ad});
  final Ad ad;

  @override
  State<AdDetailScreen> createState() => _AdDetailScreenState();
}

class _AdDetailScreenState extends State<AdDetailScreen> {
  late Ad ad = widget.ad;
  int page = 0;
  bool starting = false;

  @override
  void initState() {
    super.initState();
    if (ad.userId != myId) AdsStore.instance.view(ad.id);
    Profiles.instance.ensure([ad.userId]).then((_) => mounted ? setState(() {}) : null);
    AdsStore.instance.fetch(ad.id).then((a) {
      if (mounted && a != null) setState(() => ad = a);
    }, onError: (_) {});
  }

  Future<void> _write() async {
    setState(() => starting = true);
    try {
      final id = await Inbox.instance.start_(ad.id);
      if (mounted) openDm(context, id);
    } catch (e) {
      if (mounted) toast(context, errorText(e));
    } finally {
      if (mounted) setState(() => starting = false);
    }
  }

  Future<void> _ownerMenu() async {
    final a = await pickFrom<String>(context, 'E’lon', [
      ('edit', 'Tahrirlash', Icons.edit_outlined),
      (ad.active ? 'archive' : 'activate', ad.active ? 'Arxivlash (yopish)' : 'Qayta faollashtirish', ad.active ? Icons.archive_outlined : Icons.unarchive_outlined),
      ('delete', 'O‘chirish', Icons.delete_outline),
    ]);
    if (!mounted || a == null) return;
    try {
      if (a == 'edit') {
        final saved = await Navigator.push<Ad>(context, MaterialPageRoute(builder: (_) => AdFormScreen(initial: ad)));
        if (saved != null) setState(() => ad = saved);
      } else if (a == 'archive' || a == 'activate') {
        await AdsStore.instance.setStatus(ad, a == 'archive' ? 'archived' : 'active');
        final fresh = await AdsStore.instance.fetch(ad.id);
        if (fresh != null && mounted) setState(() => ad = fresh);
      } else if (a == 'delete') {
        if (!await confirm(context, 'E’lonni o‘chirasizmi?', ok: 'O‘chirish', danger: true)) return;
        await AdsStore.instance.remove(ad);
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) toast(context, errorText(e));
    }
  }

  Future<void> _report() async {
    final r = await pickFrom<String>(context, 'Shikoyat sababi', [for (final x in adReportReasons) (x, x, Icons.flag_outlined)]);
    if (r == null) return;
    try {
      await AdsStore.instance.report(reason: r, adId: ad.id, userId: ad.userId);
      if (mounted) toast(context, 'Shikoyat yuborildi. Rahmat!');
    } catch (e) {
      if (mounted) toast(context, errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final mine = ad.userId == myId;
    final owner = Profiles.instance.of(ad.userId);
    final fields = categoryFields[ad.category] ?? const [];
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: ad.photos.isEmpty ? 0 : 320,
          backgroundColor: Colors.white,
          actions: [
            ListenableBuilder(
              listenable: AdsStore.instance,
              builder: (context, _) {
                final fav = AdsStore.instance.favorites.contains(ad.id);
                return IconButton(onPressed: () => AdsStore.instance.toggleFavorite(ad.id), icon: Icon(fav ? Icons.favorite : Icons.favorite_border, color: fav ? AppColors.danger : null));
              },
            ),
            if (mine) IconButton(onPressed: _ownerMenu, icon: const Icon(Icons.more_vert)) else IconButton(onPressed: _report, icon: const Icon(Icons.flag_outlined)),
          ],
          flexibleSpace: ad.photos.isEmpty
              ? null
              : FlexibleSpaceBar(
                  background: Stack(fit: StackFit.expand, children: [
                    PageView.builder(
                      itemCount: ad.photos.length,
                      onPageChanged: (i) => setState(() => page = i),
                      itemBuilder: (context, i) => GestureDetector(
                        onTap: () => ImageViewer.open(context, url: ad.photos[i], tag: 'ad-${ad.id}-$i'),
                        child: Hero(tag: 'ad-${ad.id}-$i', child: CachedNetworkImage(imageUrl: ad.photos[i], fit: BoxFit.cover)),
                      ),
                    ),
                    if (ad.photos.length > 1)
                      Positioned(
                        bottom: 12,
                        left: 0,
                        right: 0,
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          for (var i = 0; i < ad.photos.length; i++)
                            Container(margin: const EdgeInsets.symmetric(horizontal: 3), width: i == page ? 18 : 7, height: 7, decoration: BoxDecoration(color: Colors.white.withValues(alpha: i == page ? 1 : .6), borderRadius: BorderRadius.circular(4))),
                        ]),
                      ),
                  ]),
                ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 120),
          sliver: SliverList.list(children: [
            Row(children: [
              Icon(categoryIcons[ad.category], size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(ad.categoryLabel, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
              const Spacer(),
              const Icon(Icons.visibility_outlined, size: 16, color: AppColors.muted),
              const SizedBox(width: 4),
              Text('${ad.views}', style: const TextStyle(color: AppColors.muted)),
            ]),
            if (!ad.active)
              Container(margin: const EdgeInsets.only(top: 10), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: .08), borderRadius: BorderRadius.circular(12)), child: const Text('Bu e’lon yopilgan', style: TextStyle(color: AppColors.danger))),
            const SizedBox(height: 10),
            Text(ad.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(ad.priceText, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.navy)),
            const SizedBox(height: 8),
            if (ad.location.isNotEmpty) Row(children: [const Icon(Icons.place_outlined, size: 18, color: AppColors.muted), const SizedBox(width: 4), Expanded(child: Text(ad.location, style: const TextStyle(color: AppColors.muted)))]),
            const SizedBox(height: 16),
            if (ad.attrs.isNotEmpty)
              Glass(
                child: Column(children: [
                  for (final field in fields)
                    if (ad.attrs[field.key] != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(children: [Expanded(child: Text(field.label, style: const TextStyle(color: AppColors.muted))), Flexible(child: Text(ad.attrs[field.key]!, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600)))]),
                      ),
                ]),
              ),
            if (ad.description.isNotEmpty) ...[
              const SectionTitle('Tavsif'),
              Text(ad.description, style: const TextStyle(fontSize: 15.5, height: 1.5)),
            ],
            const SectionTitle('E’lon egasi'),
            ListTile(
              contentPadding: EdgeInsets.zero,
              onTap: () => showUserProfile(context, ad.userId),
              leading: UserAvatar(id: ad.userId, name: owner.displayName, url: owner.avatarUrl, size: 46),
              title: Text(mine ? 'Siz' : owner.fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('E’lon: ${dayLabel(ad.createdAt)}'),
              trailing: const Icon(Icons.chevron_right),
            ),
            if (ad.telegram != null || ad.whatsapp != null) ...[
              const SizedBox(height: 6),
              Row(children: [
                if (ad.telegram != null)
                  Expanded(child: OutlinedButton.icon(onPressed: () => launchUrl(Uri.parse('https://t.me/${ad.telegram}'), mode: LaunchMode.externalApplication), icon: const Icon(Icons.send_rounded), label: const Text('Telegram'))),
                if (ad.telegram != null && ad.whatsapp != null) const SizedBox(width: 10),
                if (ad.whatsapp != null)
                  Expanded(child: OutlinedButton.icon(onPressed: () => launchUrl(Uri.parse('https://wa.me/${ad.whatsapp}'), mode: LaunchMode.externalApplication), icon: const Icon(Icons.chat_rounded), label: const Text('WhatsApp'))),
              ]),
            ],
            const SizedBox(height: 14),
            const Text('Ehtiyot bo‘ling: oldindan pul o‘tkazmang, hujjatlaringizni bermang.', style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
          ]),
        ),
      ]),
      bottomNavigationBar: mine || !ad.active
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: FilledButton.icon(
                  onPressed: starting ? null : _write,
                  icon: starting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.chat_bubble_rounded),
                  label: const Text('Yozish'),
                ),
              ),
            ),
    );
  }
}
