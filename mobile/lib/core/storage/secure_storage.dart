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

  Future<String?> getToken() => _storage.read(key: AppConstants.keyAuthToken);

  Future<void> saveToken(String token) =>
      _storage.write(key: AppConstants.keyAuthToken, value: token);

  Future<void> deleteToken() =>
      _storage.delete(key: AppConstants.keyAuthToken);
}

@riverpod
SecureStorageService secureStorage(SecureStorageRef ref) {
  const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  return SecureStorageService(storage);
}
