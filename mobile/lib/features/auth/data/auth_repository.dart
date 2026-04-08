// lib/features/auth/data/auth_repository.dart
// 认证仓库：协调 API 与本地存储

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
    final userJson = data['user'] as Map<String, dynamic>;
    await _secureStorage.saveToken(token);
    await _secureStorage.saveUser(
      userJson['id'] as String,
      userJson['username'] as String,
      userJson['role'] as String,
    );
    return UserModel.fromJson(userJson, token);
  }

  Future<void> logout() async {
    await _api.logout();
    await _secureStorage.deleteToken();
    await _secureStorage.deleteUser();
  }

  Future<bool> getSystemStatus() => _api.getSystemStatus();

  Future<String?> getSavedToken() => _secureStorage.getToken();

  Future<void> deleteToken() async {
    await _secureStorage.deleteToken();
    await _secureStorage.deleteUser();
  }

  /// 恢复会话：只读本地存储，不调接口。
  /// 有 token + 用户信息 → 直接返回 UserModel（进首页）
  /// 缺失 → 返回 null（进登录页）
  /// 首页请求接口时如果 token 失效，AuthInterceptor 会触发 forceLogout。
  Future<UserModel?> restoreSession() async {
    final token = await _secureStorage.getToken();
    if (token == null || token.isEmpty) return null;

    final userMap = await _secureStorage.getUser();
    if (userMap == null) {
      // 有 token 但没用户信息（异常状态），清理掉
      await _secureStorage.deleteToken();
      return null;
    }

    return UserModel(
      id: userMap['id']!,
      username: userMap['username']!,
      role: userMap['role']!,
      token: token,
    );
  }
}

@riverpod
AuthRepository authRepository(AuthRepositoryRef ref) => AuthRepository(
      AuthApi(ref.watch(dioClientProvider)),
      ref.watch(secureStorageProvider),
    );
