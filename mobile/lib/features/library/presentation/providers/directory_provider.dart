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

/// 当前目录的内容
@riverpod
Future<DirectoryContent> directoryContent(
  DirectoryContentRef ref,
  String libraryId,
  String path,
) =>
    ref.read(libraryRepositoryProvider).listDirectory(libraryId, path);

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
