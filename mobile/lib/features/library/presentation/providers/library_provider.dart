// lib/features/library/presentation/providers/library_provider.dart
// 媒体库列表状态

import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/library_repository.dart';
import '../../domain/library_model.dart';

part 'library_provider.g.dart';

@riverpod
Future<List<LibraryModel>> libraries(LibrariesRef ref) =>
    ref.read(libraryRepositoryProvider).getLibraries();

/// 媒体库刷新状态轮询（Stream）
@riverpod
Stream<LibraryModel> refreshStatus(
  RefreshStatusRef ref,
  String libraryId,
) async* {
  while (true) {
    final library =
        await ref.read(libraryRepositoryProvider).getLibrary(libraryId);
    yield library;
    if (!library.isRefreshing) break;
    await Future<void>.delayed(const Duration(seconds: 5));
  }
}
