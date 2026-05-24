// lib/repositories/user_repository.dart
// Replaces frontend/src/api/user.api.ts

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';
import '../core/errors/api_exception.dart';
import '../core/utils/api_constants.dart';
import '../models/user_model.dart';

class UserRepository {
  final Dio _dio;
  UserRepository(this._dio);

  Future<UserModel> getUserProfile(String username) async {
    try {
      final res =
          await _dio.get(ApiConstants.getUserProfile(username));
      return UserModel.fromJson(res.data['data']);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<List<dynamic>> getUserPublishTravelGuide(String userId) async {
    try {
      final res = await _dio
          .get(ApiConstants.getUserPublishTravelGuide(userId));
      return res.data['data'] as List? ?? [];
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<Map<String, dynamic>> getUserProfileStats(
      String username) async {
    try {
      final res =
          await _dio.get(ApiConstants.getUserProfileStats(username));
      return res.data['data'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> followUnfollowUser(String userId) async {
    try {
      await _dio.patch(ApiConstants.followUnfollowUser(userId));
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<UserModel> updateUserProfile({
    String? username,
    String? bio,
    File? profilePicture,
  }) async {
    try {
      final formData = FormData.fromMap({
        if (username != null) 'username': username,
        if (bio != null) 'bio': bio,
        if (profilePicture != null)
          'profilePicture': await MultipartFile.fromFile(
            profilePicture.path,
            filename: 'profile.jpg',
          ),
      });

      final res = await _dio.patch(
        ApiConstants.updateProfile,
        data: formData,
        options: Options(headers: {'Content-Type': 'multipart/form-data'}),
      );
      return UserModel.fromJson(res.data['data']);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.read(dioClientProvider));
});
