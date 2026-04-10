// lib/features/library/presentation/widgets/file_grid_tile.dart
// 网格模式文件卡片（上图下标题，支持焦点导航）

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
    return FocusableCard(
      onTap: onTap,
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
    );
  }
}

/// 可聚焦的卡片容器，支持 D-pad 焦点高亮和确认键点击
class FocusableCard extends StatefulWidget {
  const FocusableCard({
    super.key,
    required this.onTap,
    required this.child,
  });

  final VoidCallback onTap;
  final Widget child;

  @override
  State<FocusableCard> createState() => _FocusableCardState();
}

class _FocusableCardState extends State<FocusableCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: _focused
                ? Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 3,
                  )
                : null,
          ),
          transform: _focused
              ? (Matrix4.identity()..scale(1.05, 1.05))
              : Matrix4.identity(),
          transformAlignment: Alignment.center,
          child: Card(
            clipBehavior: Clip.antiAlias,
            margin: EdgeInsets.zero,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
