// lib/features/library/presentation/library_detail_page.dart
// 媒体库详情页（目录浏览 + 搜索 + 刷新感知）

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants.dart';
import '../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../features/settings/providers/settings_provider.dart';
import '../../../shared/utils/url_builder.dart';
import '../../../shared/widgets/skeleton_grid.dart';
import '../../../shared/widgets/empty_state.dart';
import '../domain/file_model.dart';
import 'providers/directory_provider.dart';
import 'providers/library_provider.dart';
import 'widgets/file_grid_tile.dart';
import 'widgets/refresh_banner.dart';
import '../../player/presentation/image_preview_overlay.dart';

class LibraryDetailPage extends ConsumerStatefulWidget {
  const LibraryDetailPage({
    super.key,
    required this.libraryId,
  });

  final String libraryId;

  @override
  ConsumerState<LibraryDetailPage> createState() =>
      _LibraryDetailPageState();
}

class _LibraryDetailPageState extends ConsumerState<LibraryDetailPage> {
  String _searchKeyword = '';
  bool _isSearching = false;
  final _searchController = TextEditingController();
  Timer? _debounceTimer;

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(AppConstants.searchDebounce, () {
      if (mounted) setState(() => _searchKeyword = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentPath = ref.watch(
      currentPathProvider(widget.libraryId),
    );
    final baseUrl =
        ref.watch(settingsNotifierProvider.select((s) => s.serverUrl));
    final token = ref.watch(
          authNotifierProvider.select((s) => s.valueOrNull?.token),
        ) ??
        '';

    // 刷新状态轮询
    final refreshAsync =
        ref.watch(refreshStatusProvider(widget.libraryId));

    // 刷新完成后重新拉取文件列表
    ref.listen(
      refreshStatusProvider(widget.libraryId),
      (prev, next) {
        final prevLibrary = prev?.valueOrNull;
        final nextLibrary = next.valueOrNull;
        if (prevLibrary != null &&
            nextLibrary != null &&
            prevLibrary.isRefreshing &&
            !nextLibrary.isRefreshing) {
          ref.invalidate(
            directoryContentProvider(widget.libraryId, currentPath),
          );
        }
      },
    );

    final libraryName = ref
            .watch(librariesProvider)
            .valueOrNull
            ?.where((l) => l.id == widget.libraryId)
            .firstOrNull
            ?.name ??
        '';
    final isRefreshing = refreshAsync.valueOrNull?.isRefreshing ?? false;

    return PopScope(
      canPop: currentPath.isEmpty,
      onPopInvoked: (_) {
        if (currentPath.isNotEmpty) {
          // 子目录：返回上级
          ref.read(currentPathProvider(widget.libraryId).notifier).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: _isSearching
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: '搜索文件名...',
                    border: InputBorder.none,
                  ),
                  onChanged: _onSearchChanged,
                )
              : Text(
                  currentPath.isEmpty
                      ? libraryName
                      : currentPath.split('/').last,
                ),
          actions: [
            IconButton(
              icon: Icon(_isSearching ? Icons.close : Icons.search_outlined),
              onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _searchKeyword = '';
                    _searchController.clear();
                  }
                });
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // 刷新横幅
            if (isRefreshing) const RefreshBanner(),

            // 内容区域
            Expanded(
              child: _isSearching && _searchKeyword.isNotEmpty
                  ? _SearchResults(
                      libraryId: widget.libraryId,
                      keyword: _searchKeyword,
                      baseUrl: baseUrl,
                      token: token,
                    )
                  : _DirectoryView(
                      libraryId: widget.libraryId,
                      path: currentPath,
                      baseUrl: baseUrl,
                      token: token,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// 面包屑
// ──────────────────────────────────────────────
class _BreadcrumbRow extends ConsumerWidget {
  const _BreadcrumbRow({
    required this.libraryId,
    required this.path,
    required this.libraryName,
  });

  final String libraryId;
  final String path;
  final String libraryName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final segments = path.split('/');
    final notifier = ref.read(currentPathProvider(libraryId).notifier);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          TextButton(
            onPressed: () => notifier.navigate(''),
            style: TextButton.styleFrom(padding: const EdgeInsets.all(4)),
            child: Text(libraryName),
          ),
          ...List.generate(segments.length, (i) {
            final fullPath = segments.sublist(0, i + 1).join('/');
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.chevron_right, size: 16),
                TextButton(
                  onPressed: i == segments.length - 1
                      ? null
                      : () => notifier.navigate(fullPath),
                  style: TextButton.styleFrom(padding: const EdgeInsets.all(4)),
                  child: Text(segments[i]),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// 目录内容视图
// ──────────────────────────────────────────────
class _DirectoryView extends ConsumerWidget {
  const _DirectoryView({
    required this.libraryId,
    required this.path,
    required this.baseUrl,
    required this.token,
  });

  final String libraryId;
  final String path;
  final String baseUrl;
  final String token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentAsync =
        ref.watch(directoryContentProvider(libraryId, path));

    return contentAsync.when(
      loading: () => const SkeletonGrid(),
      error: (err, _) => Center(child: Text('加载失败：$err')),
      data: (content) {
        final dirs = content.dirs;
        final files = content.files;
        final hasMore = content.hasMore;
        final notifier =
            ref.read(currentPathProvider(libraryId).notifier);

        if (dirs.isEmpty && files.isEmpty) {
          return const EmptyState(
            icon: Icons.folder_open_outlined,
            message: '此目录暂无文件',
          );
        }

        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (hasMore &&
                notification.metrics.pixels >=
                    notification.metrics.maxScrollExtent - 200) {
              ref
                  .read(directoryContentProvider(libraryId, path).notifier)
                  .loadMore();
            }
            return false;
          },
          child: _buildGrid(context, dirs, files, hasMore, notifier, ref),
        );
      },
    );
  }

  Widget _buildGrid(
    BuildContext context,
    List<String> dirs,
    List<FileModel> files,
    bool hasMore,
    CurrentPath notifier,
    WidgetRef ref,
  ) {
    final totalCount = dirs.length + files.length;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(8),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.85,
            ),
            delegate: SliverChildBuilderDelegate(
              (_, i) {
                if (i < dirs.length) {
                  return _DirGridTile(
                    name: dirs[i],
                    onTap: () => notifier.navigate(
                      path.isEmpty ? dirs[i] : '$path/${dirs[i]}',
                    ),
                  );
                }
                final file = files[i - dirs.length];
                return FileGridTile(
                  file: file,
                  thumbnailUrl:
                      UrlBuilder.thumbnailUrl(baseUrl, file.id, token),
                  onTap: () =>
                      _onFileTap(context, file, files, i - dirs.length),
                );
              },
              childCount: totalCount,
            ),
          ),
        ),
        if (hasMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      ],
    );
  }

  void _onFileTap(
    BuildContext context,
    FileModel file,
    List<FileModel> files,
    int index,
  ) {
    if (file.isVideo) {
      context.push('/library/$libraryId/play/${file.id}?title=${Uri.encodeComponent(file.filename)}');
    } else if (file.isImage) {
      final images = files.where((f) => f.isImage).toList();
      final imageIndex = images.indexWhere((f) => f.id == file.id);
      Navigator.of(context).push(
        PageRouteBuilder(
          opaque: false,
          pageBuilder: (_, __, ___) => ImagePreviewOverlay(
            images: images,
            initialIndex: imageIndex < 0 ? 0 : imageIndex,
            baseUrl: baseUrl,
            token: token,
          ),
        ),
      );
    }
  }
}

// ──────────────────────────────────────────────
// 搜索结果视图
// ──────────────────────────────────────────────
class _SearchResults extends ConsumerWidget {
  const _SearchResults({
    required this.libraryId,
    required this.keyword,
    required this.baseUrl,
    required this.token,
  });

  final String libraryId;
  final String keyword;
  final String baseUrl;
  final String token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync =
        ref.watch(searchFilesProvider(libraryId, keyword));

    return resultsAsync.when(
      loading: () => const SkeletonGrid(),
      error: (err, _) => Center(child: Text('搜索失败：$err')),
      data: (files) {
        if (files.isEmpty) {
          return const EmptyState(
            icon: Icons.search_off,
            message: '未找到匹配的文件',
          );
        }
        final totalCount = files.length;
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(8),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.85,
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, i) {
                    final file = files[i];
                    return FileGridTile(
                      file: file,
                      thumbnailUrl:
                          UrlBuilder.thumbnailUrl(baseUrl, file.id, token),
                      onTap: () {
                        if (file.isVideo) {
                          context.push('/library/$libraryId/play/${file.id}?title=${Uri.encodeComponent(file.filename)}');
                        } else if (file.isImage) {
                          final images =
                              files.where((f) => f.isImage).toList();
                          final idx =
                              images.indexWhere((f) => f.id == file.id);
                          Navigator.of(context).push(
                            PageRouteBuilder(
                              opaque: false,
                              pageBuilder: (_, __, ___) =>
                                  ImagePreviewOverlay(
                                images: images,
                                initialIndex: idx < 0 ? 0 : idx,
                                baseUrl: baseUrl,
                                token: token,
                              ),
                            ),
                          );
                        }
                      },
                    );
                  },
                  childCount: totalCount,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ──────────────────────────────────────────────
// 目录 Grid Tile
// ──────────────────────────────────────────────
class _DirGridTile extends StatelessWidget {
  const _DirGridTile({required this.name, required this.onTap});

  final String name;
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
              child: Container(
                color: Colors.grey.shade200,
                child: Center(
                  child: Icon(
                    Icons.folder_outlined,
                    color: Colors.grey.shade600,
                    size: 40,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: SizedBox(
                height: 32,
                child: Text(
                  name,
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
