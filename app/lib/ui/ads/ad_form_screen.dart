import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/supa.dart';
import '../../models/ad.dart';
import '../../state/ads_store.dart';
import '../../state/session.dart';
import '../../theme.dart';
import 'ad_detail_screen.dart';

class AdFormScreen extends StatefulWidget {
  const AdFormScreen({super.key, this.initial});
  final Ad? initial;

  @override
  State<AdFormScreen> createState() => _AdFormScreenState();
}

class _AdFormScreenState extends State<AdFormScreen> {
  late String category = widget.initial?.category ?? 'Ish';
  late final title = TextEditingController(text: widget.initial?.title);
  late final amount = TextEditingController(text: widget.initial?.amount?.toString());
  late final city = TextEditingController(text: widget.initial?.city ?? AppSession.instance.profile?.currentCity ?? 'Moskva');
  late final address = TextEditingController(text: widget.initial?.address);
  late final description = TextEditingController(text: widget.initial?.description);
  late final telegram = TextEditingController(text: widget.initial?.telegram);
  late final whatsapp = TextEditingController(text: widget.initial?.whatsapp);
  late final Map<String, String> attrs = {...?widget.initial?.attrs};
  late final List<String> photos = [...?widget.initial?.photos];
  int uploading = 0;
  bool saving = false;

  Future<void> _addPhotos() async {
    final left = 5 - photos.length;
    if (left <= 0) return;
    final picked = await ImagePicker().pickMultiImage(maxWidth: 2000, maxHeight: 2000, imageQuality: 90, limit: left);
    for (final x in picked.take(left)) {
      setState(() => uploading++);
      try {
        final url = await AdsStore.instance.uploadPhoto(x.path);
        setState(() => photos.add(url));
      } catch (e) {
        if (mounted) toast(context, errorText(e));
      } finally {
        if (mounted) setState(() => uploading--);
      }
    }
  }

  Future<void> _save() async {
    if (title.text.trim().length < 3) {
      toast(context, 'Sarlavhani yozing');
      return;
    }
    if (uploading > 0) {
      toast(context, 'Rasmlar yuklanmoqda, biroz kuting');
      return;
    }
    setState(() => saving = true);
    try {
      final ad = await AdsStore.instance.save(id: widget.initial?.id, values: {
        'category': category,
        'title': title.text.trim(),
        'amount': int.tryParse(amount.text.replaceAll(RegExp(r'\D'), '')),
        'city': city.text.trim(),
        'address': address.text.trim(),
        'description': description.text.trim(),
        'attrs': attrs,
        'photos': photos,
        'telegram': telegram.text.trim(),
        'whatsapp': whatsapp.text.trim(),
      });
      if (!mounted) return;
      if (widget.initial != null) {
        Navigator.pop(context, ad);
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AdDetailScreen(ad: ad)));
        toast(context, 'E’lon joylandi');
      }
    } catch (e) {
      if (mounted) toast(context, errorText(e));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fields = categoryFields[category]!;
    return Scaffold(
      appBar: AppBar(title: Text(widget.initial == null ? 'Yangi e’lon' : 'E’lonni tahrirlash')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
        if (widget.initial == null) ...[
          const Text('Kategoriya', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in adCategories)
              ChoiceChip(
                label: Text(c == 'Maishiy xizmatlar' ? 'Xizmatlar' : c),
                selected: c == category,
                onSelected: (_) => setState(() {
                  category = c;
                  attrs.clear();
                }),
              ),
          ]),
          const SizedBox(height: 16),
        ],
        TextField(controller: title, maxLength: 120, decoration: const InputDecoration(labelText: 'Sarlavha', hintText: 'Masalan: Omborga ishchi kerak')),
        const SizedBox(height: 8),
        for (final field in fields) ...[
          switch (field) {
            SelectField(:final options) => DropdownButtonFormField<String>(
                initialValue: attrs[field.key],
                decoration: InputDecoration(labelText: field.label),
                items: [for (final o in options) DropdownMenuItem(value: o, child: Text(o))],
                onChanged: (v) => setState(() => v == null ? attrs.remove(field.key) : attrs[field.key] = v),
              ),
            TextAdField(:final hint) => TextFormField(
                initialValue: attrs[field.key],
                decoration: InputDecoration(labelText: field.label, hintText: hint),
                onChanged: (v) => attrs[field.key] = v,
              ),
            YearField() => TextFormField(
                initialValue: attrs[field.key],
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                decoration: InputDecoration(labelText: field.label),
                onChanged: (v) => attrs[field.key] = v,
              ),
          },
          const SizedBox(height: 12),
        ],
        TextField(controller: amount, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: InputDecoration(labelText: priceLabel(category), hintText: 'Bo‘sh qoldirsangiz: Kelishiladi')),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(controller: city, decoration: const InputDecoration(labelText: 'Shahar'))),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: address, decoration: const InputDecoration(labelText: 'Tuman / metro'))),
        ]),
        const SizedBox(height: 12),
        TextField(controller: description, minLines: 4, maxLines: 10, maxLength: 4000, decoration: const InputDecoration(labelText: 'Tavsif', alignLabelWithHint: true)),
        const SizedBox(height: 4),
        Text('Rasmlar (${photos.length}/5)', style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SizedBox(
          height: 92,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final p in photos)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Stack(children: [
                  ClipRRect(borderRadius: BorderRadius.circular(14), child: CachedNetworkImage(imageUrl: p, width: 92, height: 92, fit: BoxFit.cover)),
                  Positioned(
                    right: 2,
                    top: 2,
                    child: GestureDetector(onTap: () => setState(() => photos.remove(p)), child: const CircleAvatar(radius: 12, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 15, color: Colors.white))),
                  ),
                ]),
              ),
            for (var i = 0; i < uploading; i++)
              Container(margin: const EdgeInsets.only(right: 8), width: 92, height: 92, decoration: BoxDecoration(color: AppColors.canvas, borderRadius: BorderRadius.circular(14)), child: const Center(child: CircularProgressIndicator(strokeWidth: 2.4))),
            if (photos.length + uploading < 5)
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _addPhotos,
                child: Container(width: 92, height: 92, decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.line, width: 1.5)), child: const Icon(Icons.add_a_photo_outlined, color: AppColors.primary)),
              ),
          ]),
        ),
        const SizedBox(height: 16),
        const Text('Qo‘shimcha aloqa (ixtiyoriy)', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(controller: telegram, decoration: const InputDecoration(labelText: 'Telegram', hintText: '@username', prefixIcon: Icon(Icons.send_rounded))),
        const SizedBox(height: 12),
        TextField(controller: whatsapp, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'WhatsApp', hintText: '+7 900 000 00 00', prefixIcon: Icon(Icons.chat_rounded))),
        const SizedBox(height: 22),
        FilledButton(onPressed: saving ? null : _save, child: saving ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)) : Text(widget.initial == null ? 'E’lonni joylash' : 'Saqlash')),
      ]),
    );
  }
}
