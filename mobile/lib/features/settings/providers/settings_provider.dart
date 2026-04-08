// lib/features/settings/providers/settings_provider.dart
// 服务器地址与视图偏好管理

import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/storage/prefs_storage.dart';

part 'settings_provider.g.dart';

class SettingsState {
  const SettingsState({
    required this.serverUrl,
    required this.libraryViewMode,
  });

  final String serverUrl;
  final ViewMode libraryViewMode;

  SettingsState copyWith({
    String? serverUrl,
    ViewMode? libraryViewMode,
  }) =>
      SettingsState(
        serverUrl: serverUrl ?? this.serverUrl,
        libraryViewMode: libraryViewMode ?? this.libraryViewMode,
      );
}

@riverpod
class SettingsNotifier extends _$SettingsNotifier {
  @override
  SettingsState build() => SettingsState(
        serverUrl: ref.read(prefsStorageProvider).getServerUrl() ?? '',
        libraryViewMode:
            ref.read(prefsStorageProvider).getViewMode(),
      );

  Future<void> saveServerUrl(String url) async {
    await ref.read(prefsStorageProvider).setServerUrl(url);
    state = state.copyWith(serverUrl: url);
  }

  Future<void> saveViewMode(ViewMode mode) async {
    await ref.read(prefsStorageProvider).setViewMode(mode);
    state = state.copyWith(libraryViewMode: mode);
  }
}
