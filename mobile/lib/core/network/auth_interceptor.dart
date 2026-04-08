// lib/core/network/auth_interceptor.dart
// 自动注入 Token；处理 401

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/secure_storage.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._ref);

  final Ref _ref;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token =
        await _ref.read(secureStorageProvider).getToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      // 清除本地 Token
      await _ref.read(secureStorageProvider).deleteToken();

      // 通知 authNotifier 强制登出（延迟调用避免循环依赖）
      final errorCode =
          err.response?.data?['error_code'] as String? ?? 'token_expired';
      // 通过异步回调通知，避免直接依赖 authNotifierProvider（循环依赖）
      _ref.read(_authCallbackProvider)?.call(errorCode);
    }
    handler.next(err);
  }
}

// 用于注册 forceLogout 回调（由 auth_provider 注册）
final _authCallbackProvider =
    StateProvider<void Function(String errorCode)?>((_) => null);

/// 注册 401 处理回调（在 AuthNotifier 中调用）
void registerAuthCallback(
  WidgetRef ref,
  void Function(String errorCode) callback,
) {
  ref.read(_authCallbackProvider.notifier).state = callback;
}
