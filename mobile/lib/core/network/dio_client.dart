// lib/core/network/dio_client.dart
// Dio 单例 + 拦截器组装

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'auth_interceptor.dart';
import 'error_interceptor.dart';
import '../../features/settings/providers/settings_provider.dart';

part 'dio_client.g.dart';

Dio createDio(String baseUrl, Ref ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
  dio.interceptors.addAll([
    AuthInterceptor(ref),
    ErrorInterceptor(),
    // LogInterceptor(requestBody: false, responseBody: false), // debug only
  ]);
  return dio;
}

@riverpod
Dio dioClient(DioClientRef ref) {
  final baseUrl = ref.watch(
    settingsNotifierProvider.select((s) => s.serverUrl),
  );
  return createDio(baseUrl, ref);
}
