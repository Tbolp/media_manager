// lib/features/auth/data/auth_repository.dart
// 认证仓库：协调 API 与本地存储

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../domain/user_model.dart';
import 'auth_api.dart';

part 'auth_repository.g.dart';

class AuthRepository {
  AuthRepository(this._api, this._secureStorage);

  final AuthApi _api;
  final SecureStorageService _secureStorage;

  Future<UserModel> login(String username, String password) async {
    final data = await _api.login(username, password);
    final token = data['token'] as String;
    await _secureStorage.saveToken(token);
    // 直接从 JWT token 解析用户信息
    final user = UserModel.fromToken(token);
    if (user == null) {
      throw Exception('JWT token 解析失败');
    }
    return user;
  }

  Future<void> logout() async {
    await _api.logout();
    await _secureStorage.deleteToken();
  }

  Future<bool> getSystemStatus() => _api.getSystemStatus();

  Future<String?> getSavedToken() => _secureStorage.getToken();

  Future<void> deleteToken() => _secureStorage.deleteToken();

  /// 恢复会话：只读本地存储的 token，从 JWT 解析用户信息。
  /// token 有效 → 返回 UserModel（进首页）
  /// token 缺失或过期 → 返回 null（进登录页）
  Future<UserModel?> restoreSession() async {
    final token = await _secureStorage.getToken();
    debugPrint(
        '[AuthRepo] restoreSession: token=${token == null ? "null" : "len=${token.length}"}');
    if (token == null || token.isEmpty) {
      debugPrint('[AuthRepo] restoreSession: no token, return null');
      return null;
    }

    final user = UserModel.fromToken(token);
    debugPrint(
        '[AuthRepo] restoreSession: fromToken result=${user == null ? "null" : "id=${user.id}, name=${user.username}, role=${user.role}"}');
    if (user == null) {
      // token 无效，清理
      debugPrint('[AuthRepo] restoreSession: token invalid, deleting');
      await _secureStorage.deleteToken();
      return null;
    }

    return user;
  }
}

@riverpod
AuthRepository authRepository(AuthRepositoryRef ref) => AuthRepository(
      AuthApi(ref.watch(dioClientProvider)),
      ref.watch(secureStorageProvider),
    );
