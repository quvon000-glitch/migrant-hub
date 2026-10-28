import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/supa.dart';
import '../../models/profile.dart';
import '../../state/ads_store.dart';
import '../../state/profiles.dart';
import '../../theme.dart';
import '../widgets/common.dart';

Future<void> showUserProfile(BuildContext context, String userId) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (_) => _UserProfile(userId: userId),
  );
}

class _UserProfile extends StatefulWidget {
  const _UserProfile({required this.userId});
  final String userId;

  @override
  State<_UserProfile> createState() => _UserProfileState();
}

class _UserProfileState extends State<_UserProfile> {
  PublicProfile? p;
  bool blocked = false;

  @override
  void initState() {
    super.initState();
    p = Profiles.instance.get(widget.userId);
    Profiles.instance.fetch(widget.userId).then((v) {
      if (mounted && v != null) setState(() => p = v);
    });
    if (widget.userId != myId) {
      supa.from('user_blocks').select('blocked_id').eq('blocked_id', widget.userId).maybeSingle().then((r) {
        if (mounted) setState(() => blocked = r != null);
      }, onError: (_) {});
    }
  }

  Future<void> _report() async {
    final r = await pickFrom<String>(context, 'Shikoyat sababi', [for (final x in ['Firibgarlik', 'Spam yoki reklama', 'Haqorat', 'Soxta profil', 'Boshqa']) (x, x, Icons.flag_outlined)]);
    if (r == null) return;
    try {
      await AdsStore.instance.report(reason: r, userId: widget.userId);
      if (mounted) toast(context, 'Shikoyat yuborildi. Rahmat!');
    } catch (e) {
      if (mounted) toast(context, errorText(e));
    }
  }

  Future<void> _block() async {
    try {
      if (blocked) {
        await supa.from('user_blocks').delete().eq('blocked_id', widget.userId).eq('blocker_id', myId!);
      } else {
        if (!await confirm(context, 'Bloklaysizmi?', text: 'Bu foydalanuvchi sizga e’lonlar orqali yoza olmaydi.', ok: 'Bloklash', danger: true)) return;
        await supa.from('user_blocks').insert({'blocked_id': widget.userId});
      }
      if (mounted) setState(() => blocked = !blocked);
    } catch (e) {
      if (mounted) toast(context, errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = p;
    final isMe = widget.userId == myId;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          UserAvatar(id: widget.userId, name: v?.displayName ?? '?', url: v?.avatarUrl, size: 92),
          const SizedBox(height: 12),
          Text(v?.fullName ?? '…', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
          if (v != null) Text(lastSeen(v.lastSeenAt), style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 16),
          if (v?.username != null) ListTile(leading: const Icon(Icons.alternate_email), title: Text('@${v!.username}'), subtitle: const Text('foydalanuvchi nomi')),
          if (v?.phone != null)
            ListTile(leading: const Icon(Icons.phone_outlined), title: Text(v!.phone!, style: const TextStyle(color: AppColors.tickSeen)), subtitle: const Text('telefon'), onTap: () => launchUrl(Uri.parse('tel:${v.phone}'))),
          if (v?.about != null && v!.about!.isNotEmpty) ListTile(leading: const Icon(Icons.info_outline), title: Text(v.about!), subtitle: const Text('o‘zim haqimda')),
          if (v != null && v.username == null && v.phone == null && (v.about ?? '').isEmpty)
            const Padding(padding: EdgeInsets.all(8), child: Text('Foydalanuvchi o‘zi haqida ma’lumot qo‘shmagan', style: TextStyle(color: AppColors.muted))),
          if (!isMe) ...[
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: _report, icon: const Icon(Icons.flag_outlined), label: const Text('Shikoyat'))),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton.icon(onPressed: _block, icon: Icon(blocked ? Icons.lock_open : Icons.block, color: AppColors.danger), label: Text(blocked ? 'Blokdan chiqarish' : 'Bloklash', style: const TextStyle(color: AppColors.danger)))),
            ]),
          ],
        ]),
      ),
    );
  }
}
