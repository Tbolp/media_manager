// lib/features/player/presentation/video_player_page.dart
// 视频播放页（竖屏，标题 + 播放器）

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';
import '../../../core/constants.dart';
import '../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../features/settings/providers/settings_provider.dart';
import '../../../shared/utils/duration_format.dart';
import '../../../shared/utils/url_builder.dart';
import 'providers/player_provider.dart';

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
  late final Player _player;
  late final VideoController _controller;
  bool _controllerReady = false;
  bool _isFullscreen = false;
  bool _isBuffering = false;

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
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    _player = Player();
    _controller = VideoController(_player);

    final baseUrl = ref.read(
      settingsNotifierProvider.select((s) => s.serverUrl),
    );
    final token =
        ref.read(authNotifierProvider.select((s) => s.valueOrNull?.token)) ??
            '';
    final url = UrlBuilder.videoUrl(baseUrl, widget.fileId, token);

    // 并行：获取进度 + 打开视频
    final api = ref.read(progressApiProvider);
    final progressFuture = api.getProgress(widget.fileId);
    final openFuture = _player.open(Media(url), play: false);

    // 等待视频打开
    await openFuture;
    if (!mounted) return;
    setState(() => _controllerReady = true);

    // 等待获取到实际时长（5s 超时）
    Duration? videoDuration;
    try {
      videoDuration = await _player.stream.duration
          .firstWhere((d) => d > Duration.zero)
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // 超时，从头播放
    }

    // 获取进度（此时应该已经完成了）
    final savedProgress = await progressFuture;

    // 有进度且未看完则 seek，否则从头播放
    // savedProgress 现在是秒数
    if (videoDuration != null &&
        savedProgress != null &&
        savedProgress > 0 &&
        videoDuration.inSeconds > 0 &&
        savedProgress / videoDuration.inSeconds < AppConstants.watchedThreshold) {
      final seekTo = Duration(seconds: savedProgress.round());
      await _player.seek(seekTo);
    }

    // seek 完成后再开始播放
    if (!mounted) return;
    await _player.play();

    _player.stream.buffering.listen((v) {
      if (mounted) setState(() => _isBuffering = v);
    });

    _scheduleHideControls();
  }

  @override
  void dispose() {
    // 退出时上报进度
    final position = _player.state.position.inSeconds.toDouble();
    final duration = _player.state.duration.inSeconds.toDouble();
    _player.dispose();
    _hideControlsTimer?.cancel();
    if (_isFullscreen) _exitFullscreen();
    if (duration > 0) {
      ref
          .read(progressApiProvider)
          .reportProgress(widget.fileId, position, duration)
          .catchError((_) {});
    }
    super.dispose();
  }

  void _enterFullscreen() {
    setState(() => _isFullscreen = true);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  void _exitFullscreen() {
    setState(() => _isFullscreen = false);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
    final pos = _player.state.position -
        const Duration(seconds: AppConstants.seekSeconds);
    _player.seek(pos < Duration.zero ? Duration.zero : pos);
    _showSeekOverlay(-AppConstants.seekSeconds);
  }

  void _onDoubleTapRight() {
    final pos = _player.state.position +
        const Duration(seconds: AppConstants.seekSeconds);
    final dur = _player.state.duration;
    _player.seek(pos > dur ? dur : pos);
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

  @override
  Widget build(BuildContext context) {
    if (_isFullscreen) {
      return PopScope(
        canPop: false,
        onPopInvoked: (didPop) {
          if (!didPop) _exitFullscreen();
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: _buildPlayerWithGestures(context),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: _buildPlayerWithGestures(context),
          ),
        ],
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
        if (isLeft) {
          _onDoubleTapLeft();
        } else {
          _onDoubleTapRight();
        }
      },
      onLongPressStart: (_) {
        setState(() => _isLongPress = true);
        _player.setRate(AppConstants.longPressRate);
      },
      onLongPressEnd: (_) {
        setState(() => _isLongPress = false);
        _player.setRate(1.0);
      },
      onPanStart: (details) {
        _dragStartX = details.localPosition.dx;
        _dragStartY = details.localPosition.dy;
        _dragStartPosition = _player.state.position;
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
          final seekDelta = ratio * _player.state.duration.inSeconds;
          final newPos =
              _dragStartPosition! + Duration(seconds: seekDelta.round());
          final clamped = newPos.isNegative
              ? Duration.zero
              : newPos > _player.state.duration
                  ? _player.state.duration
                  : newPos;
          _player.seek(clamped);
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
      child: Container(
        color: Colors.black,
        child: Stack(
          children: [
            // 视频
            Center(
              child: _controllerReady
                  ? Video(
                      controller: _controller,
                      controls: NoVideoControls,
                      fit: BoxFit.contain,
                    )
                  : const CircularProgressIndicator(color: Colors.white),
            ),

            // 缓冲加载指示器
            if (_isBuffering && _controllerReady)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),

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
                    style:
                        const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
              ),

            // 控制栏
            if (_showControls) ...[
              // 顶部（全屏时显示返回按钮和标题）
              if (_isFullscreen)
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
                      top: viewPadding.top,
                      left: 4,
                      right: 4,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back,
                              color: Colors.white),
                          onPressed: _exitFullscreen,
                        ),
                        Expanded(
                          child: Text(
                            widget.title,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // 底部进度条 + 按钮
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
                    bottom: _isFullscreen ? viewPadding.bottom + 8 : 8,
                    left: 16,
                    right: 16,
                  ),
                  child: _ControlBar(
                    player: _player,
                    onSeek: _scheduleHideControls,
                    isFullscreen: _isFullscreen,
                    onToggleFullscreen: () {
                      if (_isFullscreen) {
                        _exitFullscreen();
                      } else {
                        _enterFullscreen();
                      }
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
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

// ──────────────────────────────────────────────
// 底部控制栏
// ──────────────────────────────────────────────
class _ControlBar extends StatefulWidget {
  const _ControlBar({
    required this.player,
    required this.onSeek,
    required this.isFullscreen,
    required this.onToggleFullscreen,
  });

  final Player player;
  final VoidCallback onSeek;
  final bool isFullscreen;
  final VoidCallback onToggleFullscreen;

  @override
  State<_ControlBar> createState() => _ControlBarState();
}

class _ControlBarState extends State<_ControlBar> {
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  bool _buffering = false;
  bool _dragging = false;
  double _dragValue = 0.0;
  double? _seekTarget; // seek 后等待加载期间保持目标位置

  final List<StreamSubscription> _subs = [];

  @override
  void initState() {
    super.initState();
    _position = widget.player.state.position;
    _duration = widget.player.state.duration;
    _playing = widget.player.state.playing;
    _buffering = widget.player.state.buffering;
    _subs.addAll([
      widget.player.stream.position
          .listen((v) { if (mounted && !_dragging) setState(() => _position = v); }),
      widget.player.stream.duration
          .listen((v) { if (mounted) setState(() => _duration = v); }),
      widget.player.stream.playing
          .listen((v) { if (mounted) setState(() => _playing = v); }),
      widget.player.stream.buffering
          .listen((v) {
            if (!mounted) return;
            setState(() {
              _buffering = v;
              if (!v) _seekTarget = null;
            });
          }),
    ]);
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ratio = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 播放/暂停（加载状态下不响应操作）
        GestureDetector(
          onTap: _buffering
              ? null
              : () {
                  _playing
                      ? widget.player.pause()
                      : widget.player.play();
                },
          child: Icon(
            _playing ? Icons.pause : Icons.play_arrow,
            color: _buffering ? Colors.white38 : Colors.white,
            size: 28,
          ),
        ),
        // 进度条
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 10),
              trackHeight: 3,
            ),
            child: Slider(
              value: _dragging
                  ? _dragValue.clamp(0.0, 1.0)
                  : (_seekTarget ?? ratio).clamp(0.0, 1.0),
              onChangeStart: (v) {
                setState(() {
                  _dragging = true;
                  _dragValue = v;
                });
              },
              onChanged: (v) {
                setState(() => _dragValue = v);
              },
              onChangeEnd: (v) {
                final seek = Duration(
                  milliseconds: (v * _duration.inMilliseconds).round(),
                );
                widget.player.seek(seek);
                setState(() {
                  _dragging = false;
                  _seekTarget = v;
                });
                widget.onSeek();
              },
              activeColor: Colors.white,
              inactiveColor: Colors.white38,
            ),
          ),
        ),
        // 播放时间/总时间
        Text(
          '${DurationFormat.format(_dragging ? (_dragValue * _duration.inSeconds).toDouble() : _seekTarget != null ? (_seekTarget! * _duration.inSeconds).toDouble() : _position.inSeconds.toDouble())} / ${DurationFormat.format(_duration.inSeconds.toDouble())}',
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
        const SizedBox(width: 4),
        // 全屏
        GestureDetector(
          onTap: widget.onToggleFullscreen,
          child: Icon(
            widget.isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
            color: Colors.white,
            size: 26,
          ),
        ),
      ],
    );
  }
}
