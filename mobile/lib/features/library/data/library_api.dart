// lib/features/library/data/library_api.dart
// 媒体库相关 API 调用

import 'package:dio/dio.dart';
import '../domain/file_model.dart';
import '../domain/library_model.dart';

class LibraryApi {
  LibraryApi(this._dio);

  final Dio _dio;

  Future<List<LibraryModel>> getLibraries() async {
    final resp = await _dio.get<Map<String, dynamic>>('/api/libraries');
    final items = resp.data!['items'] as List<dynamic>;
    return items
        .map((e) => LibraryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<LibraryModel> getLibrary(String id) async {
    final resp = await _dio.get<Map<String, dynamic>>('/api/libraries/$id');
    return LibraryModel.fromJson(resp.data!);
  }

  Future<DirectoryContent> listDirectory(
    String libraryId,
    String path, {
    int page = 1,
    int pageSize = 30,
  }) async {
    final resp = await _dio.get<Map<String, dynamic>>(
      '/api/libraries/$libraryId/files',
      queryParameters: {
        if (path.isNotEmpty) 'path': path,
        'page': page,
        'page_size': pageSize,
      },
    );
    return DirectoryContent.fromJson(resp.data!);
  }

  Future<List<FileModel>> searchFiles(
    String libraryId,
    String keyword, {
    int page = 1,
    int pageSize = 30,
  }) async {
    final resp = await _dio.get<Map<String, dynamic>>(
      '/api/libraries/$libraryId/files',
      queryParameters: {
        'q': keyword,
        'page': page,
        'page_size': pageSize,
      },
    );
    final items = resp.data!['items'] as List<dynamic>;
    return items
        .map((e) => FileModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<bool> triggerRefresh(String libraryId) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      '/api/libraries/$libraryId/refresh',
    );
    return resp.data!['queued'] as bool;
  }
}
