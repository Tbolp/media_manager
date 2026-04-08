// lib/features/auth/data/auth_api.dart
// 认证相关 API 调用

import 'package:dio/dio.dart';

class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> login(
      String username, String password) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      '/api/login',
      data: {'username': username, 'password': password},
    );
    return resp.data!;
  }

  Future<void> logout() async {
    await _dio.post<void>('/api/logout');
  }

  Future<bool> getSystemStatus() async {
    final resp = await _dio.get<Map<String, dynamic>>('/api/system/status');
    return resp.data!['initialized'] as bool;
  }

  Future<Map<String, dynamic>> getMe() async {
    final resp = await _dio.get<Map<String, dynamic>>('/api/me');
    return resp.data!;
  }
}
