// lib/features/auth/presentation/providers/auth_provider.dart
// 全局认证状态管理

import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/auth_repository.dart';
import '../../domain/user_model.dart';

part 'auth_provider.g.dart';

@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  AsyncValue<UserModel?> build() => const AsyncValue.data(null);

  Future<void> login(String username, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).login(username, password),
    );
  }

  Future<void> logout() async {
    try {
      await ref.read(authRepositoryProvider).logout();
    } catch (_) {
      // 登出失败也清除本地状态
      await ref.read(authRepositoryProvider).deleteToken();
    }
    state = const AsyncValue.data(null);
  }

  /// 启动时恢复会话（纯本地读取，不调接口）
  Future<void> restoreSession() async {
    final user = await ref.read(authRepositoryProvider).restoreSession();
    state = AsyncValue.data(user);
  }

  /// 由 AuthInterceptor 在 401 时调用
  void forceLogout(String errorCode) {
    state = const AsyncValue.data(null);
    _pendingErrorCode = errorCode;
  }

  String? _pendingErrorCode;

  /// 取出并清除待处理的错误码
  String? consumeErrorCode() {
    final code = _pendingErrorCode;
    _pendingErrorCode = null;
    return code;
  }

  bool get isLoggedIn => state.valueOrNull != null;
  UserModel? get user => state.valueOrNull;
}
