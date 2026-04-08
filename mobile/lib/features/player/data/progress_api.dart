// lib/features/player/data/progress_api.dart
// 播放进度 API

import 'package:dio/dio.dart';

class ProgressApi {
  ProgressApi(this._dio);

  final Dio _dio;

  Future<double?> getProgress(String fileId) async {
    try {
      final resp =
          await _dio.get<Map<String, dynamic>>('/api/files/$fileId/progress');
      final data = resp.data!;
      final duration = (data['duration'] as num?)?.toDouble();
      final position = (data['position'] as num?)?.toDouble();
      if (duration == null || duration <= 0) return null;
      return position! / duration;
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
