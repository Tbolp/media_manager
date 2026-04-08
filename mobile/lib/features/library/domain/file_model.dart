// lib/features/library/domain/file_model.dart
// 文件 & 目录内容数据模型

class FileModel {
  const FileModel({
    required this.id,
    required this.filename,
    required this.relativePath,
    required this.fileType,
    this.durationSeconds,
    this.progress,
    this.watched,
  });

  final String id;
  final String filename;
  final String relativePath;
  final String fileType; // 'video' | 'image'
  final double? durationSeconds;
  final double? progress; // 0.0~1.0，null 表示未播放
  final bool? watched;

  bool get isVideo => fileType == 'video';
  bool get isImage => fileType == 'image';

  factory FileModel.fromJson(Map<String, dynamic> json) => FileModel(
        id: json['id'] as String,
        filename: json['filename'] as String,
        relativePath: json['relative_path'] as String,
        fileType: json['file_type'] as String,
        durationSeconds: (json['duration'] as num?)?.toDouble(),
        progress: (json['progress'] as num?)?.toDouble(),
        watched: json['is_watched'] as bool?,
      );
}

class DirectoryContent {
  const DirectoryContent({
    required this.path,
    required this.dirs,
    required this.files,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  final String path;
  final List<String> dirs;
  final List<FileModel> files;
  final int total;
  final int page;
  final int pageSize;

  factory DirectoryContent.fromJson(Map<String, dynamic> json) =>
      DirectoryContent(
        path: json['path'] as String? ?? '',
        dirs: (json['dirs'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        files: (json['items'] as List<dynamic>?)
                ?.map((e) => FileModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        total: json['total'] as int? ?? 0,
        page: json['page'] as int? ?? 1,
        pageSize: json['page_size'] as int? ?? 30,
      );
}
