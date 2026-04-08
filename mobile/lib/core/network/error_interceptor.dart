// lib/core/network/error_interceptor.dart
// 统一错误处理拦截器

import 'package:dio/dio.dart';
import '../exceptions.dart';

class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final response = err.response;

    if (response == null) {
      handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          error: const NetworkException('网络连接失败，请检查网络'),
          type: err.type,
        ),
      );
      return;
    }

    final statusCode = response.statusCode;
    final detail = response.data?['detail'] as String?;

    switch (statusCode) {
      case 401:
        final errorCode =
            response.data?['error_code'] as String? ?? 'token_expired';
        handler.reject(
          DioException(
            requestOptions: err.requestOptions,
            response: response,
            error: UnauthorizedException(errorCode, detail ?? '登录已失效'),
          ),
        );
      case 403:
        handler.reject(
          DioException(
            requestOptions: err.requestOptions,
            response: response,
            error: ForbiddenException(detail ?? '您已无权访问此媒体库'),
          ),
        );
      case 404:
        handler.reject(
          DioException(
            requestOptions: err.requestOptions,
            response: response,
            error: NotFoundException(detail ?? '资源不存在'),
          ),
        );
      default:
        if (statusCode != null && statusCode >= 500) {
          handler.reject(
            DioException(
              requestOptions: err.requestOptions,
              response: response,
              error: const ServerException(),
            ),
          );
        } else {
          handler.next(err);
        }
    }
  }
}
