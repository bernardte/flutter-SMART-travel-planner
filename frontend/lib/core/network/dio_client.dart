// lib/core/network/dio_client.dart

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

    // Safe preview — clamp so we never exceed actual token length
    final preview = (token != null && token.isNotEmpty)
        ? token.substring(0, token.length.clamp(0, 20))
        : 'null';
    print('🔑 Access token: $preview...');

    if (token != null && token.isNotEmpty) {
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

    final skipRefresh = requestUrl.contains('/users/login') ||
        requestUrl.contains('/users/register-account') ||
        requestUrl.contains('/refreshToken');

    if (statusCode == 401 && !skipRefresh) {
      print('⚠️ 401 on $requestUrl — attempting silent token refresh');
      try {
        final refreshToken = await SecureStorage.getRefreshToken();
        if (refreshToken == null || refreshToken.isEmpty) {
          print('❌ No refresh token — session expired, user must log in');
          await SecureStorage.clearAll();
          return handler.next(err);
        }

        // Use a clean Dio (no interceptors) to avoid infinite recursion.
        // Send refresh token as Bearer header — works for both cookie-less
        // mobile clients and the existing web flow.
        final refreshDio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));
        final res = await refreshDio.get(
          ApiConstants.refreshToken,
          options: Options(
            headers: {'Authorization': 'Bearer $refreshToken'},
          ),
        );

        // Backend returns: { data: { accessToken, refreshToken } }
        final body = res.data['data'] ?? res.data;
        final newAccessToken = body['accessToken'] as String?;
        final newRefreshToken = body['refreshToken'] as String?;

        if (newAccessToken == null || newAccessToken.isEmpty) {
          throw Exception('Refresh response missing accessToken');
        }

        await SecureStorage.saveAccessToken(newAccessToken);
        if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
          await SecureStorage.saveRefreshToken(newRefreshToken);
        }
        print('✅ Token refreshed — retrying original request');

        final retryOptions = err.requestOptions;
        retryOptions.headers['Authorization'] = 'Bearer $newAccessToken';

        final retryResponse = await _dio.fetch(retryOptions);
        return handler.resolve(retryResponse);
      } catch (e) {
        print('❌ Token refresh failed: $e — clearing session');
        await SecureStorage.clearAll();
        return handler.next(err);
      }
    }

    handler.next(err);
  }
}
