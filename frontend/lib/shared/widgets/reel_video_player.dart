import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Autoplaying, looping, tap-to-mute video player for a single reel.
class ReelVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final bool autoplay;

  const ReelVideoPlayer({super.key, required this.videoUrl, this.autoplay = true});

  @override
  State<ReelVideoPlayer> createState() => _ReelVideoPlayerState();
}

class _ReelVideoPlayerState extends State<ReelVideoPlayer> {
  late final VideoPlayerController _controller;
  bool _muted = true;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..setLooping(true)
      ..setVolume(0);
    _initialize();
  }

  // A broken/unsupported video source makes initialize() (and play())
  // reject rather than throw synchronously — left uncaught, that becomes an
  // unhandled Future error that crashes the whole app, not just this tile.
  Future<void> _initialize() async {
    try {
      await _controller.initialize();
      if (!mounted) return;
      setState(() => _ready = true);
      if (widget.autoplay) {
        await _controller.play();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  void didUpdateWidget(covariant ReelVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_failed || !_ready) return;
    if (!widget.autoplay) {
      _controller.pause();
    } else {
      _controller.play();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _controller.setVolume(_muted ? 0 : 1);
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.white54, size: 40),
            SizedBox(height: 8),
            Text('Không phát được video này', style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }
    if (!_ready) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    return GestureDetector(
      onTap: _toggleMute,
      child: Stack(
        alignment: Alignment.center,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller.value.size.width,
              height: _controller.value.size.height,
              child: VideoPlayer(_controller),
            ),
          ),
          Positioned(
            bottom: 12,
            right: 12,
            child: Icon(_muted ? Icons.volume_off : Icons.volume_up, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
