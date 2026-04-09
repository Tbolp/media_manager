// lib/core/constants.dart
// 全局常量

class AppConstants {
  AppConstants._();

  static const String appName = '家庭影院';

  // SharedPreferences Keys
  static const String keyServerUrl = 'server_url';
  static const String keyLibraryViewMode = 'library_view_mode';

  // SecureStorage Keys
  static const String keyAuthToken = 'auth_token';

  // 刷新轮询间隔
  static const Duration refreshPollInterval = Duration(seconds: 5);

  // 搜索防抖时间
  static const Duration searchDebounce = Duration(milliseconds: 300);

  // 快进/快退秒数
  static const int seekSeconds = 15;

  // 长按倍速
  static const double longPressRate = 2.0;
}
