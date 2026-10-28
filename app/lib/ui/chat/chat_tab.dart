import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/supa.dart';
import '../../models/conversation.dart';
import '../../state/chat_hub.dart';
import '../../state/group_chat.dart';
import '../../state/inbox.dart';
import '../../state/profiles.dart';
import '../../theme.dart';
import '../widgets/common.dart';
import 'dm_thread_screen.dart';
import 'group_chat_screen.dart';

void openGroupChat(BuildContext context, GroupChat chat) =>
    Navigator.push(context, MaterialPageRoute(settings: const RouteSettings(name: 'group'), builder: (_) => GroupChatScreen(chat: chat)));

void openDm(BuildContext context, int conversationId) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => DmThreadScreen(conversationId: conversationId)));

/// Chats list: the city group on top, then ad conversations — like Telegram's chat list.
class ChatTab extends StatelessWidget {
  const ChatTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: ListenableBuilder(
        listenable: Listenable.merge([ChatHub.instance, Inbox.instance]),
        builder: (context, _) {
          final group = ChatHub.instance.group;
          final convs = Inbox.instance.items;
          return RefreshIndicator(
            onRefresh: () async {
              await Inbox.instance.refresh();
              await group?.reload();
            },
            child: ListView(children: [
              if (group == null) const _CityPicker() else _GroupTile(chat: group),
              const Divider(height: 1, indent: 82),
              if (convs.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: EmptyState(icon: Icons.chat_outlined, title: 'Shaxsiy yozishmalar yo‘q', text: 'E’lon egasiga «Yozish» tugmasi orqali xabar yuborsangiz, yozishma shu yerda paydo bo‘ladi.'),
                ),
              for (final c in convs) ...[_ConvTile(c: c), const Divider(height: 1, indent: 82)],
            ]),
          );
        },
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.chat});
  final GroupChat chat;

  @override
  Widget build(BuildContext context) {
    final info = groupCities[chat.city]!;
    final msgs = chat.messages;
    final last = msgs.isEmpty ? null : msgs.last;
    final typing = chat.typingNames;
    String sub;
    if (typing.isNotEmpty) {
      sub = '${typing.first} yozmoqda…';
    } else if (last == null) {
      sub = 'Guruhga xush kelibsiz!';
    } else {
      final who = last.userId == myId ? 'Siz' : Profiles.instance.of(last.userId).displayName;
      sub = '$who: ${last.preview}';
    }
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      onTap: () => openGroupChat(context, chat),
      leading: Container(
        width: 54,
        height: 54,
        alignment: Alignment.center,
        decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [AppColors.teal, AppColors.navy])),
        child: Text(info.initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      ),
      title: Row(children: [
        const Icon(Icons.groups_rounded, size: 18, color: AppColors.muted),
        const SizedBox(width: 4),
        Expanded(child: Text('${info.name} guruhi', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
        if (last != null) Text(listTime(last.createdAt), style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
      ]),
      subtitle: Row(children: [
        Expanded(child: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: typing.isNotEmpty ? AppColors.primary : AppColors.muted))),
        CountBadge(chat.unread, color: AppColors.primary),
      ]),
    );
  }
}

class _CityPicker extends StatelessWidget {
  const _CityPicker();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Glass(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Shahar guruhini tanlang', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text('Bu bir marta tanlanadi, keyin guruh ma’lumotlarida o‘zgartirish mumkin.', style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 12),
          for (final e in groupCities.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton(
                onPressed: () async {
                  try {
                    await ChatHub.instance.setCity(e.key);
                  } catch (err) {
                    if (context.mounted) toast(context, errorText(err));
                  }
                },
                child: Row(children: [Text(e.value.name, style: const TextStyle(fontWeight: FontWeight.w700)), const Spacer(), Text(e.value.initials)]),
              ),
            ),
        ]),
      ),
    );
  }
}

class _ConvTile extends StatelessWidget {
  const _ConvTile({required this.c});
  final Conversation c;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('conv-${c.id}'),
      direction: DismissDirection.endToStart,
      background: Container(color: AppColors.danger, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 24), child: const Icon(Icons.delete_outline, color: Colors.white)),
      confirmDismiss: (_) => confirm(context, 'Yozishmani o‘chirasizmi?', text: 'Faqat siz uchun o‘chiriladi.', ok: 'O‘chirish', danger: true),
      onDismissed: (_) => Inbox.instance.hide(c),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        onTap: () => openDm(context, c.id),
        leading: Stack(clipBehavior: Clip.none, children: [
          UserAvatar(id: c.otherUserId, name: c.otherName, url: c.otherAvatar, size: 54),
          if (c.adPhoto != null)
            Positioned(
              right: -4,
              bottom: -4,
              child: Container(
                decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 2), borderRadius: BorderRadius.circular(8)),
                child: ClipRRect(borderRadius: BorderRadius.circular(6), child: CachedNetworkImage(imageUrl: c.adPhoto!, width: 24, height: 24, fit: BoxFit.cover)),
              ),
            ),
        ]),
        title: Row(children: [
          Expanded(child: Text(c.otherName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
          if (c.lastFromMe) Icon(c.otherReadAt.isBefore(c.lastMessageAt) ? Icons.done : Icons.done_all, size: 16, color: c.otherReadAt.isBefore(c.lastMessageAt) ? AppColors.teal : AppColors.tickSeen),
          const SizedBox(width: 4),
          Text(listTime(c.lastMessageAt), style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
        ]),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c.adTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.primary, fontSize: 12.5, fontWeight: FontWeight.w600)),
          Row(children: [
            Expanded(child: Text('${c.lastFromMe ? 'Siz: ' : ''}${c.lastMessage ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted))),
            CountBadge(c.unread, color: AppColors.primary),
          ]),
        ]),
      ),
    );
  }
}
