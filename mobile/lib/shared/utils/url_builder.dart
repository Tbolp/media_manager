// lib/shared/utils/url_builder.dart
// 拼接缩略图/原图/视频流 URL

class UrlBuilder {
  UrlBuilder._();

  static String thumbnailUrl(
    String baseUrl,
    String fileId,
    String token,
  ) =>
      '$baseUrl/api/files/$fileId/thumbnail?token=$token';

  static String videoUrl(
    String baseUrl,
    String fileId,
    String token,
  ) =>
      '$baseUrl/api/files/$fileId/stream?token=$token';

  static String rawImageUrl(
    String baseUrl,
    String fileId,
    String token,
  ) =>
      '$baseUrl/api/files/$fileId/raw?token=$token';
}
