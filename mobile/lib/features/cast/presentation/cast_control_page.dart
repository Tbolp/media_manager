// lib/features/cast/presentation/cast_control_page.dart
// 投屏控制页面：遥控器式界面，控制投屏播放

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/utils/duration_format.dart';
import 'providers/cast_provider.dart';
import 'widgets/device_picker_sheet.dart';

class CastControlPage extends ConsumerStatefulWidget {
  const CastControlPage({super.key});

  @override
  ConsumerState<CastControlPage> createState() => _CastControlPageState();
}

class _CastControlPageState extends ConsumerState<CastControlPage> {
  bool _dragging = false;
  double _dragValue = 0;
  bool _popping = false;

  void _disconnectAndPop() {
    if (_popping) return;
    _popping = true;
    ref.read(castNotifierProvider.notifier).disconnect();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final castState = ref.watch(castNotifierProvider);
    final notifier = ref.read(castNotifierProvider.notifier);

    if (!castState.isConnected) {
      // 已断开，自动返回
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_popping) {
          _popping = true;
          Navigator.of(context).pop();
        }
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final pos = castState.position;
    final ratio = pos.durationSeconds > 0
        ? pos.positionSeconds / pos.durationSeconds
        : 0.0;
    final displayRatio = _dragging ? _dragValue : ratio;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          _disconnectAndPop();
        }
      },
      child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _disconnectAndPop,
        ),
        title: const Text('投屏控制'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cast_connected),
            onPressed: () => showDevicePicker(context),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 设备名称
                  Column(
                    children: [
                      Icon(
                        Icons.tv,
                        size: 64,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        castState.device?.friendlyName ?? '',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      // 视频标题
                      Text(
                        castState.videoTitle ?? '',
                        style: Theme.of(context).textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 进度条
                  Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          thumbShape:
                              const RoundSliderThumbShape(enabledThumbRadius: 6),
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
                            final target = (v * pos.durationSeconds).round();
                            notifier.seekTo(target);
                            setState(() => _dragging = false);
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DurationFormat.format(
                                _dragging
                                    ? _dragValue * pos.durationSeconds
                                    : pos.positionSeconds.toDouble(),
                              ),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              DurationFormat.format(pos.durationSeconds.toDouble()),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 播放控制按钮
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 后退 15 秒
                      IconButton(
                        iconSize: 36,
                        onPressed: () {
                          final target = (pos.positionSeconds - 15).clamp(0, pos.durationSeconds);
                          notifier.seekTo(target);
                        },
                        icon: const Icon(Icons.replay_10),
                      ),
                      const SizedBox(width: 24),
                      // 播放/暂停
                      IconButton(
                        iconSize: 56,
                        style: IconButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                        ),
                        onPressed: castState.status == CastStatus.loading
                            ? null
                            : () {
                                castState.isPlaying
                                    ? notifier.pause()
                                    : notifier.play();
                              },
                        icon: castState.status == CastStatus.loading
                            ? const SizedBox(
                                width: 32,
                                height: 32,
                                child: CircularProgressIndicator(strokeWidth: 3),
                              )
                            : Icon(
                                castState.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                              ),
                      ),
                      const SizedBox(width: 24),
                      // 前进 15 秒
                      IconButton(
                        iconSize: 36,
                        onPressed: () {
                          final target = (pos.positionSeconds + 15)
                              .clamp(0, pos.durationSeconds);
                          notifier.seekTo(target);
                        },
                        icon: const Icon(Icons.forward_10),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // 音量控制
                  Row(
                    children: [
                      const Icon(Icons.volume_down, size: 20),
                      Expanded(
                        child: Slider(
                          value: castState.volume.toDouble(),
                          min: 0,
                          max: 100,
                          onChanged: (v) {
                            notifier.setVolume(v.round());
                          },
                        ),
                      ),
                      const Icon(Icons.volume_up, size: 20),
                    ],
                  ),
                  const SizedBox(height: 16),

                ],
              ),
            ),
          );
        },
      ),
    ),
    );
  }
}
