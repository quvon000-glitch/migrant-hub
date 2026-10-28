import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/supa.dart';
import '../../models/conversation.dart';
import '../../models/group_message.dart' show SendState;
import '../../state/ads_store.dart';
import '../../state/profiles.dart';
import '../../state/inbox.dart';
import '../../theme.dart';
import '../ads/ad_detail_screen.dart';
import '../widgets/common.dart';
import 'bubble.dart';
import 'composer.dart';
import 'user_profile_sheet.dart';

class DmThreadScreen extends StatefulWidget {
  const DmThreadScreen({super.key, required this.conversationId});
  final int conversationId;

  @override
  State<DmThreadScreen> createState() => _DmThreadScreenState();
}

class _DmThreadScreenState extends State<DmThreadScreen> {
  late final DmThread t = DmThread(widget.conversationId);
  DmMessage? replyTo;
  DmMessage? editing;

  @override
  void initState() {
    super.initState();
    t.addListener(_changed);
    Profiles.instance.addListener(_changed);
    t.start();
  }

  void _changed() {
    if (!mounted) return;
    if (t.error != null && !t.loading) {
      final e = t.error!;
      t.error = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? toast(context, e) : null);
    }
    setState(() {});
  }

  @override
  void dispose() {
    t.removeListener(_changed);
    Profiles.instance.removeListener(_changed);
    t.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    if (editing != null) {
      final m = editing!;
      setState(() => editing = null);
      try {
        await t.edit(m, text);
      } catch (e) {
        if (mounted) toast(context, errorText(e));
      }
      return;
    }
    final r = replyTo?.id;
    setState(() => replyTo = null);
    await t.send(text, replyTo: r);
  }

  Future<void> _menu(DmMessage m) async {
    final mine = m.senderId == myId;
    if (m.state == SendState.failed) {
      final a = await pickFrom<String>(context, 'Yuborilmadi', [('retry', 'Qayta yuborish', Icons.refresh), ('discard', 'O‘chirish', Icons.delete_outline)]);
      if (a == 'retry') await t.retry(m);
      if (a == 'discard') t.discard(m);
      return;
    }
    if (m.id < 0 || m.deleted) return;
    final a = await pickFrom<String>(context, 'Xabar', [
      ('reply', 'Javob berish', Icons.reply_rounded),
      ('copy', 'Nusxa olish', Icons.copy_rounded),
      if (mine && DateTime.now().difference(m.createdAt).inHours < 48) ('edit', 'Tahrirlash', Icons.edit_outlined),
      if (mine) ('delete', 'Hamma uchun o‘chirish', Icons.delete_outline),
    ]);
    if (!mounted || a == null) return;
    try {
      switch (a) {
        case 'reply':
          setState(() => replyTo = m);
        case 'copy':
          await Clipboard.setData(ClipboardData(text: m.body));
          if (mounted) toast(context, 'Nusxa olindi');
        case 'edit':
          setState(() => editing = m);
        case 'delete':
          if (await confirm(context, 'Xabarni o‘chirasizmi?', ok: 'O‘chirish', danger: true)) await t.delete(m);
      }
    } catch (e) {
      if (mounted) toast(context, errorText(e));
    }
  }

  Future<void> _more() async {
    final other = t.otherId;
    if (other == null) return;
    final a = await pickFrom<String>(context, 'Yozishma', [
      ('profile', 'Profilni ko‘rish', Icons.person_outline),
      ('report', 'Shikoyat qilish', Icons.flag_outlined),
      ('hide', 'Yozishmani o‘chirish', Icons.delete_outline),
    ]);
    if (!mounted || a == null) return;
    if (a == 'profile') await showUserProfile(context, other);
    if (a == 'report' && mounted) {
      final r = await pickFrom<String>(context, 'Shikoyat sababi', [for (final x in ['Firibgarlik', 'Haqoratli muomala', 'Spam yoki reklama', 'Boshqa']) (x, x, Icons.flag_outlined)]);
      if (r == null) return;
      await AdsStore.instance.report(reason: r, userId: other, conversationId: widget.conversationId);
      if (mounted) toast(context, 'Shikoyat yuborildi');
    }
    if (a == 'hide') {
      await supa.rpc('conversation_hide', params: {'p_conv': widget.conversationId});
      unawaited(Inbox.instance.refresh());
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final other = t.otherId;
    final p = other == null ? null : Profiles.instance.of(other);
    final adId = (t.conv?['ad_id'] as num?)?.toInt();
    final ad = adId == null ? null : AdsStore.instance.byId(adId);
    final list = t.messages.reversed.toList();
    return Scaffold(
      backgroundColor: AppColors.chatBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        titleSpacing: 0,
        title: InkWell(
          onTap: other == null ? null : () => showUserProfile(context, other),
          child: Row(children: [
            UserAvatar(id: other ?? '', name: p?.displayName ?? '…', url: p?.avatarUrl, size: 40),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p?.displayName ?? '…', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                Text(t.otherTyping ? 'yozmoqda…' : lastSeen(p?.lastSeenAt), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: t.otherTyping ? AppColors.primary : AppColors.muted)),
              ]),
            ),
          ]),
        ),
        actions: [IconButton(onPressed: _more, icon: const Icon(Icons.more_vert))],
      ),
      body: Column(children: [
        if (t.conv != null)
          Material(
            color: Colors.white,
            child: InkWell(
              onTap: ad == null ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdDetailScreen(ad: ad))),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.line), bottom: BorderSide(color: AppColors.line))),
                child: Row(children: [
                  if (ad?.photos.isNotEmpty == true) ClipRRect(borderRadius: BorderRadius.circular(8), child: CachedNetworkImage(imageUrl: ad!.photos.first, width: 40, height: 40, fit: BoxFit.cover)) else const Icon(Icons.sell_outlined, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(ad?.title ?? t.conv!['ad_title'] as String? ?? 'E’lon', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(ad == null ? 'E’lon yopilgan' : ad.priceText, style: const TextStyle(color: AppColors.primary, fontSize: 13)),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        Expanded(
          child: t.loading && list.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : list.isEmpty
                  ? const Center(child: EmptyState(icon: Icons.waving_hand_outlined, title: 'Salom yozing!', text: 'E’lon bo‘yicha savolingizni yozing.'))
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final m = list[i];
                        final older = i + 1 < list.length ? list[i + 1] : null;
                        final newer = i > 0 ? list[i - 1] : null;
                        final showDay = older == null || !sameDay(older.createdAt, m.createdAt);
                        final lastInRun = newer == null || newer.senderId != m.senderId;
                        return Column(children: [if (showDay) DateChip(m.createdAt), _bubble(m, lastInRun)]);
                      },
                    ),
        ),
        Composer(
          onSend: _send,
          onTyping: t.typing,
          editText: editing?.body,
          context_: editing != null
              ? ComposerContext('Tahrirlash', editing!.body, Icons.edit_rounded)
              : replyTo != null
                  ? ComposerContext('Javob', replyTo!.body, Icons.reply_rounded)
                  : null,
          onCancelContext: () => setState(() {
            replyTo = null;
            editing = null;
          }),
        ),
      ]),
    );
  }

  Widget _bubble(DmMessage m, bool lastInRun) {
    final mine = m.senderId == myId;
    DmMessage? reply;
    if (m.replyToId != null) {
      for (final x in t.messages) {
        if (x.id == m.replyToId) reply = x;
      }
    }
    final meta = MessageMeta(time: m.createdAt, edited: m.editedAt != null, tick: tickFor(mine: mine, state: m.state, seen: t.isSeen(m)));
    return BubbleRow(
      key: ValueKey(m.clientId),
      mine: mine,
      lastInRun: lastInRun,
      onReply: m.id < 0 || m.deleted ? null : () => setState(() => replyTo = m),
      onMenu: () => _menu(m),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        if (m.replyToId != null) ReplyQuote(name: reply == null ? 'Xabar' : (reply.senderId == myId ? 'Siz' : Profiles.instance.of(reply.senderId).displayName), text: reply?.body ?? 'Oldingi xabar'),
        Stack(children: [
          m.deleted
              ? Padding(padding: EdgeInsets.only(right: MessageMeta.width), child: const Text('Xabar o‘chirildi', style: TextStyle(fontStyle: FontStyle.italic, color: AppColors.muted)))
              : RichMessageText(m.body, trailingSpace: MessageMeta.width + (m.editedAt != null ? 64 : 0) + (mine ? 18 : 0)),
          Positioned(right: 0, bottom: 0, child: meta),
        ]),
      ]),
    );
  }
}
