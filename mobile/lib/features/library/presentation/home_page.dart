// lib/features/library/presentation/home_page.dart
// 首页（媒体库列表）

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/routes.dart';
import '../../../shared/utils/url_builder.dart';
import '../../../shared/widgets/skeleton_grid.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../cast/presentation/providers/cast_provider.dart';
import '../../cast/presentation/widgets/device_picker_sheet.dart';
import '../../settings/providers/settings_provider.dart';
import '../data/library_repository.dart';
import 'providers/library_provider.dart';
import 'widgets/library_card.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final librariesAsync = ref.watch(librariesProvider);
    final user = ref.watch(authNotifierProvider.select((s) => s.valueOrNull));
    final baseUrl =
        ref.watch(settingsNotifierProvider.select((s) => s.serverUrl));
    final token = ref.watch(
          authNotifierProvider.select((s) => s.valueOrNull?.token),
        ) ??
        '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('媒体库'),
        actions: [
          // 投屏按钮
          Builder(builder: (context) {
            final castState = ref.watch(castNotifierProvider);
            return IconButton(
              icon: Icon(
                castState.isConnected
                    ? Icons.cast_connected
                    : Icons.cast,
                color: castState.isConnected
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              onPressed: () {
                if (castState.isCasting) {
                  context.push(kRouteCastControl);
                } else {
                  showDevicePicker(context);
                }
              },
            );
          }),
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
        loading: () => const SkeletonGrid(),
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
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.85,
              ),
              itemCount: libraries.length,
              itemBuilder: (_, i) {
                final library = libraries[i];
                final coverUrl = library.coverFileId != null
                    ? UrlBuilder.thumbnailUrl(
                        baseUrl, library.coverFileId!, token)
                    : null;
                return LibraryCard(
                  library: library,
                  thumbnailUrl: coverUrl,
                  onTap: () => context.push('/library/${library.id}'),
                  onRefresh: () async {
                    final queued = await ref
                        .read(libraryRepositoryProvider)
                        .triggerRefresh(library.id);
                    if (!context.mounted) return;
                    if (!queued) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('刷新任务已在队列中，无需重复提交')),
                      );
                    }
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
