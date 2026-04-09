// lib/core/storage/prefs_storage.dart
// SharedPreferences 封装（服务器地址）

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';

part 'prefs_storage.g.dart';

class PrefsStorageService {
  PrefsStorageService(this._prefs);

  final SharedPreferences _prefs;

  String? getServerUrl() => _prefs.getString(AppConstants.keyServerUrl);

  Future<void> setServerUrl(String url) =>
      _prefs.setString(AppConstants.keyServerUrl, url);
}

@riverpod
PrefsStorageService prefsStorage(PrefsStorageRef ref) {
  throw UnimplementedError('Must be overridden in ProviderScope overrides');
}
