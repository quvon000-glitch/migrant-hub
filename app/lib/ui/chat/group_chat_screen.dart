import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:video_player/video_player.dart';

import '../../core/format.dart';
import '../../core/supa.dart';
import '../../models/group_message.dart';
import '../../state/group_chat.dart';
import '../../state/profiles.dart';
import '../../theme.dart';
import '../widgets/common.dart';
import 'bubble.dart';
import 'composer.dart';
import 'group_info_screen.dart';
import 'media.dart';
import 'user_profile_sheet.dart';

class GroupChatScreen extends StatefulWidget {
  const GroupChatScreen({super.key, required this.chat});
  final GroupChat chat;

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _Entry {
  final GroupMessage? m;
  final DateTime? day;
  const _Entry.msg(this.m) : day = null;
  const _Entry.day(this.day) : m = null;
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  GroupChat get chat => widget.chat;
  final items = ItemScrollController();
  final positions = ItemPositionsListener.create();
  GroupMessage? replyTo;
  GroupMessage? editing;
  int? highlight;
  bool showDown = false;
  int newBelow = 0;
  List<_Entry> entries = [];
  StreamSubscription? _inSub, _noteSub;

  @override
  void initState() {
    super.initState();
    chat.setVisible(true);
    chat.addListener(_rebuild);
    Profiles.instance.addListener(_rebuild);
    positions.itemPositions.addListener(_onScroll);
    _inSub = chat.onIncoming.listen((_) {
      if (showDown) setState(() => newBelow++);
    });
    _noteSub = chat.notices.listen((t) {
      if (mounted) _alert(t);
    });
    _build();
  }

  @override
  void dispose() {
    chat.setVisible(false);
    chat.removeListener(_rebuild);
    Profiles.instance.removeListener(_rebuild);
    positions.itemPositions.removeListener(_onScroll);
    _inSub?.cancel();
    _noteSub?.cancel();
    super.dispose();
  }

  void _alert(String text) => showDialog(context: context, builder: (c) => AlertDialog(content: Text(text), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Tushunarli'))]));

  void _rebuild() {
    if (!mounted) return;
    setState(_build);
  }

  void _build() {
    final asc = <_Entry>[];
    DateTime? prev;
    for (final m in chat.messages) {
      if (prev == null || !sameDay(prev, m.createdAt)) asc.add(_Entry.day(m.createdAt));
      asc.add(_Entry.msg(m));
      prev = m.createdAt;
    }
    entries = asc.reversed.toList();
  }

  void _onScroll() {
    final pos = positions.itemPositions.value;
    if (pos.isEmpty) return;
    final minIdx = pos.map((p) => p.index).reduce((a, b) => a < b ? a : b);
    final maxIdx = pos.map((p) => p.index).reduce((a, b) => a > b ? a : b);
    final down = minIdx > 1;
    if (down != showDown) setState(() => showDown = down);
    if (!down && newBelow != 0) setState(() => newBelow = 0);
    if (maxIdx >= entries.length - 4 && chat.hasMore && !chat.loadingOlder) chat.loadOlder();
  }

  void _toBottom() {
    if (entries.isEmpty) return;
    items.scrollTo(index: 0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    setState(() => newBelow = 0);
  }

  Future<void> _jumpTo(int id) async {
    var i = entries.indexWhere((e) => e.m?.id == id);
    while (i < 0 && chat.hasMore) {
      await chat.loadOlder();
      _build();
      i = entries.indexWhere((e) => e.m?.id == id);
    }
    if (i < 0) {
      if (mounted) toast(context, 'Xabar topilmadi (o‘chirilgan bo‘lishi mumkin)');
      return;
    }
    items.scrollTo(index: i, alignment: .4, duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    setState(() => highlight = id);
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => highlight = null);
    });
  }

  // ---------- sending ----------

  Future<void> _send(String text) async {
    if (editing != null) {
      final m = editing!;
      setState(() => editing = null);
      if (text.trim() == m.body.trim()) return;
      try {
        await chat.edit(m, text);
      } catch (e) {
        if (mounted) _alert(errorText(e));
      }
      return;
    }
    final reply = replyTo?.id;
    setState(() => replyTo = null);
    _toBottom();
    await chat.sendText(text, replyTo: reply);
  }

  Future<void> _attach() async {
    final kind = await pickFrom<String>(context, 'Biriktirish', [
      ('gallery', 'Rasm (galereya)', Icons.photo_library_outlined),
      ('camera', 'Kamera', Icons.photo_camera_outlined),
      ('video', 'Video (60 soniyagacha)', Icons.videocam_outlined),
    ]);
    if (kind == null) return;
    final picker = ImagePicker();
    if (kind == 'video') {
      final x = await picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(seconds: 60));
      if (x == null) return;
      final f = File(x.path);
      if (await f.length() > 40 * 1024 * 1024) {
        if (mounted) _alert('Video 40 MB dan oshmasin');
        return;
      }
      final vc = VideoPlayerController.file(f);
      await vc.initialize();
      final secs = vc.value.duration.inSeconds;
      final size = vc.value.size;
      await vc.dispose();
      if (secs > 61) {
        if (mounted) _alert('Video 60 soniyadan oshmasin');
        return;
      }
      final caption = await _captionDialog(null);
      if (caption == null) return;
      final reply = replyTo?.id;
      setState(() => replyTo = null);
      _toBottom();
      await chat.sendMedia('video', f, caption: caption, replyTo: reply, duration: secs, width: size.width.round(), height: size.height.round());
      return;
    }
    final x = await picker.pickImage(source: kind == 'camera' ? ImageSource.camera : ImageSource.gallery, maxWidth: 2200, maxHeight: 2200, imageQuality: 90);
    if (x == null) return;
    final f = File(x.path);
    final img = await decodeImageFromList(await f.readAsBytes());
    final caption = await _captionDialog(f);
    if (caption == null) return;
    final reply = replyTo?.id;
    setState(() => replyTo = null);
    _toBottom();
    await chat.sendMedia('image', f, caption: caption, replyTo: reply, width: img.width, height: img.height);
  }

  Future<String?> _captionDialog(File? image) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          if (image != null) ClipRRect(borderRadius: BorderRadius.circular(12), child: ConstrainedBox(constraints: const BoxConstraints(maxHeight: 280), child: Image.file(image, fit: BoxFit.cover))),
          if (image == null) const ListTile(leading: Icon(Icons.videocam_rounded), title: Text('Video tanlandi')),
          const SizedBox(height: 10),
          TextField(controller: c, maxLines: 3, minLines: 1, maxLength: 2000, decoration: const InputDecoration(hintText: 'Izoh qo‘shish…', counterText: '')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Bekor qilish')),
          FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(110, 44)), onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Yuborish')),
        ],
      ),
    );
  }

  Future<void> _voice(File f, int secs) async {
    final reply = replyTo?.id;
    setState(() => replyTo = null);
    _toBottom();
    await chat.sendMedia('voice', f, replyTo: reply, duration: secs);
  }

  // ---------- menu ----------

  Future<void> _menu(GroupMessage m) async {
    final mine = m.userId == myId;
    final admin = chat.me.isAdmin;
    if (m.state == SendState.failed) {
      final a = await pickFrom<String>(context, m.error ?? 'Yuborilmadi', [('retry', 'Qayta yuborish', Icons.refresh), ('discard', 'O‘chirish', Icons.delete_outline)]);
      if (a == 'retry') await chat.retry(m);
      if (a == 'discard') chat.discard(m);
      return;
    }
    if (m.isLocal) return;
    final saved = chat.saved.contains(m.id);
    final a = await pickFrom<String>(context, 'Xabar', [
      ('reply', 'Javob berish', Icons.reply_rounded),
      if (m.body.isNotEmpty) ('copy', 'Nusxa olish', Icons.copy_rounded),
      if (mine && (m.kind == 'text' || m.body.isNotEmpty)) ('edit', 'Tahrirlash', Icons.edit_outlined),
      ('save', saved ? 'Saqlanganlardan olish' : 'Saqlash', saved ? Icons.bookmark_remove_outlined : Icons.bookmark_add_outlined),
      if (admin) ('pin', m.pinned ? 'Mahkamlashni bekor qilish' : 'Mahkamlash', Icons.push_pin_outlined),
      if (admin && m.hidden) ('restore', 'Qayta ko‘rsatish', Icons.visibility_outlined),
      if (!mine) ('report', 'Shikoyat qilish', Icons.flag_outlined),
      if (mine || admin) ('delete', 'O‘chirish', Icons.delete_outline),
      if (admin && !mine) ('punish', 'O‘chirish va jazolash', Icons.gavel_rounded),
    ]);
    if (!mounted || a == null) return;
    try {
      switch (a) {
        case 'reply':
          setState(() {
            editing = null;
            replyTo = m;
          });
        case 'copy':
          await Clipboard.setData(ClipboardData(text: m.body));
          if (mounted) toast(context, 'Nusxa olindi');
        case 'edit':
          setState(() {
            replyTo = null;
            editing = m;
          });
        case 'save':
          await chat.toggleSave(m);
          if (mounted) toast(context, saved ? 'Saqlanganlardan olindi' : 'Saqlandi');
        case 'pin':
          await chat.pin(m, !m.pinned);
        case 'restore':
          await chat.restore(m);
        case 'report':
          final r = await pickFrom<String>(context, 'Shikoyat sababi', [for (final x in groupReportReasons) (x, x, Icons.flag_outlined)]);
          if (r == null) return;
          await chat.report(m, r);
          if (mounted) toast(context, 'Shikoyat yuborildi. Rahmat!');
        case 'delete':
          if (await confirm(context, 'Xabarni o‘chirasizmi?', text: 'Xabar hamma uchun o‘chiriladi.', ok: 'O‘chirish', danger: true)) await chat.delete(m);
        case 'punish':
          final rule = await pickFrom<String>(context, 'Qaysi qoida buzildi?', [('card', 'Bank kartasi', Icons.credit_card_off), ('pay', 'Kunlik 8 000 ₽ dan yuqori maosh', Icons.money_off), ('sex', 'Intim xizmatlar', Icons.block)]);
          if (rule == null) return;
          final note = await chat.punish(m, rule);
          if (mounted && note != null) _alert(note);
      }
    } catch (e) {
      if (mounted) _alert(errorText(e));
    }
  }

  // ---------- build ----------

  @override
  Widget build(BuildContext context) {
    final info = groupCities[chat.city]!;
    final typing = chat.typingNames;
    final subtitle = !chat.connected && !chat.loading
        ? 'ulanmoqda…'
        : typing.isNotEmpty
            ? (typing.length == 1 ? '${typing.first} yozmoqda…' : '${typing.length} kishi yozmoqda…')
            : '${fmtNum(chat.members)} a’zo${chat.online > 0 ? ', ${chat.online} online' : ''}';
    final me = chat.me;
    return Scaffold(
      backgroundColor: AppColors.chatBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        titleSpacing: 0,
        title: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupInfoScreen(chat: chat, onJump: _jumpTo))),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [AppColors.teal, AppColors.navy])),
              child: Text(info.initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${info.name} guruhi', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                Text(subtitle, maxLines: 1, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: typing.isNotEmpty ? AppColors.primary : AppColors.muted)),
              ]),
            ),
          ]),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupSearchScreen(chat: chat, onJump: _jumpTo)))),
        ],
      ),
      body: Column(children: [
        if (chat.pinned != null) _PinnedBar(m: chat.pinned!, onTap: () => _jumpTo(chat.pinned!.id)),
        Expanded(
          child: Stack(children: [
            if (chat.loading && entries.isEmpty)
              const Center(child: CircularProgressIndicator())
            else if (entries.isEmpty)
              Center(child: EmptyState(icon: Icons.forum_outlined, title: 'Hali xabar yo‘q', text: chat.error ?? 'Birinchi bo‘lib salom yozing!'))
            else
              ScrollablePositionedList.builder(
                reverse: true,
                itemScrollController: items,
                itemPositionsListener: positions,
                padding: const EdgeInsets.only(top: 8, bottom: 6),
                itemCount: entries.length + (chat.loadingOlder ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i >= entries.length) return const Padding(padding: EdgeInsets.all(12), child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))));
                  final e = entries[i];
                  if (e.day != null) return DateChip(e.day!);
                  return _bubble(e.m!, i);
                },
              ),
            Positioned(
              right: 12,
              bottom: 12,
              child: AnimatedScale(
                scale: showDown ? 1 : 0,
                duration: const Duration(milliseconds: 160),
                child: Stack(clipBehavior: Clip.none, children: [
                  FloatingActionButton.small(heroTag: 'down', backgroundColor: Colors.white, foregroundColor: AppColors.muted, onPressed: _toBottom, child: const Icon(Icons.keyboard_arrow_down_rounded, size: 30)),
                  if (newBelow > 0) Positioned(top: -6, right: -2, child: CountBadge(newBelow, color: AppColors.primary)),
                ]),
              ),
            ),
          ]),
        ),
        Composer(
          onSend: _send,
          onTyping: chat.typing,
          onAttach: _attach,
          onVoice: _voice,
          blockedText: me.blockedText,
          attachHint: me.textOnly
              ? 'Yangi hisoblar birinchi 24 soat faqat matn yozadi'
              : null,
          editText: editing?.body,
          context_: editing != null
              ? ComposerContext('Tahrirlash', editing!.preview, Icons.edit_rounded)
              : replyTo != null
                  ? ComposerContext('Javob: ${Profiles.instance.of(replyTo!.userId).displayName}', replyTo!.preview, Icons.reply_rounded)
                  : null,
          onCancelContext: () => setState(() {
            replyTo = null;
            editing = null;
          }),
        ),
      ]),
    );
  }

  Widget _bubble(GroupMessage m, int i) {
    final mine = m.userId == myId;
    // entries are newest-first: the "previous" message on screen is i+1, the next one is i-1
    GroupMessage? older, newer;
    if (i + 1 < entries.length) older = entries[i + 1].m;
    if (i - 1 >= 0) newer = entries[i - 1].m;
    bool joined(GroupMessage? a, GroupMessage b) => a != null && a.userId == b.userId && b.createdAt.difference(a.createdAt).abs() < const Duration(minutes: 5);
    final firstInRun = !joined(older, m);
    final lastInRun = !(newer != null && joined(m, newer));
    final p = Profiles.instance.of(m.userId);
    final reply = m.replyToId == null ? null : chat.byId(m.replyToId!);
    final media = m.isMedia && m.body.isEmpty;
    final tick = tickFor(mine: mine, state: m.state, seen: chat.isSeen(m));
    final meta = MessageMeta(
      time: m.createdAt,
      edited: m.edited,
      pinned: m.pinned,
      saved: chat.saved.contains(m.id),
      tick: tick,
      onMedia: media,
      hiddenCount: m.hidden ? m.reportCount : null,
    );

    final parts = <Widget>[];
    if (!mine && firstInRun) {
      parts.add(GestureDetector(
        onTap: () => showUserProfile(context, m.userId),
        child: Padding(
          padding: EdgeInsets.only(bottom: 2, left: m.isMedia ? 6 : 0, top: m.isMedia ? 3 : 0),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(child: Text(p.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.nameColor(m.userId), fontWeight: FontWeight.w700, fontSize: 14))),
            if (p.isAdmin) Container(margin: const EdgeInsets.only(left: 6), padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1), decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .12), borderRadius: BorderRadius.circular(6)), child: const Text('admin', style: TextStyle(fontSize: 10.5, color: AppColors.primary, fontWeight: FontWeight.w700))),
          ]),
        ),
      ));
    }
    if (m.replyToId != null) {
      parts.add(Padding(
        padding: EdgeInsets.symmetric(horizontal: m.isMedia ? 4 : 0),
        child: ReplyQuote(
          name: reply == null ? 'Xabar' : Profiles.instance.of(reply.userId).displayName,
          text: reply?.preview ?? 'Oldingi xabar',
          color: reply == null ? AppColors.primary : AppColors.nameColor(reply.userId),
          onTap: () => _jumpTo(m.replyToId!),
        ),
      ));
    }
    if (m.kind == 'image') parts.add(_image(m, media ? meta : null));
    if (m.kind == 'video') parts.add(_video(m, media ? meta : null));
    if (m.kind == 'voice') {
      parts.add(Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
        m.mediaUrl == null && m.localFile == null ? const Text('🎤 Ovozli xabar o‘chirilgan', style: TextStyle(color: AppColors.muted)) : VoicePlayer(url: m.mediaUrl, file: m.localFile, duration: m.durationSec, mine: mine),
        const SizedBox(width: 8),
        if (m.body.isEmpty) meta,
      ]));
    }
    if (m.body.isNotEmpty) {
      parts.add(Padding(
        padding: EdgeInsets.fromLTRB(m.isMedia ? 6 : 0, m.isMedia ? 4 : 0, m.isMedia ? 6 : 0, m.isMedia ? 3 : 0),
        child: Stack(children: [
          RichMessageText(m.body, allowLinks: p.isAdmin, trailingSpace: MessageMeta.width + (m.edited ? 64 : 0) + (mine ? 18 : 0)),
          Positioned(right: 0, bottom: 0, child: meta),
        ]),
      ));
    } else if (m.kind == 'text') {
      parts.add(meta);
    }

    return BubbleRow(
      key: ValueKey(m.clientId),
      mine: mine,
      showAvatarSlot: true,
      lastInRun: lastInRun,
      media: m.isMedia,
      highlight: highlight == m.id,
      avatar: GestureDetector(onTap: () => showUserProfile(context, m.userId), child: UserAvatar(id: m.userId, name: p.displayName, url: p.avatarUrl, size: 34)),
      onReply: m.isLocal ? null : () => setState(() {
        editing = null;
        replyTo = m;
      }),
      onMenu: () => _menu(m),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: parts),
    );
  }

  Widget _mediaBox(GroupMessage m, Widget child, Widget? meta) {
    final w = (m.width ?? 4).toDouble(), h = (m.height ?? 3).toDouble();
    final ratio = (w / h).clamp(.6, 1.9);
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: AspectRatio(
        aspectRatio: ratio,
        child: Stack(fit: StackFit.expand, children: [
          child,
          if (m.state == SendState.sending) Container(color: Colors.black26, child: const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.6))),
          if (meta != null) Positioned(right: 6, bottom: 6, child: meta),
        ]),
      ),
    );
  }

  Widget _image(GroupMessage m, Widget? meta) {
    if (m.mediaUrl == null && m.localFile == null) return const Padding(padding: EdgeInsets.all(8), child: Text('📷 Rasm o‘chirilgan', style: TextStyle(color: AppColors.muted)));
    final tag = 'img-${m.clientId}';
    return GestureDetector(
      onTap: () => ImageViewer.open(context, url: m.mediaUrl, file: m.mediaUrl == null ? m.localFile : null, tag: tag),
      child: _mediaBox(
        m,
        Hero(
          tag: tag,
          child: m.localFile != null && m.mediaUrl == null
              ? Image.file(File(m.localFile!), fit: BoxFit.cover)
              : CachedNetworkImage(imageUrl: m.mediaUrl!, fit: BoxFit.cover, memCacheWidth: 900, placeholder: (_, _) => Container(color: Colors.black12), errorWidget: (_, _, _) => Container(color: Colors.black12, child: const Icon(Icons.broken_image_outlined))),
        ),
        meta,
      ),
    );
  }

  Widget _video(GroupMessage m, Widget? meta) {
    if (m.mediaUrl == null && m.localFile == null) return const Padding(padding: EdgeInsets.all(8), child: Text('🎬 Video o‘chirilgan', style: TextStyle(color: AppColors.muted)));
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VideoScreen(url: m.mediaUrl, file: m.mediaUrl == null ? m.localFile : null))),
      child: _mediaBox(
        m,
        Container(
          color: Colors.black87,
          child: Stack(alignment: Alignment.center, children: [
            const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 56),
            if (m.durationSec != null) Positioned(left: 8, top: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)), child: Text(mmss(m.durationSec!), style: const TextStyle(color: Colors.white, fontSize: 12)))),
          ]),
        ),
        meta,
      ),
    );
  }
}

class _PinnedBar extends StatelessWidget {
  const _PinnedBar({required this.m, required this.onTap});
  final GroupMessage m;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.line), bottom: BorderSide(color: AppColors.line))),
          child: Row(children: [
            Container(width: 3, height: 32, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Mahkamlangan xabar', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                Text(m.preview, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5)),
              ]),
            ),
            const Icon(Icons.push_pin_outlined, color: AppColors.muted, size: 20),
          ]),
        ),
      ),
    );
  }
}
