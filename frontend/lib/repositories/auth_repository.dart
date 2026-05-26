// lib/repositories/auth_repository.dart

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';
import '../core/storage/secure_storage.dart';
import '../core/errors/api_exception.dart';
import '../core/utils/api_constants.dart';
import '../models/user_model.dart';

class AuthRepository {
  final Dio _dio;
  AuthRepository(this._dio);

  Future<UserModel> login(String email, String password) async {
    try {
      final res = await _dio.post(ApiConstants.login, data: {
        'email': email,
        'password': password,
      });
      return _extractAndSaveTokens(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<UserModel> register({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      final res = await _dio.post(ApiConstants.register, data: {
        'name': name,
        'username': username,
        'email': email,
        'password': password,
      });
      return _extractAndSaveTokens(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Extracts tokens from the response and saves them to secure storage.
  ///
  /// Backend login/register response shape:
  /// {
  ///   "success": true,
  ///   "data": {
  ///     "_id": "...",
  ///     "username": "...",
  ///     "token": "<accessToken>",       ← key is "token", NOT "accessToken"
  ///     "refreshToken": "<refresh>"     ← added to backend response (see backend fix)
  ///   }
  /// }
  Future<UserModel> _extractAndSaveTokens(dynamic responseData) async {
    final data = responseData['data'] ?? responseData;

    // Access token: backend names this field "token"
    final accessToken = data['token'] as String? ?? '';
    // Refresh token: returned in JSON body after applying the backend patch
    final refreshToken = data['refreshToken'] as String?;

    print('🔐 accessToken present: ${accessToken.isNotEmpty}');
    print('🔐 refreshToken present: ${refreshToken != null && refreshToken.isNotEmpty}');

    if (accessToken.isNotEmpty) {
      await SecureStorage.saveAccessToken(accessToken);
    } else {
      print('⚠️ No access token in response — check backend is returning "token" field');
    }

    if (refreshToken != null && refreshToken.isNotEmpty) {
      await SecureStorage.saveRefreshToken(refreshToken);
    }

    return UserModel.fromJson(data);
  }

  Future<void> logout() async {
    try {
      await _dio.post(ApiConstants.logout);
    } catch (_) {
      // Even if server call fails, clear local tokens
    } finally {
      await SecureStorage.clearAll();
    }
  }

  Future<UserModel> getLoginUser() async {
    try {
      final res = await _dio.get(ApiConstants.getLoginUser);
      final data = res.data['data'] ?? res.data;
      final userData = data['user'] ?? data;
      return UserModel.fromJson(userData);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.read(dioClientProvider));
});
