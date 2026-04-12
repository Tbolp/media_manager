// lib/features/upload/presentation/widgets/upload_task_tile.dart
// 单个上传任务列表项

import 'package:flutter/material.dart';
import '../../domain/upload_task.dart';

class UploadTaskTile extends StatelessWidget {
  const UploadTaskTile({
    super.key,
    required this.task,
    this.onCancel,
    this.onRetry,
  });

  final UploadTask task;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: _buildLeadingIcon(theme),
      title: Text(
        task.filename,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: _buildSubtitle(theme),
      trailing: _buildTrailing(),
    );
  }

  Widget _buildLeadingIcon(ThemeData theme) {
    switch (task.status) {
      case UploadStatus.waiting:
        return Icon(Icons.hourglass_empty, color: theme.colorScheme.outline);
      case UploadStatus.uploading:
        return SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            value: task.progress > 0 ? task.progress : null,
            strokeWidth: 2.5,
          ),
        );
      case UploadStatus.completed:
        return Icon(Icons.check_circle, color: theme.colorScheme.primary);
      case UploadStatus.failed:
        return Icon(Icons.error, color: theme.colorScheme.error);
    }
  }

  Widget _buildSubtitle(ThemeData theme) {
    final sizeText = _formatFileSize(task.fileSize);

    switch (task.status) {
      case UploadStatus.waiting:
        return Text('$sizeText - 等待中');
      case UploadStatus.uploading:
        final percent = (task.progress * 100).toStringAsFixed(0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            LinearProgressIndicator(value: task.progress),
            const SizedBox(height: 2),
            Text('$sizeText - $percent%'),
          ],
        );
      case UploadStatus.completed:
        final time = task.completedAt;
        final timeStr = time != null
            ? '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}'
            : '';
        return Text('$sizeText - 上传完成${timeStr.isNotEmpty ? ' · $timeStr' : ''}');
      case UploadStatus.failed:
        return Text(
          task.error ?? '上传失败',
          style: TextStyle(color: theme.colorScheme.error),
        );
    }
  }

  Widget? _buildTrailing() {
    switch (task.status) {
      case UploadStatus.waiting:
      case UploadStatus.uploading:
        return IconButton(
          icon: const Icon(Icons.close),
          tooltip: '取消',
          onPressed: onCancel,
        );
      case UploadStatus.failed:
        return IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: '重试',
          onPressed: onRetry,
        );
      case UploadStatus.completed:
        return null;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
