// lib/core/storage/secure_storage.dart
// flutter_secure_storage 封装（JWT Token）

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../constants.dart';

part 'secure_storage.g.dart';

class SecureStorageService {
  SecureStorageService(this._storage);

  final FlutterSecureStorage _storage;

  // Token
  Future<String?> getToken() => _storage.read(key: AppConstants.keyAuthToken);

  Future<void> saveToken(String token) =>
      _storage.write(key: AppConstants.keyAuthToken, value: token);

  Future<void> deleteToken() =>
      _storage.delete(key: AppConstants.keyAuthToken);

  // 用户信息（登录时保存，恢复会话时读取）
  Future<void> saveUser(String id, String username, String role) async {
    await _storage.write(key: '${AppConstants.keyAuthToken}_user_id', value: id);
    await _storage.write(key: '${AppConstants.keyAuthToken}_username', value: username);
    await _storage.write(key: '${AppConstants.keyAuthToken}_role', value: role);
  }

  Future<Map<String, String>?> getUser() async {
    final id = await _storage.read(key: '${AppConstants.keyAuthToken}_user_id');
    final username = await _storage.read(key: '${AppConstants.keyAuthToken}_username');
    final role = await _storage.read(key: '${AppConstants.keyAuthToken}_role');
    if (id == null || username == null || role == null) return null;
    return {'id': id, 'username': username, 'role': role};
  }

  Future<void> deleteUser() async {
    await _storage.delete(key: '${AppConstants.keyAuthToken}_user_id');
    await _storage.delete(key: '${AppConstants.keyAuthToken}_username');
    await _storage.delete(key: '${AppConstants.keyAuthToken}_role');
  }
}

@riverpod
SecureStorageService secureStorage(SecureStorageRef ref) {
  const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  return SecureStorageService(storage);
}
