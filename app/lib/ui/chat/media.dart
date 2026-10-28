import 'dart:async';
import 'dart:io' show File;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';

import '../../core/files.dart';
import '../../core/format.dart';
import '../../theme.dart';

/// Full-screen photo with pinch-zoom.
class ImageViewer extends StatelessWidget {
  const ImageViewer({super.key, this.url, this.file, required this.tag});
  final String? url;
  final String? file;
  final Object tag;

  static void open(BuildContext context, {String? url, String? file, required Object tag}) =>
      Navigator.push(context, PageRouteBuilder(opaque: false, pageBuilder: (_, _, _) => ImageViewer(url: url, file: file, tag: tag), transitionsBuilder: (_, a, _, c) => FadeTransition(opacity: a, child: c)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: GestureDetector(
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0).abs() > 600) Navigator.pop(context);
        },
        child: Center(
          child: Hero(
            tag: tag,
            child: InteractiveViewer(
              maxScale: 5,
              child: file != null ? localImage(file!) : CachedNetworkImage(imageUrl: url!, fit: BoxFit.contain, placeholder: (_, _) => const CircularProgressIndicator(color: Colors.white)),
            ),
          ),
        ),
      ),
    );
  }
}

class VideoScreen extends StatefulWidget {
  const VideoScreen({super.key, this.url, this.file});
  final String? url;
  final String? file;

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  late final VideoPlayerController c = widget.file != null && !kIsWeb
      ? VideoPlayerController.file(File(widget.file!))
      : VideoPlayerController.networkUrl(Uri.parse(widget.url ?? widget.file!));

  @override
  void initState() {
    super.initState();
    c.initialize().then((_) {
      if (mounted) setState(() {});
      c.play();
    });
    c.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: Center(
        child: !c.value.isInitialized
            ? const CircularProgressIndicator(color: Colors.white)
            : GestureDetector(
                onTap: () => c.value.isPlaying ? c.pause() : c.play(),
                child: Stack(alignment: Alignment.center, children: [
                  AspectRatio(aspectRatio: c.value.aspectRatio, child: VideoPlayer(c)),
                  if (!c.value.isPlaying) const Icon(Icons.play_circle_fill, color: Colors.white70, size: 72),
                  Positioned(left: 0, right: 0, bottom: 0, child: VideoProgressIndicator(c, allowScrubbing: true, padding: const EdgeInsets.all(12))),
                ]),
              ),
      ),
    );
  }
}

/// Inline voice message player. Only one plays at a time.
class VoicePlayer extends StatefulWidget {
  const VoicePlayer({super.key, this.url, this.file, this.duration, required this.mine});
  final String? url;
  final String? file;
  final int? duration;
  final bool mine;

  @override
  State<VoicePlayer> createState() => _VoicePlayerState();
}

class _VoicePlayerState extends State<VoicePlayer> {
  static _VoicePlayerState? _current;
  AudioPlayer? _p;
  StreamSubscription? _s1, _s2;
  bool playing = false;
  Duration pos = Duration.zero;
  Duration? total;

  Future<void> toggle() async {
    if (_p == null) {
      final p = AudioPlayer();
      _p = p;
      _s1 = p.positionStream.listen((d) => mounted ? setState(() => pos = d) : null);
      _s2 = p.playerStateStream.listen((s) {
        if (s.processingState == ProcessingState.completed) {
          p.pause();
          p.seek(Duration.zero);
        }
        if (mounted) setState(() => playing = s.playing && s.processingState != ProcessingState.completed);
      });
      total = widget.file != null && !kIsWeb ? await p.setFilePath(widget.file!) : await p.setUrl(widget.url ?? widget.file!);
    }
    if (playing) {
      await _p!.pause();
    } else {
      if (_current != null && _current != this) await _current!._p?.pause();
      _current = this;
      await _p!.play();
    }
  }

  @override
  void dispose() {
    if (_current == this) _current = null;
    _s1?.cancel();
    _s2?.cancel();
    _p?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = total?.inMilliseconds ?? (widget.duration ?? 0) * 1000;
    final progress = t == 0 ? 0.0 : (pos.inMilliseconds / t).clamp(0.0, 1.0);
    final color = AppColors.primary;
    return SizedBox(
      width: 210,
      child: Row(children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: toggle,
            child: Padding(padding: const EdgeInsets.all(9), child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 26)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: progress, minHeight: 4, backgroundColor: color.withValues(alpha: .18), color: color)),
            const SizedBox(height: 5),
            Text(mmss((playing || pos > Duration.zero ? pos.inMilliseconds : t) / 1000), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ]),
        ),
      ]),
    );
  }
}
