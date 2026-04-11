// lib/features/auth/presentation/server_page.dart
// 服务器地址配置页

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/routes.dart';
import '../../../core/storage/secure_storage.dart';
import '../../settings/providers/settings_provider.dart';

class ServerPage extends ConsumerStatefulWidget {
  const ServerPage({super.key});

  @override
  ConsumerState<ServerPage> createState() => _ServerPageState();
}

class _ServerPageState extends ConsumerState<ServerPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _urlController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final currentUrl = ref.read(settingsNotifierProvider).serverUrl;
    _urlController = TextEditingController(text: currentUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      // trim 末尾 /
      final url = _urlController.text.trim().replaceAll(RegExp(r'/+$'), '');
      await ref.read(settingsNotifierProvider.notifier).saveServerUrl(url);
      // 清除 Token（换服务器后原 Token 无效）
      await ref.read(secureStorageProvider).deleteToken();
      if (mounted) context.go(kRouteLogin);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('服务器配置')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                Icon(Icons.dns_outlined, size: 72, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 32),
                Text(
                  '请输入家庭影院服务器地址',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _urlController,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: '服务器地址',
                    hintText: 'http://192.168.1.100:8080',
                    prefixIcon: Icon(Icons.link),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '请输入服务器地址';
                    }
                    final trimmed =
                        value.trim().replaceAll(RegExp(r'/+$'), '');
                    if (!RegExp(r'^https?://.+[^/]$').hasMatch(trimmed)) {
                      return '请输入有效的服务器地址（以 http:// 或 https:// 开头）';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        )
                      : const Text('保存并继续'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
