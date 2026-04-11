// lib/features/library/presentation/widgets/library_card.dart
// 首页媒体库网格卡片（上图下标题，右下角刷新按钮）

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../domain/library_model.dart';

class LibraryCard extends StatefulWidget {
  const LibraryCard({
    super.key,
    required this.library,
    required this.thumbnailUrl,
    required this.onTap,
    required this.onRefresh,
  });

  final LibraryModel library;
  final String? thumbnailUrl;
  final VoidCallback onTap;
  final Future<void> Function() onRefresh;

  @override
  State<LibraryCard> createState() => _LibraryCardState();
}

class _LibraryCardState extends State<LibraryCard> {
  bool _refreshLoading = false;

  Future<void> _triggerRefresh() async {
    setState(() => _refreshLoading = true);
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) setState(() => _refreshLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
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
                  widget.thumbnailUrl != null
                      ? CachedNetworkImage(
                          imageUrl: widget.thumbnailUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              _PlaceholderCover(widget.library),
                          errorWidget: (_, __, ___) =>
                              _PlaceholderCover(widget.library),
                        )
                      : _PlaceholderCover(widget.library),
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: GestureDetector(
                      onTap: _triggerRefresh,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: _refreshLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.refresh_outlined,
                                size: 16,
                                color: Colors.white,
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
                  widget.library.name,
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

class _PlaceholderCover extends StatelessWidget {
  const _PlaceholderCover(this.library);

  final LibraryModel library;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.surfaceVariant,
      child: Center(
        child: Icon(
          library.isCamera
              ? Icons.camera_alt_outlined
              : Icons.movie_outlined,
          size: 40,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
