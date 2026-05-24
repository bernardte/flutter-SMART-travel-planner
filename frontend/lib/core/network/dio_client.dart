// lib/core/network/dio_client.dart
// Replaces frontend/src/lib/axios.ts
// Handles: base URL, Bearer token injection, silent token refresh on 401.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/secure_storage.dart';
import '../utils/api_constants.dart';

final dioClientProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  dio.interceptors.add(_AuthInterceptor(dio));

  return dio;
});

class _AuthInterceptor extends QueuedInterceptor {
  final Dio _dio;

  _AuthInterceptor(this._dio);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await SecureStorage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final statusCode = err.response?.statusCode;
    final requestUrl = err.requestOptions.path;

    // Skip refresh for auth endpoints
    final skipRefresh = requestUrl.contains('/users/login') ||
        requestUrl.contains('/users/register-account') ||
        requestUrl.contains('/refreshToken');

    if (statusCode == 401 && !skipRefresh) {
      try {
        final refreshToken = await SecureStorage.getRefreshToken();
        if (refreshToken == null) {
          await SecureStorage.clearAll();
          return handler.next(err);
        }

        // Call refresh endpoint
        final refreshDio = Dio(
          BaseOptions(baseUrl: ApiConstants.baseUrl),
        );
        final res = await refreshDio.get(
          ApiConstants.refreshToken,
          options: Options(
            headers: {'Authorization': 'Bearer $refreshToken'},
          ),
        );

        final newAccessToken = res.data['data']['accessToken'] as String?;
        if (newAccessToken == null) throw Exception('No access token in refresh response');

        await SecureStorage.saveAccessToken(newAccessToken);

        // Retry original request with new token
        final retryOptions = err.requestOptions;
        retryOptions.headers['Authorization'] = 'Bearer $newAccessToken';

        final retryResponse = await _dio.fetch(retryOptions);
        return handler.resolve(retryResponse);
      } catch (_) {
        await SecureStorage.clearAll();
        return handler.next(err);
      }
    }

    handler.next(err);
  }
}
