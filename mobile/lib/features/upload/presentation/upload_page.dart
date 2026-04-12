// lib/features/upload/presentation/upload_page.dart
// 上传管理页面（正在上传 / 已完成 两个 Tab）

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../upload/domain/upload_task.dart';
import 'providers/upload_provider.dart';
import 'widgets/upload_task_tile.dart';

class UploadPage extends ConsumerWidget {
  const UploadPage({super.key, required this.libraryId});

  final String libraryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allTasks = ref.watch(uploadNotifierProvider);
    final libraryTasks =
        allTasks.where((t) => t.libraryId == libraryId).toList();

    final activeTasks = libraryTasks
        .where((t) =>
            t.status == UploadStatus.waiting ||
            t.status == UploadStatus.uploading ||
            t.status == UploadStatus.failed)
        .toList();
    final completedTasks = libraryTasks
        .where((t) => t.status == UploadStatus.completed)
        .toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('上传管理'),
          bottom: TabBar(
            tabs: [
              Tab(text: '进行中 (${activeTasks.length})'),
              Tab(text: '已完成 (${completedTasks.length})'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // 进行中 Tab
            activeTasks.isEmpty
                ? const _EmptyTab(
                    icon: Icons.cloud_upload_outlined,
                    message: '暂无上传任务',
                  )
                : ListView.separated(
                    itemCount: activeTasks.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final task = activeTasks[i];
                      return Dismissible(
                        key: ValueKey(task.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          color: Colors.red,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) {
                          ref
                              .read(uploadNotifierProvider.notifier)
                              .cancelTask(task.id);
                        },
                        child: UploadTaskTile(
                          task: task,
                          onCancel: () {
                            ref
                                .read(uploadNotifierProvider.notifier)
                                .cancelTask(task.id);
                          },
                          onRetry: () {
                            ref
                                .read(uploadNotifierProvider.notifier)
                                .retryTask(task.id);
                          },
                        ),
                      );
                    },
                  ),
            // 已完成 Tab
            completedTasks.isEmpty
                ? const _EmptyTab(
                    icon: Icons.cloud_done_outlined,
                    message: '暂无已完成任务',
                  )
                : ListView.separated(
                    itemCount: completedTasks.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final task = completedTasks[i];
                      return Dismissible(
                        key: ValueKey(task.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          color: Colors.red,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) {
                          ref
                              .read(uploadNotifierProvider.notifier)
                              .removeTask(task.id);
                        },
                        child: UploadTaskTile(task: task),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTab extends StatelessWidget {
  const _EmptyTab({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }
}
