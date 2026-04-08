// lib/features/library/presentation/widgets/file_list_tile.dart
// 列表模式文件条目

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../shared/utils/duration_format.dart';
import '../../domain/file_model.dart';

class FileListTile extends StatelessWidget {
  const FileListTile({
    super.key,
    required this.file,
    required this.thumbnailUrl,
    required this.onTap,
  });

  final FileModel file;
  final String thumbnailUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          width: 80,
          height: 52,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: thumbnailUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    Container(color: Colors.grey.shade300),
                errorWidget: (_, __, ___) => Container(
                  color: Colors.grey.shade300,
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
              if (file.isVideo)
                const Center(
                  child: Icon(
                    Icons.play_circle_outline,
                    color: Colors.white70,
                    size: 24,
                  ),
                ),
            ],
          ),
        ),
      ),
      title: Text(file.filename, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (file.durationSeconds != null)
            Text(
              DurationFormat.format(file.durationSeconds),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (file.watched == true)
            Row(
              children: [
                Icon(Icons.check_circle_outline,
                    size: 12, color: Colors.green.shade600),
                const SizedBox(width: 4),
                Text(
                  '已看完',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.green.shade600),
                ),
              ],
            )
          else if (file.progress != null && file.progress! > 0)
            LinearProgressIndicator(
              value: file.progress,
              minHeight: 3,
              backgroundColor: Colors.grey.shade300,
            ),
        ],
      ),
    );
  }
}
