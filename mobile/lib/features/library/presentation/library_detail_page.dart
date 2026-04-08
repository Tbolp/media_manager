// lib/features/library/presentation/library_detail_page.dart
// 媒体库详情页（目录浏览 + 搜索 + 刷新感知）

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants.dart';
import '../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../features/settings/providers/settings_provider.dart';
import '../../../core/storage/prefs_storage.dart';
import '../../../shared/utils/url_builder.dart';
import '../../../shared/widgets/skeleton_list.dart';
import '../../../shared/widgets/skeleton_grid.dart';
import '../../../shared/widgets/empty_state.dart';
import '../domain/file_model.dart';
import 'providers/directory_provider.dart';
import 'providers/library_provider.dart';
import 'widgets/file_grid_tile.dart';
import 'widgets/file_list_tile.dart';
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
    final viewMode = ref.watch(
      settingsNotifierProvider.select((s) => s.libraryViewMode),
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

    final libraryName =
        refreshAsync.valueOrNull?.name ?? '媒体库';
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
            if (!_isSearching)
              IconButton(
                icon: Icon(
                  viewMode == ViewMode.grid
                      ? Icons.view_list_outlined
                      : Icons.grid_view_outlined,
                ),
                onPressed: () {
                  final newMode = viewMode == ViewMode.grid
                      ? ViewMode.list
                      : ViewMode.grid;
                  ref
                      .read(settingsNotifierProvider.notifier)
                      .saveViewMode(newMode);
                },
              ),
          ],
        ),
        body: Column(
          children: [
            // 刷新横幅
            if (isRefreshing) const RefreshBanner(),

            // 面包屑（非根目录时显示）
            if (currentPath.isNotEmpty && !_isSearching)
              _BreadcrumbRow(
                libraryId: widget.libraryId,
                path: currentPath,
                libraryName: libraryName,
              ),

            // 内容区域
            Expanded(
              child: _isSearching && _searchKeyword.isNotEmpty
                  ? _SearchResults(
                      libraryId: widget.libraryId,
                      keyword: _searchKeyword,
                      baseUrl: baseUrl,
                      token: token,
                      viewMode: viewMode,
                    )
                  : _DirectoryView(
                      libraryId: widget.libraryId,
                      path: currentPath,
                      baseUrl: baseUrl,
                      token: token,
                      viewMode: viewMode,
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
    required this.viewMode,
  });

  final String libraryId;
  final String path;
  final String baseUrl;
  final String token;
  final ViewMode viewMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentAsync =
        ref.watch(directoryContentProvider(libraryId, path));

    return contentAsync.when(
      loading: () => viewMode == ViewMode.grid
          ? const SkeletonGrid()
          : const SkeletonList(),
      error: (err, _) => Center(child: Text('加载失败：$err')),
      data: (content) {
        final dirs = content.dirs;
        final files = content.files;
        final notifier =
            ref.read(currentPathProvider(libraryId).notifier);

        if (dirs.isEmpty && files.isEmpty) {
          return const EmptyState(
            icon: Icons.folder_open_outlined,
            message: '此目录暂无文件',
          );
        }

        if (viewMode == ViewMode.grid && files.isNotEmpty) {
          // 网格模式（相机库）
          return CustomScrollView(
            slivers: [
              if (dirs.isNotEmpty)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _DirTile(
                      name: dirs[i],
                      onTap: () => notifier.navigate(
                        path.isEmpty ? dirs[i] : '$path/${dirs[i]}',
                      ),
                    ),
                    childCount: dirs.length,
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.all(4),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 2,
                    mainAxisSpacing: 2,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (_, i) {
                      final file = files[i];
                      return FileGridTile(
                        file: file,
                        thumbnailUrl: UrlBuilder.thumbnailUrl(
                            baseUrl, file.id, token),
                        onTap: () => _onFileTap(context, file, files, i),
                      );
                    },
                    childCount: files.length,
                  ),
                ),
              ),
            ],
          );
        }

        // 列表模式
        final allItems = <_ListItem>[
          ...dirs.map(
            (d) => _ListItem.dir(
              name: d,
              onTap: () => notifier.navigate(
                path.isEmpty ? d : '$path/$d',
              ),
            ),
          ),
          ...files.map(
            (f) => _ListItem.file(
              file: f,
              onTap: () => _onFileTap(context, f, files,
                  files.indexOf(f)),
            ),
          ),
        ];

        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(directoryContentProvider(libraryId, path)),
          child: ListView.builder(
            itemCount: allItems.length,
            itemBuilder: (_, i) {
              final item = allItems[i];
              if (item.isDir) {
                return _DirTile(
                    name: item.name!, onTap: item.onTap);
              }
              final file = item.file!;
              return FileListTile(
                file: file,
                thumbnailUrl:
                    UrlBuilder.thumbnailUrl(baseUrl, file.id, token),
                onTap: item.onTap,
              );
            },
          ),
        );
      },
    );
  }

  void _onFileTap(
    BuildContext context,
    FileModel file,
    List<FileModel> files,
    int index,
  ) {
    if (file.isVideo) {
      context.push('/library/$libraryId/play/${file.id}');
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
    required this.viewMode,
  });

  final String libraryId;
  final String keyword;
  final String baseUrl;
  final String token;
  final ViewMode viewMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync =
        ref.watch(searchFilesProvider(libraryId, keyword));

    return resultsAsync.when(
      loading: () => const SkeletonList(),
      error: (err, _) => Center(child: Text('搜索失败：$err')),
      data: (files) {
        if (files.isEmpty) {
          return const EmptyState(
            icon: Icons.search_off,
            message: '未找到匹配的文件',
          );
        }
        return ListView.builder(
          itemCount: files.length,
          itemBuilder: (_, i) {
            final file = files[i];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FileListTile(
                  file: file,
                  thumbnailUrl:
                      UrlBuilder.thumbnailUrl(baseUrl, file.id, token),
                  onTap: () {
                    if (file.isVideo) {
                      context.push('/library/$libraryId/play/${file.id}');
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
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 104, right: 16),
                  child: Text(
                    file.relativePath,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Divider(height: 1),
              ],
            );
          },
        );
      },
    );
  }
}

// ──────────────────────────────────────────────
// 目录 Tile
// ──────────────────────────────────────────────
class _DirTile extends StatelessWidget {
  const _DirTile({required this.name, required this.onTap});

  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.folder_outlined),
      title: Text(name),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

// ──────────────────────────────────────────────
// 列表项联合类
// ──────────────────────────────────────────────
class _ListItem {
  _ListItem.dir({required this.name, required this.onTap})
      : isDir = true,
        file = null;

  _ListItem.file({required this.file, required this.onTap})
      : isDir = false,
        name = null;

  final bool isDir;
  final String? name;
  final FileModel? file;
  final VoidCallback onTap;
}
