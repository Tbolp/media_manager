// lib/core/utils/platform_utils.dart
// 平台检测工具（TV / 手机）

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'platform_utils.g.dart';

/// 检测当前设备是否是 Android TV
Future<bool> _detectIsTV() async {
  if (!Platform.isAndroid) return false;

  try {
    // UI_MODE_TYPE_TELEVISION = 4
    const channel = MethodChannel('media_manager/platform');
    final result = await channel.invokeMethod<bool>('isTV');
    return result ?? false;
  } catch (e) {
    debugPrint('[PlatformUtils] TV 检测失败: $e');
    return false;
  }
}

@Riverpod(keepAlive: true)
Future<bool> isTV(IsTVRef ref) async {
  return _detectIsTV();
}
