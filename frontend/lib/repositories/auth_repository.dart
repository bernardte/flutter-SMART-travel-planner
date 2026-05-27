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
  ///     "refreshToken": "<refresh>"     ← returned in JSON body
  ///   }
  /// }
  Future<UserModel> _extractAndSaveTokens(dynamic responseData) async {
    print('📦 RAW login response: $responseData');
    print('📦 response.runtimeType: ${responseData.runtimeType}');

    // 1. Ensure responseData is a non-null Map
    if (responseData == null) {
      throw Exception('Login response is null');
    }
    final Map<String, dynamic> responseMap;
    if (responseData is Map) {
      // Convert to Map<String, dynamic> safely
      responseMap = Map<String, dynamic>.from(responseData);
    } else {
      throw Exception('Login response is not a Map');
    }

    // 2. Extract the inner 'data' map, or fall back to the whole response
    final dynamic rawData = responseMap['data'];
    Map<String, dynamic> data;
    if (rawData is Map) {
      data = Map<String, dynamic>.from(rawData);
    } else {
      data = responseMap; // use entire response if no 'data' key
    }

    print('📦 data keys: ${data.keys.toList()}');

    final accessToken = data['token'] as String? ?? '';
    final refreshToken = data['refreshToken'] as String?;

    print('🔐 accessToken present: ${accessToken.isNotEmpty}');
    print('🔐 refreshToken present: ${refreshToken != null && refreshToken.isNotEmpty}');
    print('🔐 refreshToken raw value: $refreshToken');

    if (accessToken.isNotEmpty) {
      await SecureStorage.saveAccessToken(accessToken);
      final verified = await SecureStorage.getAccessToken();
      print(verified != null ? '✅ Access token write verified' : '⚠️ Access token write-back failed');
    }

    if (refreshToken != null && refreshToken.isNotEmpty) {
      await SecureStorage.saveRefreshToken(refreshToken);
      final verifiedR = await SecureStorage.getRefreshToken();
      print(verifiedR != null ? '✅ Refresh token saved and verified' : '⚠️ Refresh token write-back FAILED');
    } else {
      print('⚠️ No refresh token in response');
    }

    // Now data is guaranteed a non-null Map<String, dynamic>
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

// FIX: keepAlive: true — same reasoning as dioClientProvider. This provider
// wraps the Dio singleton; if Riverpod recreated it, it would create a new
// AuthRepository pointing at a new (different) Dio instance, breaking
// the interceptor chain and causing duplicate/mismatched state.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  ref.keepAlive();
  return AuthRepository(ref.read(dioClientProvider));
});
