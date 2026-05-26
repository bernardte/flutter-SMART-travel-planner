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

  // 🔥 LEVEL 3 FIX: refresh lock
  bool _isRefreshing = false;

  // 🔥 LEVEL 3 FIX: request queue
  final List<Function> _queue = [];

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await SecureStorage.getAccessToken();

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

    // ❌ not 401 → ignore
    if (statusCode != 401 || skipRefresh) {
      return handler.next(err);
    }

    // 🔥 LEVEL 3 FIX: if already refreshing → queue request
    if (_isRefreshing) {
      _queue.add(() async {
        try {
          final token = await SecureStorage.getAccessToken();
          final retryOptions = err.requestOptions;

          if (token != null) {
            retryOptions.headers['Authorization'] = 'Bearer $token';
          }

          final response = await _dio.fetch(retryOptions);
          handler.resolve(response);
        } catch (e) {
          handler.next(err);
        }
      });
      return;
    }

    _isRefreshing = true;

    try {
      final refreshToken = await SecureStorage.getRefreshToken();

      if (refreshToken == null || refreshToken.isEmpty) {
        await SecureStorage.clearAll();
        handler.next(err);
        return;
      }

      // 🔥 timeout prevents emulator freeze
      final refreshDio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));

      final res = await refreshDio
          .get(
            ApiConstants.refreshToken,
            options: Options(
              headers: {'Authorization': 'Bearer $refreshToken'},
            ),
          )
          .timeout(const Duration(seconds: 10));

      final body = res.data['data'] ?? res.data;
      final newAccessToken = body['accessToken'] as String?;
      final newRefreshToken = body['refreshToken'] as String?;

      if (newAccessToken == null || newAccessToken.isEmpty) {
        throw Exception('Missing accessToken');
      }

      await SecureStorage.saveAccessToken(newAccessToken);

      if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
        await SecureStorage.saveRefreshToken(newRefreshToken);
      }

      // 🔥 retry original request
      final retryOptions = err.requestOptions;
      retryOptions.headers['Authorization'] = 'Bearer $newAccessToken';

      final retryResponse = await _dio.fetch(retryOptions);
      handler.resolve(retryResponse);

      // 🔥 flush queue requests
      for (final task in _queue) {
        await task();
      }
      _queue.clear();
    } catch (e) {
      await SecureStorage.clearAll();
      handler.next(err);
    } finally {
      _isRefreshing = false;
    }
  }
}
