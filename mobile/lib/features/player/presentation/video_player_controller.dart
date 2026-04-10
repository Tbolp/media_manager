// lib/features/player/presentation/video_player_controller.dart
// 视频播放控制器：async/await 简化版

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

// ──────────────────────────────────────────────
// 状态
// ──────────────────────────────────────────────

enum PlayerState {
  initializing, // 初始化中（打开视频、拉取进度）
  buffering, // 缓冲中（seek 等待完成）
  playing, // 播放中
  paused, // 暂停中
  error, // 错误
}

// ──────────────────────────────────────────────
// 控制器
// ──────────────────────────────────────────────

class VideoPlayerController extends ChangeNotifier {
  static const _tag = '[VideoPlayerCtrl]';

  VideoPlayerController() {
    debugPrint('$_tag 创建控制器');
    _player = Player();
    _videoController = VideoController(_player);
  }

  late final Player _player;
  late final VideoController _videoController;
  final List<StreamSubscription> _subs = [];

  // ── 状态 ──

  VideoController get videoController => _videoController;

  PlayerState _state = PlayerState.initializing;
  PlayerState get state => _state;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  bool _isFullscreen = false;
  bool get isFullscreen => _isFullscreen;

  Duration _position = Duration.zero;
  Duration get position => _position;

  Duration _duration = Duration.zero;
  Duration get duration => _duration;

  // 连续 seek：只记录最新目标，等当前 seek 完成后再执行
  Duration? _pendingSeekTarget;
  bool _isSeeking = false;
  // seek 前的播放状态，整个 seek 链中只记录第一次
  PlayerState? _stateBeforeSeek;

  // ── 派生状态（供 UI 使用） ──

  bool get isLoading =>
      _state == PlayerState.initializing || _state == PlayerState.buffering;
  bool get isPlaying => _state == PlayerState.playing;
  bool get isPaused => _state == PlayerState.paused;
  bool get hasError => _state == PlayerState.error;
  bool get isReady =>
      _state != PlayerState.initializing && _state != PlayerState.error;

  // ── 公开方法 ──

  /// 初始化：打开视频 & 获取进度并行执行，恢复进度后自动播放
  void initialize(String url, {Future<double?>? progressFuture}) {
    debugPrint(
        '$_tag initialize() url=${url.length > 80 ? '${url.substring(0, 80)}...' : url}');
    _initAsync(url, progressFuture: progressFuture);
  }

  void play() {
    if (_state == PlayerState.error || _state == PlayerState.initializing) {
      debugPrint('$_tag play() 忽略 (当前状态: $_state)');
      return;
    }
    debugPrint('$_tag play()');
    _player.play();
    _state = PlayerState.playing;
    notifyListeners();
  }

  void pause() {
    if (_state == PlayerState.error || _state == PlayerState.initializing) {
      debugPrint('$_tag pause() 忽略 (当前状态: $_state)');
      return;
    }
    debugPrint('$_tag pause()');
    _player.pause();
    _state = PlayerState.paused;
    notifyListeners();
  }

  void seek(Duration target) {
    if (_state == PlayerState.error || _state == PlayerState.initializing) {
      debugPrint('$_tag seek() 忽略 (当前状态: $_state)');
      return;
    }
    debugPrint('$_tag seek() target=${target.inSeconds}s');
    // 立即更新 position，UI 即时响应
    _position = target;
    _seekAsync(target);
  }

  void setRate(double rate) {
    if (_state == PlayerState.error || _state == PlayerState.initializing) {
      return;
    }
    debugPrint('$_tag setRate($rate)');
    _player.setRate(rate);
  }

  // ── 全屏 ──

  void enterFullscreen() {
    debugPrint('$_tag enterFullscreen()');
    _isFullscreen = true;
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    notifyListeners();
  }

  void exitFullscreen() {
    debugPrint('$_tag exitFullscreen()');
    _isFullscreen = false;
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    notifyListeners();
  }

  // ── 内部：异步初始化 ──

  Future<void> _initAsync(String url,
      {Future<double?>? progressFuture}) async {
    try {
      // 打开视频 & 获取进度并行执行
      debugPrint('$_tag _initAsync 开始打开视频 & 获取进度（并行）...');
      final results = await Future.wait([
        _player.open(Media(url), play: false),
        if (progressFuture != null) progressFuture,
      ]);

      final savedPositionSeconds =
          progressFuture != null ? results.last as double? : null;
      debugPrint('$_tag _initAsync 视频已打开, savedPos=$savedPositionSeconds');

      // 先注册 stream 监听，确保后续 duration/position 事件不会丢失
      _setupStreamListeners();

      // 有保存进度则 seek 后播放
      if (savedPositionSeconds != null && savedPositionSeconds > 0) {
        debugPrint('$_tag _initAsync 恢复进度: ${savedPositionSeconds}s');
        _state = PlayerState.buffering;
        notifyListeners();

        await _player.seek(Duration(seconds: savedPositionSeconds.round()));
        debugPrint('$_tag _initAsync seek 完成，开始播放');

        await _player.play();
        _state = PlayerState.playing;
        notifyListeners();
      } else {
        // 无进度，直接播放
        debugPrint('$_tag _initAsync 无保存进度，直接播放');
        await _player.play();
        _state = PlayerState.playing;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('$_tag _initAsync 错误: $e');
      _state = PlayerState.error;
      _errorMessage = '视频加载失败：$e';
      notifyListeners();
    }
  }

  // ── 内部：异步 seek ──

  Future<void> _seekAsync(Duration target) async {
    // 如果正在 seek，只更新目标，不重复发起
    if (_isSeeking) {
      debugPrint('$_tag seek 排队 target=${target.inSeconds}s (替换上一个 pending)');
      _pendingSeekTarget = target;
      return;
    }

    // 记录 seek 前的播放状态（整个 seek 链只记一次）
    _stateBeforeSeek = _state;
    _isSeeking = true;
    _state = PlayerState.buffering;
    notifyListeners();

    var current = target;
    try {
      while (true) {
        _pendingSeekTarget = null;
        debugPrint('$_tag seek 执行 target=${current.inSeconds}s');
        await _player.seek(current);

        // 检查是否有更新的 seek 目标
        if (_pendingSeekTarget != null) {
          debugPrint('$_tag seek 有新目标 ${_pendingSeekTarget!.inSeconds}s，继续');
          current = _pendingSeekTarget!;
          continue;
        }
        break;
      }

      // 恢复 seek 前的状态
      final restoreTo = _stateBeforeSeek ?? PlayerState.playing;
      debugPrint('$_tag seek 完成 pos=${current.inSeconds}s, 恢复=${restoreTo == PlayerState.playing ? "playing" : "paused"}');

      if (restoreTo == PlayerState.playing) {
        _player.play();
        _state = PlayerState.playing;
      } else {
        _state = PlayerState.paused;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('$_tag seek 错误: $e');
      // 只有没有新 seek 排队时才报错
      if (_pendingSeekTarget == null) {
        _state = PlayerState.error;
        _errorMessage = 'Seek 失败：$e';
        notifyListeners();
      }
    } finally {
      _isSeeking = false;
      _stateBeforeSeek = null;
    }
  }

  // ── 内部：stream 监听 ──

  void _setupStreamListeners() {
    _subs.addAll([
      _player.stream.position.listen((v) {
        if (_state != PlayerState.buffering) {
          _position = v;
          notifyListeners();
        }
      }),
      _player.stream.duration.listen((v) {
        _duration = v;
        notifyListeners();
      }),
    ]);
  }

  // ── 生命周期 ──

  /// 当前 position（秒），用于退出时上报进度
  double get positionSeconds => _player.state.position.inSeconds.toDouble();

  /// 当前 duration（秒）
  double get durationSeconds => _player.state.duration.inSeconds.toDouble();

  @override
  void dispose() {
    debugPrint(
        '$_tag dispose() pos=${_player.state.position.inSeconds}s, dur=${_player.state.duration.inSeconds}s, fullscreen=$_isFullscreen');
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    if (_isFullscreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }
}
