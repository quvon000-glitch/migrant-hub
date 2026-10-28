import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../models/group_message.dart' show SendState;
import '../../theme.dart';

enum Tick { none, sending, sent, seen, failed }

Tick tickFor({required bool mine, required SendState state, required bool seen}) {
  if (!mine) return Tick.none;
  if (state == SendState.failed) return Tick.failed;
  if (state == SendState.sending) return Tick.sending;
  return seen ? Tick.seen : Tick.sent;
}

class MessageMeta extends StatelessWidget {
  const MessageMeta({super.key, required this.time, this.edited = false, this.tick = Tick.none, this.pinned = false, this.saved = false, this.onMedia = false, this.hiddenCount});
  final DateTime time;
  final bool edited, pinned, saved, onMedia;
  final Tick tick;
  final int? hiddenCount;

  static const width = 62.0;

  @override
  Widget build(BuildContext context) {
    final color = onMedia ? Colors.white : AppColors.muted;
    final row = Row(mainAxisSize: MainAxisSize.min, children: [
      if (hiddenCount != null) Text('yashirildi·$hiddenCount ', style: const TextStyle(fontSize: 11, color: AppColors.danger)),
      if (edited) Text('tahrirlandi ', style: TextStyle(fontSize: 11, color: color, fontStyle: FontStyle.italic)),
      if (saved) Icon(Icons.bookmark, size: 12, color: color),
      if (pinned) Icon(Icons.push_pin, size: 12, color: color),
      Text(clock(time), style: TextStyle(fontSize: 11.5, color: color)),
      if (tick != Tick.none) const SizedBox(width: 3),
      switch (tick) {
        Tick.sending => Icon(Icons.schedule, size: 13, color: color),
        Tick.sent => Icon(Icons.done, size: 15, color: onMedia ? Colors.white : AppColors.teal),
        Tick.seen => Icon(Icons.done_all, size: 15, color: onMedia ? Colors.white : AppColors.tickSeen),
        Tick.failed => const Icon(Icons.error_outline, size: 14, color: AppColors.danger),
        Tick.none => const SizedBox.shrink(),
      },
    ]);
    if (!onMedia) return row;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(10)), child: row);
  }
}

/// Text with tappable phone numbers (always) and links (only when allowed, e.g. admins).
class RichMessageText extends StatefulWidget {
  const RichMessageText(this.text, {super.key, this.allowLinks = false, this.trailingSpace = 0, this.style});
  final String text;
  final bool allowLinks;
  final double trailingSpace;
  final TextStyle? style;

  @override
  State<RichMessageText> createState() => _RichMessageTextState();
}

class _RichMessageTextState extends State<RichMessageText> {
  final List<TapGestureRecognizer> _rec = [];
  static final _link = RegExp(r'(https?://[^\s]+|www\.[^\s]+|t\.me/[^\s]+)', caseSensitive: false);
  static final _phone = RegExp(r'(\+?[78][\s(.-]*\d{3}[\s).-]*\d{3}[\s.-]*\d{2}[\s.-]*\d{2}|\+?998[\s(.-]*\d{2}[\s).-]*\d{3}[\s.-]*\d{2}[\s.-]*\d{2})');

  @override
  void dispose() {
    for (final r in _rec) {
      r.dispose();
    }
    super.dispose();
  }

  TextSpan _tap(String text, VoidCallback onTap) {
    final r = TapGestureRecognizer()..onTap = onTap;
    _rec.add(r);
    return TextSpan(text: text, recognizer: r, style: const TextStyle(color: AppColors.tickSeen, decoration: TextDecoration.underline));
  }

  List<InlineSpan> _phones(String s) {
    final out = <InlineSpan>[];
    var last = 0;
    for (final m in _phone.allMatches(s)) {
      if (m.start > last) out.add(TextSpan(text: s.substring(last, m.start)));
      final digits = m[0]!.replaceAll(RegExp(r'\D'), '');
      final tel = digits.startsWith('8') && digits.length == 11 ? '+7${digits.substring(1)}' : '+$digits';
      out.add(_tap(m[0]!, () => launchUrl(Uri.parse('tel:$tel'))));
      last = m.end;
    }
    if (last < s.length) out.add(TextSpan(text: s.substring(last)));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    for (final r in _rec) {
      r.dispose();
    }
    _rec.clear();
    final spans = <InlineSpan>[];
    final t = widget.text;
    if (widget.allowLinks) {
      var last = 0;
      for (final m in _link.allMatches(t)) {
        if (m.start > last) spans.addAll(_phones(t.substring(last, m.start)));
        final raw = m[0]!;
        spans.add(_tap(raw, () => launchUrl(Uri.parse(raw.startsWith('http') ? raw : 'https://$raw'), mode: LaunchMode.externalApplication)));
        last = m.end;
      }
      if (last < t.length) spans.addAll(_phones(t.substring(last)));
    } else {
      spans.addAll(_phones(t));
    }
    if (widget.trailingSpace > 0) spans.add(WidgetSpan(child: SizedBox(width: widget.trailingSpace, height: 12)));
    return Text.rich(TextSpan(children: spans), style: widget.style ?? const TextStyle(fontSize: 15.5, height: 1.32, color: AppColors.ink));
  }
}

/// Telegram-like row: swipe left to reply, long press for the menu, tail on the last bubble of a run.
class BubbleRow extends StatefulWidget {
  const BubbleRow({
    super.key,
    required this.mine,
    required this.child,
    this.avatar,
    this.showAvatarSlot = false,
    this.lastInRun = true,
    this.onReply,
    this.onMenu,
    this.highlight = false,
    this.media = false,
  });

  final bool mine;
  final Widget child;
  final Widget? avatar;
  final bool showAvatarSlot;
  final bool lastInRun;
  final VoidCallback? onReply;
  final VoidCallback? onMenu;
  final bool highlight;
  final bool media;

  @override
  State<BubbleRow> createState() => _BubbleRowState();
}

class _BubbleRowState extends State<BubbleRow> {
  double dx = 0;
  bool fired = false;

  @override
  Widget build(BuildContext context) {
    final r = const Radius.circular(18);
    final small = const Radius.circular(6);
    final radius = BorderRadius.only(
      topLeft: r,
      topRight: r,
      bottomLeft: widget.mine || !widget.lastInRun ? r : small,
      bottomRight: !widget.mine || !widget.lastInRun ? r : small,
    );
    final bubble = AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * (widget.media ? .72 : .78)),
      padding: widget.media ? const EdgeInsets.all(3) : const EdgeInsets.fromLTRB(11, 7, 9, 7),
      decoration: BoxDecoration(
        color: widget.highlight ? AppColors.sky : (widget.mine ? AppColors.bubbleMine : AppColors.bubbleOther),
        borderRadius: radius,
        boxShadow: const [BoxShadow(color: Color(0x14011C40), blurRadius: 3, offset: Offset(0, 1))],
      ),
      child: widget.child,
    );
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPress: widget.onMenu == null
          ? null
          : () {
              HapticFeedback.mediumImpact();
              widget.onMenu!();
            },
      onHorizontalDragUpdate: widget.onReply == null
          ? null
          : (d) {
              final next = (dx + d.delta.dx).clamp(-80.0, 0.0);
              if (!fired && next <= -56) {
                fired = true;
                HapticFeedback.selectionClick();
              }
              setState(() => dx = next);
            },
      onHorizontalDragEnd: widget.onReply == null
          ? null
          : (_) {
              if (fired) widget.onReply!();
              setState(() {
                dx = 0;
                fired = false;
              });
            },
      child: Padding(
        padding: EdgeInsets.only(top: widget.lastInRun ? 2 : 1, bottom: widget.lastInRun ? 6 : 1, left: 8, right: 8),
        child: Stack(alignment: Alignment.centerRight, children: [
          Positioned(
            right: 4,
            child: Opacity(
              opacity: (-dx / 56).clamp(0.0, 1.0),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: Colors.black12, shape: BoxShape.circle),
                child: const Icon(Icons.reply_rounded, size: 18, color: Colors.white),
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(dx, 0),
            child: Row(
              mainAxisAlignment: widget.mine ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!widget.mine && widget.showAvatarSlot) ...[
                  SizedBox(width: 34, child: widget.lastInRun ? widget.avatar : null),
                  const SizedBox(width: 6),
                ],
                Flexible(child: bubble),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class ReplyQuote extends StatelessWidget {
  const ReplyQuote({super.key, required this.name, required this.text, this.color = AppColors.primary, this.onTap});
  final String name;
  final String text;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 5),
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 5),
        decoration: BoxDecoration(color: color.withValues(alpha: .09), borderRadius: BorderRadius.circular(8), border: Border(left: BorderSide(color: color, width: 3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
          Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: AppColors.ink)),
        ]),
      ),
    );
  }
}

class DateChip extends StatelessWidget {
  const DateChip(this.date, {super.key});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: .16), borderRadius: BorderRadius.circular(14)),
        child: Text(dayLabel(date), style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
