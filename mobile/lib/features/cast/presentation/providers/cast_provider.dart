// lib/features/cast/presentation/providers/cast_provider.dart
// 投屏状态管理

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/dlna_service.dart';

part 'cast_provider.g.dart';

// ──────────────────────────────────────────────
// DLNA 服务单例
// ──────────────────────────────────────────────

@Riverpod(keepAlive: true)
DlnaService dlnaService(DlnaServiceRef ref) {
  return DlnaService.instance;
}

// ──────────────────────────────────────────────
// 投屏状态 Notifier
// ──────────────────────────────────────────────

enum CastStatus {
  disconnected,
  connected,
  playing,
  paused,
  stopped,
  loading,
}

class CastState {
  final CastStatus status;
  final DlnaDevice? device;
  final String? videoTitle;
  final String? videoUrl;
  final DlnaPosition position;
  final int volume;

  const CastState({
    this.status = CastStatus.disconnected,
    this.device,
    this.videoTitle,
    this.videoUrl,
    this.position = const _DefaultPosition(),
    this.volume = 50,
  });

  bool get isConnected => status != CastStatus.disconnected;
  bool get isPlaying => status == CastStatus.playing;
  bool get isPaused => status == CastStatus.paused;
  bool get isCasting =>
      status == CastStatus.playing || status == CastStatus.paused;

  CastState copyWith({
    CastStatus? status,
    DlnaDevice? device,
    String? videoTitle,
    String? videoUrl,
    DlnaPosition? position,
    int? volume,
  }) {
    return CastState(
      status: status ?? this.status,
      device: device ?? this.device,
      videoTitle: videoTitle ?? this.videoTitle,
      videoUrl: videoUrl ?? this.videoUrl,
      position: position ?? this.position,
      volume: volume ?? this.volume,
    );
  }
}

// DlnaPosition 的默认值需要是 const
class _DefaultPosition implements DlnaPosition {
  const _DefaultPosition();

  @override
  String get trackDuration => '00:00:00';
  @override
  String get relTime => '00:00:00';
  @override
  String get trackUri => '';
  @override
  int get durationSeconds => 0;
  @override
  int get positionSeconds => 0;
  @override
  double get progress => 0;
}

@Riverpod(keepAlive: true)
class CastNotifier extends _$CastNotifier {
  late final DlnaService _dlna;
  StreamSubscription? _positionSub;
  StreamSubscription? _transportSub;

  @override
  CastState build() {
    _dlna = ref.read(dlnaServiceProvider);

    _positionSub = _dlna.positionStream.listen((pos) {
      state = state.copyWith(position: pos);
    });

    _transportSub = _dlna.transportStateStream.listen((transport) {
      switch (transport) {
        case DlnaTransportState.playing:
          state = state.copyWith(status: CastStatus.playing);
          break;
        case DlnaTransportState.paused:
          state = state.copyWith(status: CastStatus.paused);
          break;
        case DlnaTransportState.stopped:
          if (state.isConnected) {
            state = state.copyWith(status: CastStatus.stopped);
          }
          break;
        default:
          break;
      }
    });

    ref.onDispose(() {
      _positionSub?.cancel();
      _transportSub?.cancel();
    });

    return const CastState();
  }

  void connectDevice(DlnaDevice device) {
    _dlna.connect(device);
    state = state.copyWith(
      status: CastStatus.connected,
      device: device,
    );
  }

  void disconnect() {
    _dlna.stop().catchError((_) {});
    _dlna.disconnect();
    state = const CastState();
  }

  Future<void> castVideo({
    required String url,
    required String title,
    int startPositionSeconds = 0,
  }) async {
    if (!state.isConnected) return;

    state = state.copyWith(
      status: CastStatus.loading,
      videoTitle: title,
      videoUrl: url,
    );

    try {
      await _dlna.setUrl(url, title: title);
      await _dlna.play();
      _dlna.startPositionPolling();
      state = state.copyWith(status: CastStatus.playing);
      // 等设备进入 PLAYING 状态后再 seek，否则设备会忽略
      if (startPositionSeconds > 0) {
        try {
          await _waitForReady();
          await _dlna.seek(startPositionSeconds);
        } catch (e) {
          debugPrint('[Cast] seek to start position failed: $e');
        }
      }
    } catch (e) {
      debugPrint('[Cast] castVideo failed: $e');
      state = state.copyWith(status: CastStatus.connected);
    }
  }

  /// 轮询等待设备真正就绪（PLAYING 且 duration > 0），最多等 15 秒
  Future<bool> _waitForReady() async {
    for (var i = 0; i < 30; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      final transport = await _dlna.getTransportState();
      if (transport == DlnaTransportState.playing) {
        final pos = await _dlna.getPosition();
        if (pos.durationSeconds > 0) return true;
      }
    }
    return false;
  }

  Future<void> play() async {
    try {
      await _dlna.play();
      state = state.copyWith(status: CastStatus.playing);
    } catch (e) {
      debugPrint('[Cast] play failed: $e');
    }
  }

  Future<void> pause() async {
    try {
      await _dlna.pause();
      state = state.copyWith(status: CastStatus.paused);
    } catch (e) {
      debugPrint('[Cast] pause failed: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _dlna.stop();
      _dlna.stopPositionPolling();
      state = state.copyWith(status: CastStatus.stopped);
    } catch (e) {
      debugPrint('[Cast] stop failed: $e');
    }
  }

  Future<void> seekTo(int seconds) async {
    try {
      await _dlna.seek(seconds);
    } catch (e) {
      debugPrint('[Cast] seek failed: $e');
    }
  }

  Future<void> setVolume(int volume) async {
    try {
      await _dlna.setVolume(volume);
      state = state.copyWith(volume: volume);
    } catch (e) {
      debugPrint('[Cast] setVolume failed: $e');
    }
  }
}
