// lib/features/auth/presentation/login_page.dart
// 登录页

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/routes.dart';
import '../../settings/providers/settings_provider.dart';
import '../../auth/data/auth_repository.dart';
import 'providers/auth_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key, this.errorCode});

  final String? errorCode;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  static const _errorMessages = {
    'token_expired': '登录已过期，请重新登录',
    'user_disabled': '账号已被停用，请联系管理员',
    'user_deleted': '账号不存在，请联系管理员',
  };

  @override
  void initState() {
    super.initState();
    if (widget.errorCode != null) {
      _errorMessage = _errorMessages[widget.errorCode] ?? '登录已失效，请重新登录';
    }
    _checkSystemStatus();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkSystemStatus() async {
    try {
      final initialized =
          await ref.read(authRepositoryProvider).getSystemStatus();
      if (!initialized && mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text('系统未初始化'),
            content: const Text(
              '系统尚未完成初始化，请先在电脑端（Web）完成管理员账号创建。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('我知道了'),
              ),
            ],
          ),
        );
      }
    } catch (_) {
      // 忽略检查失败，不阻止登录
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authNotifierProvider.notifier).login(
            _usernameController.text.trim(),
            _passwordController.text,
          );

      final authState = ref.read(authNotifierProvider);
      if (authState.hasValue && authState.valueOrNull != null) {
        if (mounted) context.go(kRouteHome);
      } else if (authState.hasError) {
        final error = authState.error;
        setState(() {
          _errorMessage = _parseLoginError(error);
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _parseLoginError(Object? error) {
    if (error == null) return '登录失败，请稍后再试';
    final msg = error.toString();
    if (msg.contains('用户名或密码')) return '用户名或密码错误';
    if (msg.contains('user_disabled') || msg.contains('已被停用')) {
      return '账号已被停用，请联系管理员';
    }
    return '登录失败，请检查用户名和密码';
  }

  @override
  Widget build(BuildContext context) {
    final serverUrl = ref.watch(
      settingsNotifierProvider.select((s) => s.serverUrl),
    );

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.movie_outlined, size: 72, color: Colors.blue),
                const SizedBox(height: 16),
                Text(
                  '家庭影院',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 40),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(color: Colors.red.shade700),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          TextFormField(
                            controller: _usernameController,
                            keyboardType: TextInputType.text,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.username],
                            decoration: const InputDecoration(
                              labelText: '用户名',
                              prefixIcon: Icon(Icons.person_outline),
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? '请输入用户名' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            onFieldSubmitted: (_) => _login(),
                            decoration: InputDecoration(
                              labelText: '密码',
                              prefixIcon: const Icon(Icons.lock_outline),
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                            ),
                            validator: (v) =>
                                (v == null || v.isEmpty) ? '请输入密码' : null,
                          ),
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: _isLoading ? null : _login,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('登录'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      serverUrl.isEmpty ? '未配置服务器' : serverUrl,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                    const SizedBox(width: 4),
                    TextButton(
                      onPressed: () => context.go(kRouteServer),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(44, 44),
                      ),
                      child: const Text('修改'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
