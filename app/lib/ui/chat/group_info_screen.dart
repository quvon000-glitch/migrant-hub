import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/supa.dart';
import '../../models/group_message.dart';
import '../../state/chat_hub.dart';
import '../../state/group_chat.dart';
import '../../state/profiles.dart';
import '../../theme.dart';
import '../widgets/common.dart';

class GroupInfoScreen extends StatelessWidget {
  const GroupInfoScreen({super.key, required this.chat, required this.onJump});
  final GroupChat chat;
  final Future<void> Function(int id) onJump;

  @override
  Widget build(BuildContext context) {
    final info = groupCities[chat.city]!;
    return Scaffold(
      appBar: AppBar(title: const Text('Guruh haqida')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: [
        Center(
          child: Container(
            width: 86,
            height: 86,
            alignment: Alignment.center,
            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [AppColors.teal, AppColors.navy])),
            child: Text(info.initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 24)),
          ),
        ),
        const SizedBox(height: 12),
        Text('${info.name} guruhi', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
        Text('${info.region} · ${fmtNum(chat.members)} a’zo', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
        const SizedBox(height: 16),
        Glass(
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (final (f, label, icon) in [
              ('media', 'Rasm va videolar', Icons.photo_library_outlined),
              ('voice', 'Ovozli xabarlar', Icons.mic_none_rounded),
              ('links', 'Havolalar', Icons.link_rounded),
              ('saved', 'Saqlanganlar', Icons.bookmark_border_rounded),
            ])
              ListTile(
                leading: Icon(icon, color: AppColors.primary),
                title: Text(label),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupSearchScreen(chat: chat, onJump: onJump, filter: f, title: label))),
              ),
          ]),
        ),
        const SectionTitle('Guruh qoidalari'),
        Glass(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final r in groupRules)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(padding: EdgeInsets.only(top: 6), child: Icon(Icons.circle, size: 6, color: AppColors.primary)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(r, style: const TextStyle(height: 1.4))),
                ]),
              ),
          ]),
        ),
        const SectionTitle('Shahar guruhi'),
        Glass(
          padding: EdgeInsets.zero,
          child: RadioGroup<String>(
            groupValue: chat.city,
            onChanged: (v) async {
              if (v == null || v == chat.city) return;
              Navigator.of(context).popUntil((r) => r.isFirst);
              await ChatHub.instance.setCity(v);
            },
            child: Column(children: [
              for (final e in groupCities.entries) RadioListTile<String>(value: e.key, title: Text(e.value.name), subtitle: Text(e.value.region)),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// Search and filtered views of the group (media, voice, links, saved).
class GroupSearchScreen extends StatefulWidget {
  const GroupSearchScreen({super.key, required this.chat, required this.onJump, this.filter = 'all', this.title});
  final GroupChat chat;
  final Future<void> Function(int id) onJump;
  final String filter;
  final String? title;

  @override
  State<GroupSearchScreen> createState() => _GroupSearchScreenState();
}

class _GroupSearchScreenState extends State<GroupSearchScreen> {
  List<GroupMessage> results = [];
  bool loading = false;
  String q = '';

  @override
  void initState() {
    super.initState();
    if (widget.filter != 'all') _run();
  }

  Future<void> _run() async {
    setState(() => loading = true);
    try {
      final r = await widget.chat.search(q: q, filter: widget.filter);
      if (mounted) setState(() => results = r);
    } catch (e) {
      if (mounted) toast(context, errorText(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: widget.filter == 'all'
            ? TextField(
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: (v) => q = v,
                onSubmitted: (_) => _run(),
                decoration: const InputDecoration(hintText: 'Guruhdan qidirish…', filled: false, border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none),
              )
            : Text(widget.title ?? ''),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : results.isEmpty
              ? EmptyState(icon: Icons.search_off_rounded, title: widget.filter == 'all' && q.isEmpty ? 'So‘z yozing va qidiring' : 'Hech narsa topilmadi')
              : ListView.separated(
                  itemCount: results.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
                  itemBuilder: (context, i) {
                    final m = results[i];
                    final p = Profiles.instance.of(m.userId);
                    return ListTile(
                      leading: UserAvatar(id: m.userId, name: p.displayName, url: p.avatarUrl),
                      title: Text(p.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(m.preview, maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: Text(listTime(m.createdAt), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                      onTap: () async {
                        Navigator.of(context).popUntil((r) => r.settings.name == 'group' || r.isFirst);
                        await widget.onJump(m.id);
                      },
                    );
                  },
                ),
    );
  }
}
