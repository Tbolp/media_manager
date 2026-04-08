// lib/features/library/presentation/widgets/library_card.dart
// 首页媒体库卡片

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/library/data/library_repository.dart';
import '../../../../features/settings/providers/settings_provider.dart';
import '../../../../shared/utils/url_builder.dart';
import '../../domain/library_model.dart';

class LibraryCard extends ConsumerStatefulWidget {
  const LibraryCard({
    super.key,
    required this.library,
    required this.onTap,
  });

  final LibraryModel library;
  final VoidCallback onTap;

  @override
  ConsumerState<LibraryCard> createState() => _LibraryCardState();
}

class _LibraryCardState extends ConsumerState<LibraryCard> {
  bool _refreshLoading = false;

  Future<void> _triggerRefresh() async {
    setState(() => _refreshLoading = true);
    try {
      final queued = await ref
          .read(libraryRepositoryProvider)
          .triggerRefresh(widget.library.id);
      if (!mounted) return;
      if (!queued) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('刷新任务已在队列中，无需重复提交')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('触发刷新失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _refreshLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = widget.library;
    final baseUrl =
        ref.watch(settingsNotifierProvider.select((s) => s.serverUrl));
    final token = ref.watch(
          authNotifierProvider.select((s) => s.valueOrNull?.token),
        ) ??
        '';

    final coverUrl = library.coverFileId != null
        ? UrlBuilder.thumbnailUrl(baseUrl, library.coverFileId!, token)
        : null;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 封面图
            AspectRatio(
              aspectRatio: 16 / 9,
              child: coverUrl != null
                  ? CachedNetworkImage(
                      imageUrl: coverUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _PlaceholderCover(library),
                      errorWidget: (_, __, ___) => _PlaceholderCover(library),
                    )
                  : _PlaceholderCover(library),
            ),
            // 信息栏
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    library.isCamera
                        ? Icons.camera_alt_outlined
                        : Icons.movie_outlined,
                    size: 18,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      library.name,
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // 刷新按钮（阻断点击冒泡）
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _triggerRefresh,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: _refreshLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_outlined, size: 20),
                    ),
                  ),
                ],
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
    return Container(
      color: Colors.grey.shade200,
      child: Center(
        child: Icon(
          library.isCamera
              ? Icons.camera_alt_outlined
              : Icons.movie_outlined,
          size: 48,
          color: Colors.grey.shade400,
        ),
      ),
    );
  }
}
