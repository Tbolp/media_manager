// lib/core/utils/jwt_utils.dart
// JWT 解码工具：从 token 中提取用户信息，无需额外依赖

import 'dart:convert';

class JwtUtils {
  JwtUtils._();

  /// 解码 JWT payload（不验证签名，签名由后端验证）。
  /// 返回 claims map；token 格式不合法时返回 null。
  static Map<String, dynamic>? decodePayload(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;

    try {
      final payload = parts[1];
      // Base64Url → 补齐 padding
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      return json.decode(decoded) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// 检查 JWT 是否已过期（基于 `exp` claim）。
  static bool isExpired(String token) {
    final claims = decodePayload(token);
    if (claims == null) return true;

    final exp = claims['exp'];
    if (exp is! num) return true;

    final expiry = DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
    return DateTime.now().isAfter(expiry);
  }
}
