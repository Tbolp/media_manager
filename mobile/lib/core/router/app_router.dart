// lib/core/router/app_router.dart
// go_router 路由定义（带认证守卫）

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/server_page.dart';
import '../../features/library/presentation/home_page.dart';
import '../../features/library/presentation/library_detail_page.dart';
import '../../features/player/presentation/video_player_page.dart';
import '../../features/settings/providers/settings_provider.dart';
import 'routes.dart';

part 'app_router.g.dart';

@riverpod
GoRouter appRouter(AppRouterRef ref) {
  final authNotifier = ref.watch(authNotifierProvider.notifier);

  // 监听 auth 状态变化以触发路由刷新
  final authState = ref.watch(authNotifierProvider);
  final serverUrl = ref.watch(
    settingsNotifierProvider.select((s) => s.serverUrl),
  );

  return GoRouter(
    initialLocation: kRouteHome,
    redirect: (context, state) {
      final hasServer = serverUrl.isNotEmpty;
      final isLoggedIn = authState.valueOrNull != null;
      final location = state.uri.path;

      // 未配置服务器 → /server（除非已在 /server）
      if (!hasServer && location != kRouteServer) {
        return kRouteServer;
      }

      // 已配置服务器但未登录 → /login
      if (hasServer && !isLoggedIn) {
        if (location == kRouteServer || location == kRouteLogin) {
          return null; // 允许停留
        }
        // 传递 errorCode（如果有）
        final errorCode = authNotifier.consumeErrorCode();
        if (errorCode != null) {
          return '$kRouteLogin?errorCode=$errorCode';
        }
        return kRouteLogin;
      }

      // 已登录时访问 /login 或 /server → 跳到首页
      if (isLoggedIn &&
          (location == kRouteLogin || location == kRouteServer)) {
        return kRouteHome;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: kRouteServer,
        builder: (_, __) => const ServerPage(),
      ),
      GoRoute(
        path: kRouteLogin,
        builder: (_, state) => LoginPage(
          errorCode: state.uri.queryParameters['errorCode'],
        ),
      ),
      GoRoute(
        path: kRouteHome,
        builder: (_, __) => const HomePage(),
      ),
      GoRoute(
        path: kRouteLibrary,
        builder: (_, state) => LibraryDetailPage(
          libraryId: state.pathParameters['libraryId']!,
        ),
      ),
      GoRoute(
        path: kRoutePlayer,
        builder: (_, state) => VideoPlayerPage(
          libraryId: state.pathParameters['libraryId']!,
          fileId: state.pathParameters['fileId']!,
        ),
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(
        child: Text('页面未找到：${state.error}'),
      ),
    ),
  );
}
