// lib/features/player/presentation/video_player_page.dart
// 视频播放页（沉浸式横屏，media_kit）

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
  });

  final String libraryId;
  final String fileId;

  @override
  ConsumerState<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends ConsumerState<VideoPlayerPage>
    with WidgetsBindingObserver {
  late final Player _player;
  late final VideoController _controller;
  bool _controllerReady = false;
  bool _showControls = true;
  bool _isLongPress = false;
  Timer? _hideControlsTimer;

  // 滑动手势相关
  double? _dragStartX;
  double? _dragStartY;
  Duration? _dragStartPosition;
  double? _initialBrightness;
  double? _initialVolume;
  bool? _isDraggingHorizontal; // null=未决定，true=水平，false=垂直
  String? _dragOverlayText;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enterFullscreen();
    _initPlayer();
  }

  void _enterFullscreen() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  void _exitFullscreen() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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

    // 拉取进度
    final api = ref.read(progressApiProvider);
    final savedProgress = await api.getProgress(widget.fileId);

    await _player.open(Media(url));

    if (!mounted) return;
    setState(() => _controllerReady = true);

    // 续播
    if (savedProgress != null && savedProgress < AppConstants.watchedThreshold) {
      // 等待播放器就绪后 seek
      _player.stream.duration.first.then((duration) {
        if (duration > Duration.zero) {
          final seekTo = Duration(
            milliseconds:
                (savedProgress * duration.inMilliseconds).round(),
          );
          _player.seek(seekTo);
        }
      });
    }

    // 监听进度达到 90% 时上报已看完（通过 reportProgress 触发）
    _player.stream.position.listen((pos) {
      final duration = _player.state.duration;
      if (duration > Duration.zero) {
        final ratio = pos.inMilliseconds / duration.inMilliseconds;
        if (ratio >= AppConstants.watchedThreshold) {
          _reportProgress(force: true);
        }
      }
    });

    _scheduleHideControls();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _reportProgress();
    }
  }

  Future<void> _reportProgress({bool force = false}) async {
    final position = _player.state.position.inSeconds.toDouble();
    final duration = _player.state.duration.inSeconds.toDouble();
    if (duration <= 0) return;
    try {
      await ref
          .read(progressApiProvider)
          .reportProgress(widget.fileId, position, duration);
    } catch (_) {
      // fire-and-forget，忽略错误
    }
  }

  @override
  void dispose() {
    _reportProgress();
    _player.dispose();
    _hideControlsTimer?.cancel();
    _exitFullscreen();
    WidgetsBinding.instance.removeObserver(this);
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
    final pos = _player.state.position - const Duration(seconds: AppConstants.seekSeconds);
    _player.seek(pos < Duration.zero ? Duration.zero : pos);
    _showSeekOverlay(-AppConstants.seekSeconds);
  }

  void _onDoubleTapRight() {
    final pos = _player.state.position + const Duration(seconds: AppConstants.seekSeconds);
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

  void _onHorizontalDragEnd() {
    _isDraggingHorizontal = null;
    _dragStartX = null;
    _dragStartPosition = null;
    setState(() => _dragOverlayText = null);
  }

  void _onVerticalDragEnd() {
    _isDraggingHorizontal = null;
    _dragStartY = null;
    _initialBrightness = null;
    _initialVolume = null;
    setState(() => _dragOverlayText = null);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final viewPadding = MediaQuery.of(context).viewPadding;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleControls,

        // 双击左侧快退 / 右侧快进
        onDoubleTapDown: (details) {
          final isLeft = details.localPosition.dx < size.width / 2;
          if (isLeft) {
            _onDoubleTapLeft();
          } else {
            _onDoubleTapRight();
          }
        },

        // 长按加速
        onLongPressStart: (_) {
          setState(() => _isLongPress = true);
          _player.setRate(AppConstants.longPressRate);
        },
        onLongPressEnd: (_) {
          setState(() => _isLongPress = false);
          _player.setRate(1.0);
        },

        // 水平/垂直滑动
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

          // 决定方向
          _isDraggingHorizontal ??= dx.abs() > dy.abs();

          if (_isDraggingHorizontal == true) {
            // 水平滑动 → seek
            final ratio = dx / size.width;
            final seekDelta = ratio * _player.state.duration.inSeconds;
            final newPos = _dragStartPosition! +
                Duration(seconds: seekDelta.round());
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
            final isLeft =
                details.localPosition.dx < size.width / 2;
            final delta = -dy / (size.height * 0.8);
            if (isLeft) {
              // 左侧 → 亮度
              final newBrightness =
                  ((_initialBrightness ?? 0.5) + delta).clamp(0.0, 1.0);
              ScreenBrightness().setScreenBrightness(newBrightness);
              setState(() {
                _dragOverlayText =
                    '亮度 ${(newBrightness * 100).round()}%';
              });
            } else {
              // 右侧 → 音量
              final newVolume =
                  ((_initialVolume ?? 0.5) + delta).clamp(0.0, 1.0);
              VolumeController().setVolume(newVolume);
              setState(() {
                _dragOverlayText =
                    '音量 ${(newVolume * 100).round()}%';
              });
            }
          }
        },
        onPanEnd: (_) {
          _onHorizontalDragEnd();
          _onVerticalDragEnd();
        },

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

            // 长按倍速标识
            if (_isLongPress)
              const Positioned(
                top: 24,
                left: 0,
                right: 0,
                child: Center(
                  child: _SpeedBadge(),
                ),
              ),

            // 滑动预览文字
            if (_dragOverlayText != null)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _dragOverlayText!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),

            // 控制栏
            if (_showControls) ...[
              // 顶部
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Padding(
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
                        onPressed: () => Navigator.of(context).pop(),
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
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: viewPadding.bottom + 8,
                    left: 16,
                    right: 16,
                  ),
                  child: _ControlBar(
                    player: _player,
                    onSeek: _scheduleHideControls,
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
// 底部控制栏（StatefulWidget，监听 Player stream）
// ──────────────────────────────────────────────
class _ControlBar extends StatefulWidget {
  const _ControlBar({required this.player, required this.onSeek});

  final Player player;
  final VoidCallback onSeek;

  @override
  State<_ControlBar> createState() => _ControlBarState();
}

class _ControlBarState extends State<_ControlBar> {
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  bool _buffering = false;

  final List<StreamSubscription> _subs = [];

  @override
  void initState() {
    super.initState();
    _subs.addAll([
      widget.player.stream.position
          .listen((v) { if (mounted) setState(() => _position = v); }),
      widget.player.stream.duration
          .listen((v) { if (mounted) setState(() => _duration = v); }),
      widget.player.stream.playing
          .listen((v) { if (mounted) setState(() => _playing = v); }),
      widget.player.stream.buffering
          .listen((v) { if (mounted) setState(() => _buffering = v); }),
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 进度条
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          ),
          child: Slider(
            value: ratio.clamp(0.0, 1.0),
            onChanged: (v) {
              final seek = Duration(
                milliseconds:
                    (v * _duration.inMilliseconds).round(),
              );
              widget.player.seek(seek);
              widget.onSeek();
            },
            activeColor: Colors.white,
            inactiveColor: Colors.white38,
          ),
        ),
        // 时间 + 播放按钮
        Row(
          children: [
            Text(
              '${DurationFormat.format(_position.inSeconds.toDouble())} / ${DurationFormat.format(_duration.inSeconds.toDouble())}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const Spacer(),
            if (_buffering)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else
              IconButton(
                icon: Icon(
                  _playing ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                ),
                onPressed: () {
                  _playing
                      ? widget.player.pause()
                      : widget.player.play();
                },
              ),
          ],
        ),
      ],
    );
  }
}
