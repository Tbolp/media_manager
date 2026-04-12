// lib/features/upload/presentation/providers/upload_provider.dart
// 上传队列管理器

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/network/dio_client.dart';
import '../../data/upload_api.dart';
import '../../domain/upload_task.dart';

part 'upload_provider.g.dart';

const _uuid = Uuid();

@Riverpod(keepAlive: true)
class UploadNotifier extends _$UploadNotifier {
  late UploadApi _api;

  /// 每个 libraryId 是否正在上传
  final _uploading = <String>{};

  @override
  List<UploadTask> build() {
    final dio = ref.watch(dioClientProvider);
    _api = UploadApi(dio);
    return [];
  }

  /// 添加多个文件到上传队列
  void addTasks({
    required String libraryId,
    required String subPath,
    required List<({String filePath, String filename, int fileSize})> files,
  }) {
    final newTasks = files.map((f) {
      return UploadTask(
        id: _uuid.v4(),
        libraryId: libraryId,
        subPath: subPath,
        filePath: f.filePath,
        filename: f.filename,
        fileSize: f.fileSize,
      );
    }).toList();

    state = [...state, ...newTasks];

    // 触发该 library 的上传处理
    _processNext(libraryId);
  }

  /// 取消任务（上传中 → 取消请求；等待中 → 直接移除）
  void cancelTask(String taskId) {
    final idx = state.indexWhere((t) => t.id == taskId);
    if (idx < 0) return;

    final task = state[idx];
    if (task.status == UploadStatus.uploading) {
      task.cancelToken?.cancel('用户取消');
    }

    // 从列表移除
    state = [...state]..removeAt(idx);
  }

  /// 重试失败任务
  void retryTask(String taskId) {
    final idx = state.indexWhere((t) => t.id == taskId);
    if (idx < 0) return;

    final task = state[idx];
    if (task.status != UploadStatus.failed) return;

    final updated = [...state];
    updated[idx] = task.copyWith(
      status: UploadStatus.waiting,
      progress: 0.0,
      error: null,
    );
    state = updated;

    _processNext(task.libraryId);
  }

  /// 清除所有已完成任务
  void clearCompleted() {
    state = state.where((t) => t.status != UploadStatus.completed).toList();
  }

  /// 移除单个已完成任务
  void removeTask(String taskId) {
    state = state.where((t) => t.id != taskId).toList();
  }

  /// 处理队列：同一 library 串行上传
  void _processNext(String libraryId) {
    if (_uploading.contains(libraryId)) return;

    final nextIdx = state.indexWhere(
      (t) => t.libraryId == libraryId && t.status == UploadStatus.waiting,
    );
    if (nextIdx < 0) return;

    _uploading.add(libraryId);

    final task = state[nextIdx];
    final cancelToken = CancelToken();

    // 更新状态为 uploading
    _updateTask(task.id, (t) => t.copyWith(
      status: UploadStatus.uploading,
      cancelToken: cancelToken,
    ));

    _doUpload(task.id, libraryId, cancelToken);
  }

  Future<void> _doUpload(
    String taskId,
    String libraryId,
    CancelToken cancelToken,
  ) async {
    try {
      final task = state.firstWhere((t) => t.id == taskId);

      await _api.uploadFile(
        libraryId: task.libraryId,
        subPath: task.subPath,
        filePath: task.filePath,
        filename: task.filename,
        cancelToken: cancelToken,
        onProgress: (sent, total) {
          if (total > 0) {
            _updateTask(taskId, (t) => t.copyWith(
              progress: sent / total,
            ));
          }
        },
      );

      _updateTask(taskId, (t) => t.copyWith(
        status: UploadStatus.completed,
        progress: 1.0,
        completedAt: DateTime.now(),
      ));
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        // 取消的任务已从列表移除，无需更新
        debugPrint('[Upload] 任务 $taskId 已取消');
      } else {
        _updateTask(taskId, (t) => t.copyWith(
          status: UploadStatus.failed,
          error: e.response?.data?['detail']?.toString() ?? e.message ?? '上传失败',
        ));
      }
    } catch (e) {
      _updateTask(taskId, (t) => t.copyWith(
        status: UploadStatus.failed,
        error: e.toString(),
      ));
    } finally {
      _uploading.remove(libraryId);
      _processNext(libraryId);
    }
  }

  void _updateTask(String taskId, UploadTask Function(UploadTask) updater) {
    final idx = state.indexWhere((t) => t.id == taskId);
    if (idx < 0) return;
    final updated = [...state];
    updated[idx] = updater(updated[idx]);
    state = updated;
  }
}
