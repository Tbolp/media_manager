// lib/features/library/presentation/home_page.dart
// 首页（媒体库列表）

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/routes.dart';
import '../../../shared/widgets/skeleton_list.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import 'providers/library_provider.dart';
import 'widgets/library_card.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final librariesAsync = ref.watch(librariesProvider);
    final user = ref.watch(authNotifierProvider.select((s) => s.valueOrNull));

    return Scaffold(
      appBar: AppBar(
        title: const Text('媒体库'),
        actions: [
          PopupMenuButton<String>(
            icon: CircleAvatar(
              radius: 16,
              child: Text(
                user?.username.substring(0, 1).toUpperCase() ?? '?',
              ),
            ),
            onSelected: (value) async {
              if (value == 'logout') {
                await ref.read(authNotifierProvider.notifier).logout();
                if (context.mounted) context.go(kRouteLogin);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Text(
                  user?.username ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: const [
                    Icon(Icons.logout_outlined),
                    SizedBox(width: 12),
                    Text('退出登录'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: librariesAsync.when(
        loading: () => const SkeletonList(),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('加载失败：$err'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(librariesProvider),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
        data: (libraries) {
          if (libraries.isEmpty) {
            return EmptyState(
              icon: Icons.video_library_outlined,
              message: user?.isAdmin == true
                  ? '还没有媒体库，请在电脑端创建'
                  : '暂无可访问的媒体库，请联系管理员开通权限',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(librariesProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: libraries.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: LibraryCard(
                  library: libraries[i],
                  onTap: () => context.push('/library/${libraries[i].id}'),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
