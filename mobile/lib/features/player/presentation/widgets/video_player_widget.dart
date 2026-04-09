// lib/features/player/presentation/widgets/video_player_widget.dart
// 视频显示组件：显示视频画面、loading、错误状态

import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../video_player_controller.dart';

class VideoPlayerWidget extends StatelessWidget {
  const VideoPlayerWidget({super.key, required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        // 错误状态
        if (controller.hasError) {
          return Container(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      color: Colors.white70, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    controller.errorMessage,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return Container(
          color: Colors.black,
          child: Stack(
            children: [
              // 视频画面
              if (controller.isReady)
                Center(
                  child: Video(
                    controller: controller.videoController,
                    controls: NoVideoControls,
                    fit: BoxFit.contain,
                  ),
                ),

              // loading 指示器
              if (!controller.isReady || controller.isLoading)
                const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
            ],
          ),
        );
      },
    );
  }
}
