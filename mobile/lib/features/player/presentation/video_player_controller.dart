// lib/features/player/presentation/video_player_controller.dart
// 视频播放控制器：封装 media_kit Player，提供操作队列和状态管理

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

// ──────────────────────────────────────────────
// 操作队列
// ──────────────────────────────────────────────

enum _OpType { play, pause, seek, setRate, other }

class _QueuedOp {
  const _QueuedOp(this.type, this.execute);
  final _OpType type;
  final Future<void> Function() execute;
}

// ──────────────────────────────────────────────
// 控制器
// ──────────────────────────────────────────────

class VideoPlayerController extends ChangeNotifier {
  VideoPlayerController() {
    _player = Player();
    _videoController = VideoController(_player);
  }

  late final Player _player;
  late final VideoController _videoController;
  final List<StreamSubscription> _subs = [];

  // ── 公开状态 ──

  VideoController get videoController => _videoController;

  bool _isReady = false;
  bool get isReady => _isReady;

  bool _isBuffering = false;
  Duration? _seekTarget;
  bool get isLoading => _processing || _seekTarget != null || _isBuffering;

  bool _hasError = false;
  bool get hasError => _hasError;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  bool _isFullscreen = false;
  bool get isFullscreen => _isFullscreen;

  Duration _position = Duration.zero;
  Duration get position => _seekTarget ?? _position;

  Duration _duration = Duration.zero;
  Duration get duration => _duration;

  // ── 操作队列 ──

  final _queue = <_QueuedOp>[];
  bool _processing = false;

  void _enqueue(_OpType type, Future<void> Function() task) {
    _optimizeQueue(type);
    _queue.add(_QueuedOp(type, task));
    if (_processing) return;
    _processQueue();
  }

  void _optimizeQueue(_OpType incoming) {
    if (_queue.isEmpty) return;

    switch (incoming) {
      case _OpType.play:
      case _OpType.pause:
        while (_queue.isNotEmpty &&
            (_queue.last.type == _OpType.play ||
                _queue.last.type == _OpType.pause)) {
          _queue.removeLast();
        }
        break;
      case _OpType.seek:
        while (_queue.isNotEmpty && _queue.last.type == _OpType.seek) {
          _queue.removeLast();
        }
        break;
      case _OpType.setRate:
        while (_queue.isNotEmpty && _queue.last.type == _OpType.setRate) {
          _queue.removeLast();
        }
        break;
      case _OpType.other:
        break;
    }
  }

  Future<void> _processQueue() async {
    _processing = true;
    notifyListeners();
    while (_queue.isNotEmpty) {
      final next = _queue.removeAt(0);
      try {
        await next.execute();
      } catch (e) {
        _queue.clear();
        _hasError = true;
        _errorMessage = e.toString();
        break;
      }
    }
    _processing = false;
    notifyListeners();
  }

  // ── 公开方法（入队列） ──

  /// 初始化：打开视频、seek 到保存位置、开始播放。
  /// 这是唯一的异步入队方法，因为 open 必须等待完成后才能 seek/play。
  void initialize(String url, {double? savedPositionSeconds}) {
    _enqueue(_OpType.other, () =>
      _initAsync(url, savedPositionSeconds: savedPositionSeconds),
    );
  }

  Future<void> _initAsync(String url,
      {double? savedPositionSeconds}) async {
    try {
      await _player.open(Media(url), play: false);

      // 等待获取实际时长（5s 超时）
      Duration? videoDuration;
      try {
        videoDuration = await _player.stream.duration
            .firstWhere((d) => d > Duration.zero)
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        // 超时，从头播放
      }

      // 有保存进度则 seek
      if (videoDuration != null &&
          savedPositionSeconds != null &&
          savedPositionSeconds > 0 &&
          videoDuration.inSeconds > 0 &&
          savedPositionSeconds / videoDuration.inSeconds < 0.9) {
        await _player.seek(Duration(seconds: savedPositionSeconds.round()));
      }

      await _player.play();

      // 设置 stream 监听
      _setupStreamListeners();

      _isReady = true;
      notifyListeners();
    } catch (e) {
      _hasError = true;
      _errorMessage = '视频加载失败：$e';
      notifyListeners();
    }
  }

  void play() {
    if (!_isReady) return;
    _enqueue(_OpType.play, () => _player.play());
  }

  void pause() {
    if (!_isReady) return;
    _enqueue(_OpType.pause, () => _player.pause());
  }

  void seek(Duration target) {
    if (!_isReady) return;
    _seekTarget = target;
    _enqueue(_OpType.seek, () => _player.seek(target));
    notifyListeners();
  }

  void setRate(double rate) {
    if (!_isReady) return;
    _enqueue(_OpType.setRate, () => _player.setRate(rate));
  }

  // ── 全屏（直接执行，不入队列） ──

  void enterFullscreen() {
    _isFullscreen = true;
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    notifyListeners();
  }

  void exitFullscreen() {
    _isFullscreen = false;
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    notifyListeners();
  }

  // ── Stream 监听 ──

  void _setupStreamListeners() {
    _subs.addAll([
      _player.stream.position.listen((v) {
        if (_seekTarget != null) {
          // seek 过程中：position 到达目标附近后清除 seekTarget，恢复正常同步
          final diff = (v - _seekTarget!).inMilliseconds.abs();
          if (diff < 500) {
            _seekTarget = null;
            _position = v;
            notifyListeners();
          }
          // 未到达目标，不更新 position
          return;
        }
        _position = v;
        notifyListeners();
      }),
      _player.stream.duration.listen((v) {
        _duration = v;
        notifyListeners();
      }),
      _player.stream.playing.listen((v) {
        _isPlaying = v;
        notifyListeners();
      }),
      _player.stream.buffering.listen((v) {
        _isBuffering = v;
        notifyListeners();
      }),
    ]);
  }

  // ── 生命周期 ──

  /// 获取当前 position（秒），用于退出时上报进度。
  double get positionSeconds => _player.state.position.inSeconds.toDouble();

  /// 获取当前 duration（秒）。
  double get durationSeconds => _player.state.duration.inSeconds.toDouble();

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    if (_isFullscreen) {
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }
}
