// lib/features/library/presentation/providers/directory_provider.dart
// 目录浏览状态（页面内，不共享路由）

import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/library_repository.dart';
import '../../domain/file_model.dart';

part 'directory_provider.g.dart';

/// 当前目录路径（页面内状态）
@riverpod
class CurrentPath extends _$CurrentPath {
  @override
  String build(String libraryId) => ''; // 空字符串 = 根目录

  void navigate(String path) => state = path;

  void pop() => state = _parentOf(state);

  static String _parentOf(String path) {
    if (path.isEmpty) return '';
    final idx = path.lastIndexOf('/');
    return idx < 0 ? '' : path.substring(0, idx);
  }
}

/// 累积的目录内容（分页加载）
class AccumulatedContent {
  const AccumulatedContent({
    required this.dirs,
    required this.files,
    required this.total,
    required this.currentPage,
    required this.pageSize,
    required this.hasMore,
  });

  final List<String> dirs;
  final List<FileModel> files;
  final int total;
  final int currentPage;
  final int pageSize;
  final bool hasMore;
}

/// 当前目录的内容（支持分页累加）
@riverpod
class DirectoryContent extends _$DirectoryContent {
  @override
  Future<AccumulatedContent> build(String libraryId, String path) async {
    final content = await ref
        .read(libraryRepositoryProvider)
        .listDirectory(libraryId, path);
    final totalFiles = content.total;
    final loadedFiles = content.files.length;
    // 目录列表在第一页就全部返回，后续分页只影响文件
    final hasMore = loadedFiles < totalFiles;
    return AccumulatedContent(
      dirs: content.dirs,
      files: content.files,
      total: totalFiles,
      currentPage: 1,
      pageSize: content.pageSize,
      hasMore: hasMore,
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore) return;

    final nextPage = current.currentPage + 1;
    final content = await ref.read(libraryRepositoryProvider).listDirectory(
          libraryId,
          path,
          page: nextPage,
        );

    final allFiles = [...current.files, ...content.files];
    final hasMore = allFiles.length < current.total;

    state = AsyncValue.data(AccumulatedContent(
      dirs: current.dirs,
      files: allFiles,
      total: current.total,
      currentPage: nextPage,
      pageSize: current.pageSize,
      hasMore: hasMore,
    ));
  }
}

/// 搜索结果
@riverpod
Future<List<FileModel>> searchFiles(
  SearchFilesRef ref,
  String libraryId,
  String keyword,
) async {
  if (keyword.isEmpty) return [];
  return ref.read(libraryRepositoryProvider).searchFiles(libraryId, keyword);
}
