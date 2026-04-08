// lib/features/library/presentation/widgets/file_grid_tile.dart
// 网格模式文件卡片（上图下标题）

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../shared/utils/duration_format.dart';
import '../../domain/file_model.dart';

class FileGridTile extends StatelessWidget {
  const FileGridTile({
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
    return GestureDetector(
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
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
                        color: Colors.white,
                        size: 32,
                        shadows: [
                          Shadow(color: Colors.black54, blurRadius: 8),
                        ],
                      ),
                    ),
                  if (file.isVideo && file.durationSeconds != null)
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          DurationFormat.format(file.durationSeconds),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: SizedBox(
                height: 32,
                child: Text(
                  file.filename,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
