// lib/features/auth/domain/user_model.dart
// 用户数据模型

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
}
