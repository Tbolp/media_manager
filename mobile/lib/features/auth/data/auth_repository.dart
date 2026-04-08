// lib/features/auth/data/auth_repository.dart
// 认证仓库：协调 API 与本地存储

import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    return UserModel.fromJson(data['user'] as Map<String, dynamic>, token);
  }

  Future<void> logout() async {
    await _api.logout();
    await _secureStorage.deleteToken();
  }

  Future<bool> getSystemStatus() => _api.getSystemStatus();

  Future<String?> getSavedToken() => _secureStorage.getToken();

  Future<void> deleteToken() => _secureStorage.deleteToken();

  /// 用保存的 token 恢复会话（启动时调用）
  Future<UserModel?> restoreSession() async {
    final token = await _secureStorage.getToken();
    if (token == null || token.isEmpty) return null;
    try {
      final data = await _api.getMe();
      return UserModel.fromJson(data, token);
    } catch (_) {
      await _secureStorage.deleteToken();
      return null;
    }
  }
}

@riverpod
AuthRepository authRepository(AuthRepositoryRef ref) => AuthRepository(
      AuthApi(ref.watch(dioClientProvider)),
      ref.watch(secureStorageProvider),
    );
