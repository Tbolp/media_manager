// lib/features/upload/domain/upload_task.dart
// 上传任务模型

import 'package:dio/dio.dart';

enum UploadStatus { waiting, uploading, completed, failed }

class UploadTask {
  const UploadTask({
    required this.id,
    required this.libraryId,
    required this.subPath,
    required this.filePath,
    required this.filename,
    required this.fileSize,
    this.status = UploadStatus.waiting,
    this.progress = 0.0,
    this.error,
    this.cancelToken,
    this.completedAt,
  });

  final String id;
  final String libraryId;
  final String subPath;
  final String filePath;
  final String filename;
  final int fileSize;
  final UploadStatus status;
  final double progress;
  final String? error;
  final CancelToken? cancelToken;
  final DateTime? completedAt;

  UploadTask copyWith({
    UploadStatus? status,
    double? progress,
    String? error,
    CancelToken? cancelToken,
    DateTime? completedAt,
  }) {
    return UploadTask(
      id: id,
      libraryId: libraryId,
      subPath: subPath,
      filePath: filePath,
      filename: filename,
      fileSize: fileSize,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      error: error ?? this.error,
      cancelToken: cancelToken ?? this.cancelToken,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
