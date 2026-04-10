// lib/features/player/presentation/video_player_page.dart
// 视频播放页：页面框架，组合视频组件 + 控制栏 + 手势处理

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';
import '../../../core/constants.dart';
import '../../../core/router/routes.dart';
import '../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../features/cast/presentation/providers/cast_provider.dart';
import '../../../features/cast/presentation/widgets/device_picker_sheet.dart';
import '../../../features/settings/providers/settings_provider.dart';
import '../../../shared/utils/duration_format.dart';
import '../../../shared/utils/url_builder.dart';
import 'providers/player_provider.dart';
import '../data/progress_api.dart';
import 'video_player_controller.dart';
import 'widgets/video_control_bar.dart';
import 'widgets/video_player_widget.dart';

class VideoPlayerPage extends ConsumerStatefulWidget {
  const VideoPlayerPage({
    super.key,
    required this.libraryId,
    required this.fileId,
    this.title = '',
  });

  final String libraryId;
  final String fileId;
  final String title;

  @override
  ConsumerState<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends ConsumerState<VideoPlayerPage> {
  late final VideoPlayerController _controller;
  late final ProgressApi _progressApi;

  // 手势相关
  bool _showControls = true;
  bool _isLongPress = false;
  Timer? _hideControlsTimer;
  double? _dragStartX;
  double? _dragStartY;
  Duration? _dragStartPosition;
  double? _initialBrightness;
  double? _initialVolume;
  bool? _isDraggingHorizontal;
  String? _dragOverlayText;

  @override
  void initState() {
    super.initState();

    _controller = VideoPlayerController();

    final baseUrl =
        ref.read(settingsNotifierProvider.select((s) => s.serverUrl));
    final token =
        ref.read(authNotifierProvider.select((s) => s.valueOrNull?.token)) ??
            '';
    final url = UrlBuilder.videoUrl(baseUrl, widget.fileId, token);

    // 缓存 progressApi 引用，dispose 时 ref 已不可用
    _progressApi = ref.read(progressApiProvider);

    // 打开视频 & 获取进度并行执行
    _controller.initialize(
      url,
      progressFuture: _progressApi.getProgress(widget.fileId),
    );

    _controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    // 触发页面重建以响应全屏切换等
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    // 退出时上报进度
    final position = _controller.positionSeconds;
    final duration = _controller.durationSeconds;
    _controller.dispose();
    _hideControlsTimer?.cancel();
    if (duration > 0) {
      _progressApi
          .reportProgress(widget.fileId, position, duration)
          .catchError((_) {});
    }
    super.dispose();
  }

  void _scheduleHideControls() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _scheduleHideControls();
  }

  // ──── 手势 ────

  void _onDoubleTapLeft() {
    final pos = _controller.position -
        const Duration(seconds: AppConstants.seekSeconds);
    _controller.seek(pos < Duration.zero ? Duration.zero : pos);
    _showSeekOverlay(-AppConstants.seekSeconds);
  }

  void _onDoubleTapRight() {
    final pos = _controller.position +
        const Duration(seconds: AppConstants.seekSeconds);
    final dur = _controller.duration;
    _controller.seek(pos > dur ? dur : pos);
    _showSeekOverlay(AppConstants.seekSeconds);
  }

  void _showSeekOverlay(int seconds) {
    setState(() {
      _dragOverlayText = '${seconds > 0 ? '+' : ''}$seconds 秒';
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _dragOverlayText = null);
    });
  }

  void _onPanEnd() {
    _isDraggingHorizontal = null;
    _dragStartX = null;
    _dragStartY = null;
    _dragStartPosition = null;
    _initialBrightness = null;
    _initialVolume = null;
    setState(() => _dragOverlayText = null);
  }

  // ──── 投屏 ────

  Future<void> _onCastPressed(BuildContext context) async {
    final device = await showDevicePicker(context);
    if (device == null || !mounted) return;

    // 暂停本地播放
    _controller.pause();

    // 投屏
    final baseUrl =
        ref.read(settingsNotifierProvider.select((s) => s.serverUrl));
    final token =
        ref.read(authNotifierProvider.select((s) => s.valueOrNull?.token)) ??
            '';
    final url = UrlBuilder.videoUrl(baseUrl, widget.fileId, token);

    ref.read(castNotifierProvider.notifier).castVideo(
          url: url,
          title: widget.title,
          startPositionSeconds: _controller.position.inSeconds,
        );

    if (mounted) {
      context.push(kRouteCastControl);
    }
  }

  // ──── 构建 ────

  @override
  Widget build(BuildContext context) {
    if (_controller.isFullscreen) {
      return PopScope(
        canPop: false,
        onPopInvoked: (didPop) {
          if (!didPop) _controller.exitFullscreen();
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: _buildPlayerWithGestures(context),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: _buildPlayerWithGestures(context),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerWithGestures(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final viewPadding = MediaQuery.of(context).viewPadding;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleControls,
      onDoubleTapDown: (details) {
        final isLeft = details.localPosition.dx < size.width / 2;
        isLeft ? _onDoubleTapLeft() : _onDoubleTapRight();
      },
      onLongPressStart: (_) {
        setState(() => _isLongPress = true);
        _controller.setRate(AppConstants.longPressRate);
      },
      onLongPressEnd: (_) {
        setState(() => _isLongPress = false);
        _controller.setRate(1.0);
      },
      onPanStart: (details) {
        _dragStartX = details.localPosition.dx;
        _dragStartY = details.localPosition.dy;
        _dragStartPosition = _controller.position;
        _isDraggingHorizontal = null;
        ScreenBrightness().current.then((v) => _initialBrightness = v);
        VolumeController().getVolume().then((v) => _initialVolume = v);
      },
      onPanUpdate: (details) {
        if (_dragStartX == null) return;

        final dx = details.localPosition.dx - _dragStartX!;
        final dy = details.localPosition.dy - _dragStartY!;

        _isDraggingHorizontal ??= dx.abs() > dy.abs();

        if (_isDraggingHorizontal == true) {
          final ratio = dx / size.width;
          final seekDelta = ratio * _controller.duration.inSeconds;
          final newPos =
              _dragStartPosition! + Duration(seconds: seekDelta.round());
          final clamped = newPos.isNegative
              ? Duration.zero
              : newPos > _controller.duration
                  ? _controller.duration
                  : newPos;
          _controller.seek(clamped);
          setState(() {
            _dragOverlayText =
                DurationFormat.format(clamped.inSeconds.toDouble());
          });
        } else if (_isDraggingHorizontal == false) {
          final isLeft = details.localPosition.dx < size.width / 2;
          final delta = -dy / (size.height * 0.8);
          if (isLeft) {
            final newBrightness =
                ((_initialBrightness ?? 0.5) + delta).clamp(0.0, 1.0);
            ScreenBrightness().setScreenBrightness(newBrightness);
            setState(() {
              _dragOverlayText = '亮度 ${(newBrightness * 100).round()}%';
            });
          } else {
            final newVolume =
                ((_initialVolume ?? 0.5) + delta).clamp(0.0, 1.0);
            VolumeController().setVolume(newVolume);
            setState(() {
              _dragOverlayText = '音量 ${(newVolume * 100).round()}%';
            });
          }
        }
      },
      onPanEnd: (_) => _onPanEnd(),
      child: Stack(
        children: [
          // 视频显示组件
          VideoPlayerWidget(controller: _controller),

          // 长按倍速标识
          if (_isLongPress)
            const Positioned(
              top: 24,
              left: 0,
              right: 0,
              child: Center(child: _SpeedBadge()),
            ),

          // 滑动预览文字
          if (_dragOverlayText != null)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _dragOverlayText!,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ),

          // 控制栏
          if (_showControls) ...[
            // 顶部栏
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black54, Colors.transparent],
                  ),
                ),
                padding: EdgeInsets.only(
                  top: _controller.isFullscreen ? viewPadding.top : 4,
                  left: 4,
                  right: 4,
                ),
                child: Row(
                  children: [
                    if (_controller.isFullscreen) ...[
                      IconButton(
                        icon: const Icon(Icons.arrow_back,
                            color: Colors.white),
                        onPressed: _controller.exitFullscreen,
                      ),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ] else ...[
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.cast,
                            color: !_controller.isLoading
                                ? Colors.white
                                : Colors.white38),
                        onPressed: !_controller.isLoading
                            ? () => _onCastPressed(context)
                            : null,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // 底部控制栏
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black54, Colors.transparent],
                  ),
                ),
                padding: EdgeInsets.only(
                  bottom: _controller.isFullscreen
                      ? viewPadding.bottom + 8
                      : 8,
                  left: 16,
                  right: 16,
                ),
                child: VideoControlBar(
                  controller: _controller,
                  onSeek: _scheduleHideControls,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SpeedBadge extends StatelessWidget {
  const _SpeedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fast_forward, color: Colors.white, size: 18),
          SizedBox(width: 4),
          Text('2x', style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}
