// lib/features/settings/providers/settings_provider.dart
// 服务器地址管理

import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/storage/prefs_storage.dart';

part 'settings_provider.g.dart';

class SettingsState {
  const SettingsState({
    required this.serverUrl,
  });

  final String serverUrl;

  SettingsState copyWith({
    String? serverUrl,
  }) =>
      SettingsState(
        serverUrl: serverUrl ?? this.serverUrl,
      );
}

@riverpod
class SettingsNotifier extends _$SettingsNotifier {
  @override
  SettingsState build() => SettingsState(
        serverUrl: ref.read(prefsStorageProvider).getServerUrl() ?? '',
      );

  Future<void> saveServerUrl(String url) async {
    await ref.read(prefsStorageProvider).setServerUrl(url);
    state = state.copyWith(serverUrl: url);
  }
}
