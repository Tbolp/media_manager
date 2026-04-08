// lib/features/library/data/library_repository.dart
// 媒体库仓库

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/network/dio_client.dart';
import '../domain/file_model.dart';
import '../domain/library_model.dart';
import 'library_api.dart';

part 'library_repository.g.dart';

class LibraryRepository {
  LibraryRepository(this._api);

  final LibraryApi _api;

  Future<List<LibraryModel>> getLibraries() => _api.getLibraries();

  Future<LibraryModel> getLibrary(String id) => _api.getLibrary(id);

  Future<DirectoryContent> listDirectory(String libraryId, String path,
          {int page = 1}) =>
      _api.listDirectory(libraryId, path, page: page);

  Future<List<FileModel>> searchFiles(String libraryId, String keyword) =>
      _api.searchFiles(libraryId, keyword);

  Future<bool> triggerRefresh(String libraryId) =>
      _api.triggerRefresh(libraryId);
}

@riverpod
LibraryRepository libraryRepository(LibraryRepositoryRef ref) =>
    LibraryRepository(LibraryApi(ref.watch(dioClientProvider)));
