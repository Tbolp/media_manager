// lib/main.dart
// 应用入口

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'core/storage/prefs_storage.dart';
import 'features/auth/presentation/providers/auth_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 全局锁定竖屏（视频全屏时由 VideoPlayerController 临时切换）
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // media_kit 初始化（必须在任何 Player 实例创建前调用）
  MediaKit.ensureInitialized();

  // 提前获取 SharedPreferences 实例
  final prefs = await SharedPreferences.getInstance();

  final container = ProviderContainer(
    overrides: [
      prefsStorageProvider.overrideWithValue(PrefsStorageService(prefs)),
    ],
  );

  // 纯本地读取，有 token+用户信息就直接进首页
  await container.read(authNotifierProvider.notifier).restoreSession();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const App(),
    ),
  );
}
