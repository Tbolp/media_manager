// lib/features/player/presentation/widgets/video_control_bar.dart
// 视频控制栏：播放暂停、进度条、时间、全屏

import 'package:flutter/material.dart';
import '../../../../shared/utils/duration_format.dart';
import '../video_player_controller.dart';

class VideoControlBar extends StatefulWidget {
  const VideoControlBar({
    super.key,
    required this.controller,
    required this.onSeek,
  });

  final VideoPlayerController controller;
  final VoidCallback onSeek; // seek 后重置控制栏隐藏计时

  @override
  State<VideoControlBar> createState() => _VideoControlBarState();
}

class _VideoControlBarState extends State<VideoControlBar> {
  bool _dragging = false;
  double _dragValue = 0.0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final c = widget.controller;
        final ratio = c.duration.inMilliseconds > 0
            ? c.position.inMilliseconds / c.duration.inMilliseconds
            : 0.0;

        // 显示的进度：拖动中用拖动值，否则用实际位置
        final displayRatio = _dragging ? _dragValue : ratio;
        final displaySeconds = displayRatio * c.duration.inSeconds;
        final loading = c.isLoading;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 播放/暂停
            GestureDetector(
              onTap: loading
                  ? null
                  : () {
                      c.isPlaying ? c.pause() : c.play();
                    },
              child: Icon(
                c.isPlaying ? Icons.pause : Icons.play_arrow,
                color: loading ? Colors.white38 : Colors.white,
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
                  value: displayRatio.clamp(0.0, 1.0),
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
                    final target = Duration(
                      milliseconds:
                          (v * c.duration.inMilliseconds).round(),
                    );
                    c.seek(target);
                    setState(() => _dragging = false);
                    widget.onSeek();
                  },
                  activeColor: Colors.white,
                  inactiveColor: Colors.white38,
                ),
              ),
            ),
            // 播放时间/总时间
            Text(
              '${DurationFormat.format(displaySeconds)} / ${DurationFormat.format(c.duration.inSeconds.toDouble())}',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
            const SizedBox(width: 4),
            // 全屏
            GestureDetector(
              onTap: () {
                c.isFullscreen ? c.exitFullscreen() : c.enterFullscreen();
              },
              child: Icon(
                c.isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                color: Colors.white,
                size: 26,
              ),
            ),
          ],
        );
      },
    );
  }
}
