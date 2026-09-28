import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../video/local_video_source.dart';
import 'app_theme.dart';
import 'status_badge.dart';

class LocalVideoPlayer extends StatefulWidget {
  const LocalVideoPlayer({
    super.key,
    this.source = const LocalVideoSource(),
  });

  final LocalVideoSource source;

  @override
  State<LocalVideoPlayer> createState() => _LocalVideoPlayerState();
}

class _LocalVideoPlayerState extends State<LocalVideoPlayer>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _loading = true;
  bool _available = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    final available = await widget.source.isAvailable();
    if (!mounted) return;
    if (!available) {
      setState(() {
        _available = false;
        _loading = false;
      });
      return;
    }

    final controller = VideoPlayerController.asset(widget.source.assetPath);
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.play();
      if (!mounted) return;
      setState(() {
        _available = true;
        _loading = false;
      });
    } on Object {
      await controller.dispose();
      if (identical(_controller, controller)) _controller = null;
      if (!mounted) return;
      setState(() {
        _available = false;
        _loading = false;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.resumed) {
      unawaited(controller.play());
    } else {
      unawaited(controller.pause());
    }
  }

  void _togglePlayback() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    setState(() {
      if (controller.value.isPlaying) {
        unawaited(controller.pause());
      } else {
        unawaited(controller.play());
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final controller = _controller;
    _controller = null;
    unawaited(controller?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      key: const Key('local-video-aspect-ratio'),
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF050C0A),
            border: Border.all(
              color: AppTheme.primary.withValues(alpha: 0.2),
            ),
          ),
          child: _buildContent(context),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final controller = _controller;
    if (_loading) {
      return const Center(
        child: SizedBox.square(
          dimension: 34,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      );
    }
    if (!_available || controller == null) {
      return const _LocalVideoPlaceholder();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: controller.value.size.width,
            height: controller.value.size.height,
            child: VideoPlayer(controller),
          ),
        ),
        const Positioned(
          left: 10,
          top: 10,
          child: StatusBadge(
            label: '本地监控视频',
            color: AppTheme.secondary,
            icon: Icons.video_library_outlined,
          ),
        ),
        Positioned(
          right: 10,
          bottom: 10,
          child: IconButton.filledTonal(
            key: const Key('local-video-playback-toggle'),
            tooltip: controller.value.isPlaying ? '暂停' : '继续播放',
            onPressed: _togglePlayback,
            icon: Icon(
              controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
            ),
          ),
        ),
      ],
    );
  }
}

class _LocalVideoPlaceholder extends StatelessWidget {
  const _LocalVideoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('local-video-placeholder'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.video_library_outlined,
              color: AppTheme.primary,
              size: 44,
            ),
            const SizedBox(height: 12),
            Text(
              '猪舍监控视频',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              '本地视频素材待配置',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFA7BDB5),
                  ),
            ),
            const SizedBox(height: 10),
            const StatusBadge(
              label: '监控视频待配置',
              color: AppTheme.warning,
              icon: Icons.schedule_outlined,
            ),
          ],
        ),
      ),
    );
  }
}
