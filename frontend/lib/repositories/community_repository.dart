// lib/repositories/community_repository.dart
// Replaces frontend/src/api/travel_guide.api.ts

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';
import '../core/errors/api_exception.dart';
import '../core/utils/api_constants.dart';
import '../models/travel_guide_model.dart';

class CommunityRepository {
  final Dio _dio;
  CommunityRepository(this._dio);

  Future<List<TravelGuideModel>> getAllPublicPosts() async {
    try {
      final res = await _dio.get(ApiConstants.publicPosts);
      final list = res.data['data'] as List? ?? [];
      print("list received from Backend: $list");
      final travelList = list.map((g) => TravelGuideModel.fromJson(g)).toList();
      print("Converted to dart list: $travelList"); 
      return travelList;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<List<TravelGuideModel>> getRecommendedGuides() async {
    try {
      final res = await _dio.get(ApiConstants.recommendedGuides);
      final list = res.data['data'] as List? ?? [];
      return list.map((g) => TravelGuideModel.fromJson(g)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<List<TravelGuideModel>> getFollowersGuides() async {
    try {
      final res = await _dio.get(ApiConstants.followersGuides);
      final list = res.data['data'] as List? ?? [];
      return list.map((g) => TravelGuideModel.fromJson(g)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<List<dynamic>> getItinerariesByAuthor(String authorId) async {
    try {
      final res =
          await _dio.get(ApiConstants.itinerariesByAuthor(authorId));
      return res.data['data'] as List? ?? [];
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<TravelGuideModel> createPost({
    required String title,
    required String description,
    required String country,
    required String privacy,
    required List<String> tags,
    required String itineraryId,
    File? image,
    void Function(int percent)? onProgress,
  }) async {
    try {
      final formData = FormData.fromMap({
        'title': title,
        'description': description,
        'country': country,
        'privacy': privacy,
        'tags': tags.join(','),
        'itineraryId': itineraryId,
        if (image != null)
          'image': await MultipartFile.fromFile(
            image.path,
            filename: 'post_image.jpg',
          ),
      });

      final res = await _dio.post(
        ApiConstants.createPost,
        data: formData,
        options: Options(headers: {'Content-Type': 'multipart/form-data'}),
        onSendProgress: (sent, total) {
          if (total > 0) onProgress?.call((sent * 100 ~/ total));
        },
      );
      return TravelGuideModel.fromJson(res.data['data']);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<TravelGuideModel> editPost({
    required String postId,
    required String title,
    required String description,
    required String country,
    required String privacy,
    required List<String> tags,
    File? image,
    void Function(int percent)? onProgress,
  }) async {
    try {
      final formData = FormData.fromMap({
        'title': title,
        'description': description,
        'country': country,
        'privacy': privacy,
        'tags': tags.join(','),
        if (image != null)
          'image': await MultipartFile.fromFile(
            image.path,
            filename: 'post_image.jpg',
          ),
      });

      final res = await _dio.patch(
        ApiConstants.editPost(postId),
        data: formData,
        options: Options(headers: {'Content-Type': 'multipart/form-data'}),
        onSendProgress: (sent, total) {
          if (total > 0) onProgress?.call((sent * 100 ~/ total));
        },
      );
      return TravelGuideModel.fromJson(res.data['data']);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<Map<String, dynamic>> likeUnlikePost(String postId) async {
    try {
      final res = await _dio.post(ApiConstants.likeUnlikePost(postId));
      return res.data['data'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<Map<String, dynamic>> savePost(String postId) async {
    try {
      final res = await _dio.post(ApiConstants.savePost(postId));
      return res.data['data'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> deletePost(String postId) async {
    try {
      await _dio.delete(ApiConstants.deletePost(postId));
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}

final communityRepositoryProvider = Provider<CommunityRepository>((ref) {
  ref.keepAlive();
  return CommunityRepository(ref.read(dioClientProvider));
});
