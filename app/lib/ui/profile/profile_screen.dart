import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/files.dart';
import '../../core/supa.dart';
import '../../state/chat_hub.dart';
import '../../state/group_chat.dart';
import '../../state/session.dart';
import '../../theme.dart';
import '../auth/auth_data.dart';
import '../widgets/common.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListenableBuilder(
        listenable: AppSession.instance,
        builder: (context, _) {
          final p = AppSession.instance.profile;
          if (p == null) return const Center(child: CircularProgressIndicator());
          return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
            Center(child: UserAvatar(id: p.id, name: p.displayName, url: p.avatarUrl, size: 96)),
            const SizedBox(height: 12),
            Text(p.fullName, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
            Text('+${p.phone}${p.username != null ? ' · @${p.username}' : ''}', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
            if (p.isAdmin) const Center(child: Padding(padding: EdgeInsets.only(top: 6), child: Chip(label: Text('Administrator')))),
            if (p.resetRequestedAt != null)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: .08), borderRadius: BorderRadius.circular(14)),
                child: const Text('Bu hisob uchun “Kodni unutdim” so‘rovi bor edi — siz to‘g‘ri kod bilan kirdingiz, so‘rov bekor qilindi.', style: TextStyle(color: AppColors.danger)),
              ),
            const SizedBox(height: 18),
            Glass(
              padding: EdgeInsets.zero,
              child: Column(children: [
                ListTile(leading: const Icon(Icons.badge_outlined, color: AppColors.primary), title: const Text('Chat profili'), subtitle: const Text('Rasm, ism, @username, o‘zim haqimda'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileEditScreen()))),
                const Divider(height: 1, indent: 56),
                ListTile(leading: const Icon(Icons.person_outline, color: AppColors.primary), title: const Text('Shaxsiy ma’lumotlar'), subtitle: const Text('Tug‘ilgan sana, fuqarolik, shahar'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PersonalInfoScreen()))),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.location_city_outlined, color: AppColors.primary),
                  title: const Text('Chat guruhi'),
                  subtitle: Text(p.chatCity == null ? 'Tanlanmagan' : groupCities[p.chatCity]!.name),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final c = await pickFrom<String>(context, 'Shahar guruhi', [for (final e in groupCities.entries) (e.key, e.value.name, Icons.location_city)]);
                    if (c != null) await ChatHub.instance.setCity(c);
                  },
                ),
              ]),
            ),
            const SizedBox(height: 14),
            Glass(
              padding: EdgeInsets.zero,
              child: Column(children: [
                ListTile(
                  leading: const Icon(Icons.logout_rounded),
                  title: const Text('Chiqish'),
                  onTap: () async {
                    if (!await confirm(context, 'Hisobdan chiqasizmi?', ok: 'Chiqish')) return;
                    if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
                    await AppSession.instance.signOut();
                  },
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.delete_forever_outlined, color: AppColors.danger),
                  title: const Text('Hisobni o‘chirish', style: TextStyle(color: AppColors.danger)),
                  onTap: () async {
                    if (!await confirm(context, 'Hisobni butunlay o‘chirasizmi?', text: 'Barcha e’lonlar, yozishmalar va ma’lumotlaringiz qaytarib bo‘lmaydigan qilib o‘chiriladi.', ok: 'O‘chirish', danger: true)) return;
                    try {
                      await supa.functions.invoke('auth', body: {'action': 'delete_account'});
                      if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
                      await AppSession.instance.signOut();
                    } catch (e) {
                      if (context.mounted) toast(context, errorText(e));
                    }
                  },
                ),
              ]),
            ),
          ]);
        },
      ),
    );
  }
}

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final p = AppSession.instance.profile!;
  late final name = TextEditingController(text: p.displayName);
  late final last = TextEditingController(text: p.lastName);
  late final username = TextEditingController(text: p.username);
  late final about = TextEditingController(text: p.about);
  late bool phoneVisible = p.phoneVisible;
  late String? avatar = p.avatarUrl;
  bool saving = false;
  bool uploading = false;

  Future<void> _pickAvatar() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1200, maxHeight: 1200);
    if (x == null) return;
    setState(() => uploading = true);
    try {
      final bytes = await jpegForUpload(x.path, maxSide: 512, quality: 85);
      final path = '${p.id}/${const Uuid().v4()}.jpg';
      await supa.storage.from('avatars').uploadBinary(path, bytes, fileOptions: const FileOptions(contentType: 'image/jpeg', cacheControl: '31536000'));
      setState(() => avatar = publicUrl('avatars', path));
    } catch (e) {
      if (mounted) toast(context, errorText(e));
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  Future<void> _save() async {
    final u = username.text.trim().replaceFirst('@', '');
    if (name.text.trim().isEmpty) return toast(context, 'Ismingizni kiriting');
    if (u.isNotEmpty && !RegExp(r'^[a-zA-Z][a-zA-Z0-9_]{4,31}$').hasMatch(u)) {
      return toast(context, '@username 5–32 ta lotin harfi, raqam yoki _ dan iborat bo‘lsin va harf bilan boshlansin');
    }
    if (RegExp(r'(admin|support|moderator|migranthub|migrant_hub|official|rasmiy|yordam|help|mvd|police|politsiya)', caseSensitive: false).hasMatch(u)) {
      return toast(context, 'Bu nomni tanlab bo‘lmaydi');
    }
    setState(() => saving = true);
    try {
      await AppSession.instance.updateProfile({
        'display_name': name.text.trim(),
        'last_name': last.text.trim().isEmpty ? null : last.text.trim(),
        'username': u.isEmpty ? null : u,
        'about': about.text.trim().isEmpty ? null : about.text.trim(),
        'phone_visible': phoneVisible,
        'avatar_url': avatar,
      });
      if (mounted) Navigator.pop(context);
    } on PostgrestException catch (e) {
      if (mounted) toast(context, e.code == '23505' ? 'Bu @username band' : errorText(e));
    } catch (e) {
      if (mounted) toast(context, errorText(e));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat profili'), actions: [TextButton(onPressed: saving ? null : _save, child: const Text('Saqlash'))]),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
        Center(
          child: GestureDetector(
            onTap: uploading ? null : _pickAvatar,
            child: Stack(children: [
              UserAvatar(id: p.id, name: name.text, url: avatar, size: 104),
              Positioned(right: 0, bottom: 0, child: CircleAvatar(radius: 17, backgroundColor: AppColors.primary, child: uploading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.photo_camera, color: Colors.white, size: 18))),
            ]),
          ),
        ),
        if (avatar != null) Center(child: TextButton(onPressed: () => setState(() => avatar = null), child: const Text('Rasmni olib tashlash'))),
        const SizedBox(height: 12),
        TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Ism')),
        const SizedBox(height: 12),
        TextField(controller: last, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Familiya (ixtiyoriy)')),
        const SizedBox(height: 12),
        TextField(controller: username, decoration: const InputDecoration(labelText: 'Foydalanuvchi nomi', prefixText: '@')),
        const SizedBox(height: 12),
        TextField(controller: about, maxLength: 300, maxLines: 3, decoration: const InputDecoration(labelText: 'O‘zim haqimda')),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: phoneVisible,
          onChanged: (v) => setState(() => phoneVisible = v),
          title: const Text('Telefon raqamim boshqalarga ko‘rinsin'),
          subtitle: Text('+${p.phone}'),
        ),
      ]),
    );
  }
}

class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final p = AppSession.instance.profile!;
  late DateTime? birth = p.birthDate;
  late String? citizenship = p.citizenship;
  late String? city = ruRegions.contains(p.currentCity) ? p.currentCity : null;
  late final birthPlace = TextEditingController(text: p.birthPlace);
  late final email = TextEditingController(text: p.recoveryEmail);
  bool saving = false;

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      await AppSession.instance.updateProfile({
        'birth_date': birth?.toIso8601String().substring(0, 10),
        'citizenship': citizenship,
        'current_city': city,
        'birth_place': birthPlace.text.trim().isEmpty ? null : birthPlace.text.trim(),
        'recovery_email': email.text.trim().isEmpty ? null : email.text.trim(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) toast(context, errorText(e));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shaxsiy ma’lumotlar'), actions: [TextButton(onPressed: saving ? null : _save, child: const Text('Saqlash'))]),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
        const Text('Bu ma’lumotlar faqat sizga ko‘rinadi.', style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 14),
        InkWell(
          onTap: () async {
            final d = await showDatePicker(context: context, initialDate: birth ?? DateTime(1995), firstDate: DateTime(1940), lastDate: DateTime.now());
            if (d != null) setState(() => birth = d);
          },
          child: InputDecorator(decoration: const InputDecoration(labelText: 'Tug‘ilgan sana'), child: Text(birth == null ? 'Tanlang' : '${birth!.day.toString().padLeft(2, '0')}.${birth!.month.toString().padLeft(2, '0')}.${birth!.year}')),
        ),
        const SizedBox(height: 12),
        TextField(controller: birthPlace, decoration: const InputDecoration(labelText: 'Tug‘ilgan joy')),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: citizenship,
          decoration: const InputDecoration(labelText: 'Fuqarolik'),
          items: [for (final (id, name, flag) in citizenships) DropdownMenuItem(value: id, child: Text('$flag  $name'))],
          onChanged: (v) => setState(() => citizenship = v),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: city,
          isExpanded: true,
          menuMaxHeight: 420,
          decoration: const InputDecoration(labelText: 'Yashash joyi'),
          items: [for (final r in ruRegions) DropdownMenuItem(value: r, child: Text(r, overflow: TextOverflow.ellipsis))],
          onChanged: (v) => setState(() => city = v),
        ),
        const SizedBox(height: 12),
        TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Zaxira email')),
      ]),
    );
  }
}
