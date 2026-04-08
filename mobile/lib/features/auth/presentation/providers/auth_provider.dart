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
    }
    state = const AsyncValue.data(null);
  }

  /// 启动时恢复会话
  Future<void> restoreSession() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).restoreSession(),
    );
  }

  /// 由 AuthInterceptor 在 401 时调用
  void forceLogout(String errorCode) {
    state = const AsyncValue.data(null);
    // 路由守卫会监听此状态并跳转到 /login
    // errorCode 通过路由参数传递
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
