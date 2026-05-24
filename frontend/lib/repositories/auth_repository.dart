// lib/repositories/auth_repository.dart
// Replaces frontend/src/api/auth.api.ts

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
      final data = res.data['data'] ?? res.data;
      await SecureStorage.saveAccessToken(data['accessToken'] ?? '');
      if (data['refreshToken'] != null) {
        await SecureStorage.saveRefreshToken(data['refreshToken']);
      }
      return UserModel.fromJson(data['user'] ?? data);
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
      final data = res.data['data'] ?? res.data;
      await SecureStorage.saveAccessToken(data['accessToken'] ?? '');
      if (data['refreshToken'] != null) {
        await SecureStorage.saveRefreshToken(data['refreshToken']);
      }
      return UserModel.fromJson(data['user'] ?? data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
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
      return UserModel.fromJson(data['user'] ?? data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.read(dioClientProvider));
});
