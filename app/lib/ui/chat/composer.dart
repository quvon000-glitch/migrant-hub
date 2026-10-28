import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import '../../core/format.dart';
import '../../theme.dart';

class ComposerContext {
  final String title; // "Javob: Ali" or "Tahrirlash"
  final String text;
  final IconData icon;
  const ComposerContext(this.title, this.text, this.icon);
}

/// Message input bar: text, attach, voice recording, reply/edit strip.
class Composer extends StatefulWidget {
  const Composer({
    super.key,
    required this.onSend,
    this.onTyping,
    this.onAttach,
    this.onVoice,
    this.context_,
    this.onCancelContext,
    this.editText,
    this.blockedText,
    this.attachHint,
    this.maxVoiceSec = 30,
  });

  final Future<void> Function(String text) onSend;
  final VoidCallback? onTyping;
  final VoidCallback? onAttach;
  /// [path] is a file path on phones and a blob: URL on the web.
  final Future<void> Function(String path, int seconds, String mime)? onVoice;
  final ComposerContext? context_;
  final VoidCallback? onCancelContext;
  final String? editText; // when set, the field is filled with it once
  final String? blockedText;
  final String? attachHint; // why attaching is not allowed right now
  final int maxVoiceSec;

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final ctrl = TextEditingController();
  final focus = FocusNode();
  AudioRecorder? _rec;
  bool recording = false;
  int seconds = 0;
  Timer? _timer;
  String? _lastEdit;
  String _mime = 'audio/mp4';

  bool get hasText => ctrl.text.trim().isNotEmpty;

  @override
  void didUpdateWidget(covariant Composer old) {
    super.didUpdateWidget(old);
    if (widget.editText != null && widget.editText != _lastEdit) {
      _lastEdit = widget.editText;
      ctrl.text = widget.editText!;
      ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
      focus.requestFocus();
    }
    if (widget.editText == null && _lastEdit != null) {
      _lastEdit = null;
      ctrl.clear();
    }
    if (widget.context_ != null && old.context_ == null) focus.requestFocus();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _rec?.dispose();
    ctrl.dispose();
    focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final t = ctrl.text;
    if (t.trim().isEmpty) return;
    ctrl.clear();
    setState(() {});
    await widget.onSend(t);
  }

  Future<void> _startVoice() async {
    final r = _rec ??= AudioRecorder();
    if (!await r.hasPermission()) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mikrofonga ruxsat bering')));
      return;
    }
    // AAC (m4a) where possible — it plays everywhere, iPhone included; browsers may only offer Opus/WAV
    var encoder = AudioEncoder.aacLc;
    _mime = 'audio/mp4';
    if (!await r.isEncoderSupported(AudioEncoder.aacLc)) {
      if (await r.isEncoderSupported(AudioEncoder.opus)) {
        encoder = AudioEncoder.opus;
        _mime = 'audio/webm';
      } else {
        encoder = AudioEncoder.wav;
        _mime = 'audio/wav';
      }
    }
    final path = kIsWeb ? '' : '${(await getTemporaryDirectory()).path}/${const Uuid().v4()}.m4a';
    await r.start(RecordConfig(encoder: encoder, bitRate: 64000, sampleRate: 44100, numChannels: 1), path: path);
    setState(() {
      recording = true;
      seconds = 0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => seconds++);
      if (seconds >= widget.maxVoiceSec) _stopVoice(send: true);
    });
  }

  Future<void> _stopVoice({required bool send}) async {
    _timer?.cancel();
    final r = _rec;
    if (r == null || !recording) return;
    final secs = seconds;
    setState(() => recording = false);
    if (!send) {
      await r.cancel();
      return;
    }
    final path = await r.stop();
    if (path != null && secs >= 1) await widget.onVoice?.call(path, secs, _mime);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.blockedText != null) {
      return SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.all(14),
          child: Text(widget.blockedText!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.danger, height: 1.4)),
        ),
      );
    }
    final c = widget.context_;
    return Material(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (c != null)
            Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 4, 0),
              child: Row(children: [
                Icon(c.icon, color: AppColors.primary, size: 22),
                const SizedBox(width: 10),
                Container(width: 2.5, height: 34, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13.5)),
                    Text(c.text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5)),
                  ]),
                ),
                IconButton(onPressed: widget.onCancelContext, icon: const Icon(Icons.close, size: 20)),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
            child: recording ? _recordingBar() : _inputBar(),
          ),
        ]),
      ),
    );
  }

  Widget _recordingBar() => Row(children: [
        IconButton(onPressed: () => _stopVoice(send: false), icon: const Icon(Icons.delete_outline, color: AppColors.danger)),
        const Icon(Icons.fiber_manual_record, color: AppColors.danger, size: 14),
        const SizedBox(width: 6),
        Text('${mmss(seconds)} / ${mmss(widget.maxVoiceSec)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const Spacer(),
        const Text('Yozilmoqda…', style: TextStyle(color: AppColors.muted)),
        const SizedBox(width: 8),
        _roundButton(Icons.send_rounded, () => _stopVoice(send: true)),
      ]);

  Widget _inputBar() {
    final editing = widget.editText != null;
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      if (widget.onAttach != null && !editing)
        IconButton(
          onPressed: widget.attachHint != null ? () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.attachHint!))) : widget.onAttach,
          icon: Icon(Icons.attach_file_rounded, color: widget.attachHint != null ? AppColors.muted.withValues(alpha: .5) : AppColors.muted),
        ),
      Expanded(
        child: Container(
          decoration: BoxDecoration(color: AppColors.canvas, borderRadius: BorderRadius.circular(22)),
          child: TextField(
            controller: ctrl,
            focusNode: focus,
            minLines: 1,
            maxLines: 6,
            maxLength: 2000,
            textCapitalization: TextCapitalization.sentences,
            keyboardType: TextInputType.multiline,
            onChanged: (_) {
              setState(() {});
              widget.onTyping?.call();
            },
            decoration: const InputDecoration(
              hintText: 'Xabar',
              counterText: '',
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            ),
          ),
        ),
      ),
      const SizedBox(width: 6),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
        child: hasText || editing || widget.onVoice == null
            ? _roundButton(editing ? Icons.check_rounded : Icons.send_rounded, _send, key: const ValueKey('send'))
            : _roundButton(Icons.mic_rounded, widget.attachHint != null ? () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.attachHint!))) : _startVoice, key: const ValueKey('mic')),
      ),
    ]);
  }

  Widget _roundButton(IconData icon, VoidCallback onTap, {Key? key}) => Material(
        key: key,
        color: AppColors.primary,
        shape: const CircleBorder(),
        child: InkWell(customBorder: const CircleBorder(), onTap: onTap, child: Padding(padding: const EdgeInsets.all(11), child: Icon(icon, color: Colors.white, size: 22))),
      );
}
