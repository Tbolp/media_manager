// lib/main.dart
// 应用入口

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'core/storage/prefs_storage.dart';
import 'features/auth/presentation/providers/auth_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // media_kit 初始化（必须在任何 Player 实例创建前调用）
  MediaKit.ensureInitialized();

  // 提前获取 SharedPreferences 实例
  final prefs = await SharedPreferences.getInstance();

  // 在 runApp 之前完成 session 恢复，避免构建期间出现 provider 状态变更
  final container = ProviderContainer(
    overrides: [
      prefsStorageProvider.overrideWithValue(PrefsStorageService(prefs)),
    ],
  );
  await container.read(authNotifierProvider.notifier).restoreSession();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const App(),
    ),
  );
}
