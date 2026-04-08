// lib/features/player/data/progress_api.dart
// 播放进度 API

import 'package:dio/dio.dart';

class ProgressApi {
  ProgressApi(this._dio);

  final Dio _dio;

  /// 获取播放进度，返回上次播放的 position（秒）
  Future<double?> getProgress(String fileId) async {
    try {
      final resp =
          await _dio.get<Map<String, dynamic>>('/api/files/$fileId/progress');
      final data = resp.data!;
      final position = (data['position'] as num?)?.toDouble();
      return position;
    } catch (_) {
      return null;
    }
  }

  Future<void> reportProgress(
    String fileId,
    double position,
    double duration,
  ) async {
    await _dio.put<void>(
      '/api/files/$fileId/progress',
      data: {
        'position': position,
        'duration': duration,
      },
    );
  }
}
