// lib/core/exceptions.dart
// 业务异常类型

class AppException implements Exception {
  const AppException(this.message);
  final String message;

  @override
  String toString() => 'AppException: $message';
}

class NetworkException extends AppException {
  const NetworkException(super.message);
}

class UnauthorizedException extends AppException {
  const UnauthorizedException(this.errorCode, super.message);
  final String errorCode;
}

class ForbiddenException extends AppException {
  const ForbiddenException([super.message = '您已无权访问此资源']);
}

class NotFoundException extends AppException {
  const NotFoundException([super.message = '资源不存在']);
}

class ServerException extends AppException {
  const ServerException([super.message = '服务异常，请稍后再试']);
}
