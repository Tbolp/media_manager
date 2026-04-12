// lib/features/upload/data/upload_api.dart
// 上传 API 调用（raw body 流式上传）

import 'dart:io';

import 'package:dio/dio.dart';

class UploadApi {
  UploadApi(this._dio);

  final Dio _dio;

  /// 上传单个文件到媒体库。
  ///
  /// 后端接口：POST /api/libraries/:id/upload?path=subPath
  /// 使用 raw body 流式传输，文件名通过 Content-Disposition header 传递。
  Future<void> uploadFile({
    required String libraryId,
    required String subPath,
    required String filePath,
    required String filename,
    required CancelToken cancelToken,
    required void Function(int sent, int total) onProgress,
  }) async {
    final file = File(filePath);
    final length = await file.length();
    final stream = file.openRead();

    await _dio.post<Map<String, dynamic>>(
      '/api/libraries/$libraryId/upload',
      queryParameters: {
        if (subPath.isNotEmpty) 'path': subPath,
      },
      data: stream,
      options: Options(
        headers: {
          'Content-Type': 'application/octet-stream',
          'Content-Disposition':
              'attachment; filename="${Uri.encodeComponent(filename)}"',
          'Content-Length': length,
        },
        // 上传大文件需要更长超时
        sendTimeout: const Duration(minutes: 30),
        receiveTimeout: const Duration(minutes: 5),
      ),
      cancelToken: cancelToken,
      onSendProgress: onProgress,
    );
  }
}
