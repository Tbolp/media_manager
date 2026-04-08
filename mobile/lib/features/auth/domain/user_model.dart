// lib/features/auth/domain/user_model.dart
// 用户数据模型

import '../../../core/utils/jwt_utils.dart';

class UserModel {
  const UserModel({
    required this.id,
    required this.username,
    required this.role,
    required this.token,
  });

  final String id;
  final String username;
  final String role; // 'admin' | 'user'
  final String token;

  bool get isAdmin => role == 'admin';

  factory UserModel.fromJson(Map<String, dynamic> json, String token) =>
      UserModel(
        id: json['id'] as String,
        username: json['username'] as String,
        role: json['role'] as String,
        token: token,
      );

  /// 直接从 JWT token 解析用户信息。
  /// JWT payload 包含：sub(userId), name(username), role, ver, exp
  /// 返回 null 如果 token 格式无效。
  /// 注意：不检查过期，过期由后端 401 处理（客户端时钟可能不准）。
  static UserModel? fromToken(String token) {
    final claims = JwtUtils.decodePayload(token);
    if (claims == null) return null;

    final id = claims['sub'] as String?;
    final username = claims['name'] as String?;
    final role = claims['role'] as String?;

    if (id == null || username == null || role == null) return null;

    return UserModel(id: id, username: username, role: role, token: token);
  }
}
