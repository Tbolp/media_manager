// lib/features/library/domain/library_model.dart
// 媒体库数据模型

class LibraryModel {
  const LibraryModel({
    required this.id,
    required this.name,
    required this.libType,
    required this.refreshStatus,
    this.coverFileId,
  });

  final String id;
  final String name;
  final String libType; // 'video' | 'camera'
  final String refreshStatus; // 'idle' | 'running' | 'pending'
  final String? coverFileId;

  bool get isCamera => libType == 'camera';
  bool get isVideo => libType == 'video';
  bool get isRefreshing =>
      refreshStatus == 'running' || refreshStatus == 'pending';

  factory LibraryModel.fromJson(Map<String, dynamic> json) => LibraryModel(
        id: json['id'] as String,
        name: json['name'] as String,
        libType: json['lib_type'] as String,
        refreshStatus: json['refresh_status'] as String? ?? 'idle',
        coverFileId: json['cover_file_id'] as String?,
      );
}
