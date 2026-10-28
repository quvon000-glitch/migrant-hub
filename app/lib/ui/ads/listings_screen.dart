import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/supa.dart';
import '../../models/ad.dart';
import '../../state/ads_store.dart';
import '../../theme.dart';
import '../widgets/common.dart';
import 'ad_detail_screen.dart';
import 'ad_form_screen.dart';
import 'my_ads_screen.dart';

class AdFilters {
  String category = 'Barchasi';
  String query = '';
  Map<String, String> attrs = {};
  int? min, max;

  bool get active => category != 'Barchasi' || attrs.isNotEmpty || min != null || max != null;

  bool matches(Ad a) {
    if (category != 'Barchasi' && a.category != category) return false;
    for (final e in attrs.entries) {
      final v = a.attrs[e.key] ?? '';
      if (e.key == 'make' || e.key == 'model') {
        if (!v.toLowerCase().contains(e.value.toLowerCase())) return false;
      } else if (v != e.value) {
        return false;
      }
    }
    if (min != null && (a.amount ?? 0) < min!) return false;
    if (max != null && (a.amount ?? 0) > max!) return false;
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty && !'${a.category} ${a.title} ${a.location} ${a.priceText} ${a.description}'.toLowerCase().contains(q)) return false;
    return true;
  }
}

class ListingsScreen extends StatefulWidget {
  const ListingsScreen({super.key});

  @override
  State<ListingsScreen> createState() => _ListingsScreenState();
}

class _ListingsScreenState extends State<ListingsScreen> {
  final f = AdFilters();

  Future<void> _filters() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (c) => _FilterSheet(f: f),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    const cats = [('Ish', 'ISH', Icons.work_rounded), ('Uy-joy', 'UY-JOY', Icons.home_rounded), ('Maishiy xizmatlar', 'XIZMATLAR', Icons.handyman_rounded), ('Transport', 'TRANSPORT', Icons.directions_car_rounded)];
    return Scaffold(
      appBar: AppBar(
        title: const Text('E’lonlar'),
        actions: [
          IconButton(tooltip: 'Mening e’lonlarim', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyAdsScreen())), icon: const Icon(Icons.person_outline_rounded)),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 14)),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdFormScreen())),
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Qo‘shish'),
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: AdsStore.instance,
        builder: (context, _) {
          final s = AdsStore.instance;
          final list = s.ads.where(f.matches).toList();
          return RefreshIndicator(
            onRefresh: s.refresh,
            child: CustomScrollView(slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                sliver: SliverList.list(children: [
                  TextField(
                    onChanged: (v) => setState(() => f.query = v),
                    decoration: InputDecoration(
                      hintText: 'Ish, uy-joy yoki xizmat qidirish',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(onPressed: _filters, icon: Badge(isLabelVisible: f.active, smallSize: 8, child: const Icon(Icons.tune_rounded))),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    for (final (cat, label, icon) in cats)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            f.category = f.category == cat ? 'Barchasi' : cat;
                            f.attrs.clear();
                          }),
                          child: Column(children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                color: f.category == cat ? AppColors.primary : Colors.white,
                                border: Border.all(color: AppColors.line),
                              ),
                              child: Icon(icon, color: f.category == cat ? Colors.white : AppColors.navy, size: 28),
                            ),
                            const SizedBox(height: 6),
                            Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: f.category == cat ? AppColors.primary : AppColors.ink)),
                          ]),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 14),
                  Row(children: [
                    Text(f.category == 'Barchasi' ? 'Yangi e’lonlar' : (f.category == 'Maishiy xizmatlar' ? 'Xizmatlar' : f.category), style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(width: 8),
                    Text('${list.length} ta', style: const TextStyle(color: AppColors.muted)),
                    const Spacer(),
                    if (f.active || f.query.isNotEmpty) TextButton(onPressed: () => setState(() => f..category = 'Barchasi'..attrs.clear()..min = null..max = null), child: const Text('Tozalash')),
                  ]),
                ]),
              ),
              if (list.isEmpty)
                SliverToBoxAdapter(child: EmptyState(icon: Icons.search_off_rounded, title: s.loading ? 'Yuklanmoqda…' : 'Mos e’lon topilmadi', text: s.error ?? 'Filtrlarni o‘zgartirib ko‘ring yoki birinchi e’lonni joylang.'))
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverGrid.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 240, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: .72),
                    itemCount: list.length,
                    itemBuilder: (context, i) => AdCard(ad: list[i]),
                  ),
                ),
            ]),
          );
        },
      ),
    );
  }
}

const categoryIcons = {'Ish': Icons.work_rounded, 'Uy-joy': Icons.home_rounded, 'Transport': Icons.directions_car_rounded, 'Maishiy xizmatlar': Icons.handyman_rounded};

class AdCard extends StatelessWidget {
  const AdCard({super.key, required this.ad});
  final Ad ad;

  @override
  Widget build(BuildContext context) {
    final fav = AdsStore.instance.favorites.contains(ad.id);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdDetailScreen(ad: ad))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Stack(fit: StackFit.expand, children: [
              ad.photos.isNotEmpty
                  ? CachedNetworkImage(imageUrl: ad.photos.first, fit: BoxFit.cover, memCacheWidth: 500, placeholder: (_, _) => Container(color: AppColors.canvas))
                  : Container(color: AppColors.sky.withValues(alpha: .4), child: Icon(categoryIcons[ad.category], size: 46, color: AppColors.navy)),
              Positioned(
                right: 6,
                top: 6,
                child: Material(
                  color: Colors.white.withValues(alpha: .9),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () async {
                      if (myId == null) return;
                      try {
                        await AdsStore.instance.toggleFavorite(ad.id);
                      } catch (e) {
                        if (context.mounted) toast(context, errorText(e));
                      }
                    },
                    child: Padding(padding: const EdgeInsets.all(6), child: Icon(fav ? Icons.favorite : Icons.favorite_border, size: 19, color: fav ? AppColors.danger : AppColors.muted)),
                  ),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ad.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, height: 1.25)),
              const SizedBox(height: 4),
              Text(ad.priceText, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy)),
              const SizedBox(height: 2),
              Row(children: [
                const Icon(Icons.place_outlined, size: 13, color: AppColors.muted),
                const SizedBox(width: 2),
                Expanded(child: Text(ad.location, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 12))),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.f});
  final AdFilters f;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  AdFilters get f => widget.f;

  @override
  Widget build(BuildContext context) {
    final fields = categoryFields[f.category] ?? const [];
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Filtrlash', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: f.category,
            decoration: const InputDecoration(labelText: 'Kategoriya'),
            items: [for (final c in ['Barchasi', ...adCategories]) DropdownMenuItem(value: c, child: Text(c))],
            onChanged: (v) => setState(() {
              f.category = v ?? 'Barchasi';
              f.attrs.clear();
            }),
          ),
          for (final field in fields)
            if (field is SelectField)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: DropdownButtonFormField<String>(
                  initialValue: f.attrs[field.key] ?? 'Barchasi',
                  decoration: InputDecoration(labelText: field.label),
                  items: [for (final o in ['Barchasi', ...field.options]) DropdownMenuItem(value: o, child: Text(o))],
                  onChanged: (v) => setState(() => v == null || v == 'Barchasi' ? f.attrs.remove(field.key) : f.attrs[field.key] = v),
                ),
              )
            else if (field is TextAdField && (field.key == 'make' || field.key == 'model'))
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextFormField(
                  initialValue: f.attrs[field.key],
                  decoration: InputDecoration(labelText: field.label, hintText: field.hint),
                  onChanged: (v) => v.trim().isEmpty ? f.attrs.remove(field.key) : f.attrs[field.key] = v.trim(),
                ),
              ),
          if (f.category != 'Barchasi')
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(children: [
                Expanded(child: TextFormField(initialValue: f.min?.toString(), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'dan, ₽'), onChanged: (v) => f.min = int.tryParse(v))),
                const SizedBox(width: 10),
                Expanded(child: TextFormField(initialValue: f.max?.toString(), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'gacha, ₽'), onChanged: (v) => f.max = int.tryParse(v))),
              ]),
            ),
          const SizedBox(height: 18),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Natijalarni ko‘rsatish')),
        ]),
      ),
    );
  }
}
