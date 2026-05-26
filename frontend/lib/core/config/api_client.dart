import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:frontend/core/config/service_locator.dart';
import 'package:frontend/core/config/token_service.dart';
import 'package:frontend/data/repository/auth/logout_repository.dart';
import 'dart:io';


class ApiClient {
  static String get baseUrl => _getBaseUrl();

  static String _getBaseUrl() {
    const fallbackUrl = "http://10.0.2.2:8000/api";
    if (kIsWeb) {
      final webUrl = dotenv.env["DEV_BASE_URL"] ?? fallbackUrl;
      print("WEB URL: $webUrl");
      return webUrl;
    }

    if (Platform.isAndroid) {
      final androidUrl = dotenv.env["ANDROID_BASE_URL"] ??
          dotenv.env["DEV_BASE_URL"] ??
          fallbackUrl;
      print("ANDROID URL: $androidUrl");
      return androidUrl;
    }

    if (Platform.isIOS) {
      final iosUrl = dotenv.env["IOS_BASE_URL"] ??
          dotenv.env["DEV_BASE_URL"] ??
          fallbackUrl;
      print("IOS URL: $iosUrl");
      return iosUrl;
    }

    return dotenv.env["DEV_BASE_URL"] ?? fallbackUrl;
  }

  static final devBaseUrl = baseUrl;

  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: devBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {"Content-Type": "application/json"},
    ),
  );

  // Separate Dio for refresh — never goes through the main interceptor
  static final Dio _refreshDio = Dio(
    BaseOptions(
      baseUrl: devBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {"Content-Type": "application/json"},
    ),
  );

  static bool _isRefreshing = false;

  static void init() {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
           if (options.extra["skipAuth"] == true) {
            return handler.next(options);
          }

          final token = await getIt<TokenStorageService>().getToken();
          if (token != null) {
            options.headers["Authorization"] = "Bearer $token";
          }
          return handler.next(options);
        },

        onError: (DioException error, handler) async {
          final is401 = error.response?.statusCode == 401;
          final isRefreshRoute = error.requestOptions.path.contains(
            '/api/refreshToken',
          );
          final isSkip = error.requestOptions.extra["skipAuth"] == true;

          if (isSkip) {
            return handler.next(error);
          }

          if (is401 && !isRefreshRoute && !_isRefreshing) {
            _isRefreshing = true;
            final refreshed = await _tryRefreshToken();
            _isRefreshing = false;

            if (refreshed) {
              // Retry original request with new token
              final newToken = await getIt<TokenStorageService>().getToken();
              final opts = error.requestOptions;
              opts.headers["Authorization"] = "Bearer $newToken";
              try {
                final retryResponse = await dio.fetch(opts);
                return handler.resolve(retryResponse);
              } catch (_) {
                return handler.next(error);
              }
            } else {
              // Refresh failed — force logout via GlobalCubit (context-safe)
              await getIt<LogoutRepository>().logout();
              return handler.next(error);
            }
          }

          return handler.next(error);
        },
      ),
    );
  }

  static Future<bool> _tryRefreshToken() async {
    try {
      final refreshToken = await getIt<TokenStorageService>().getRefreshToken();
      if (refreshToken == null) return false;

      final response = await _refreshDio.post(
        '/api/refreshToken', // ← adjust to your endpoint
        data: {"refreshToken": refreshToken},
      );

      if (response.statusCode == 200) {
        final newAccess = response.data['accessToken'] as String?;
        final newRefresh =
            response.data['refreshToken'] as String?; // if backend rotates

        if (newAccess == null) return false;

        await getIt<TokenStorageService>().saveTokens(
          accessToken: newAccess,
          refreshToken: newRefresh,
        );
        return true;
      }

      return false;
    } catch (e) {
      debugPrint("Refresh token failed: $e");
      return false;
    }
  }
}
