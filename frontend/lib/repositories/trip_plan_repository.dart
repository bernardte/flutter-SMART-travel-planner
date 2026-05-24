// lib/repositories/trip_plan_repository.dart
// Replaces trip plan API calls from trip.api.ts

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';
import '../core/errors/api_exception.dart';
import '../core/utils/api_constants.dart';
import '../models/comment_model.dart';

class TripPlanRepository {
  final Dio _dio;
  TripPlanRepository(this._dio);

  Future<Map<String, dynamic>?> getTripPlanByItineraryId(
      String itineraryId) async {
    try {
      final res =
          await _dio.get(ApiConstants.tripPlanByItinerary(itineraryId));
      return res.data['data'];
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<Map<String, dynamic>> getTripPlan(String tripPlanId) async {
    try {
      final res = await _dio.get(ApiConstants.tripPlanById(tripPlanId));
      return res.data['data'];
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> createTripPlan({
    required String tripId,
    required String title,
    required String description,
    required String country,
    required String privacy,
    required List<String> tags,
    required List<dynamic> sections,
    File? thumbnailImage,
    void Function(int percent)? onProgress,
  }) async {
    try {
      final formData = FormData.fromMap({
        'tripId': tripId,
        'title': title,
        'description': description,
        'country': country,
        'privacy': privacy,
        'tags': tags.join(','),
        'sections': sections.toString(),
        if (thumbnailImage != null)
          'thumbnailImage': await MultipartFile.fromFile(
            thumbnailImage.path,
            filename: 'thumbnail.jpg',
          ),
      });

      await _dio.post(
        ApiConstants.createTripPlan,
        data: formData,
        options: Options(headers: {'Content-Type': 'multipart/form-data'}),
        onSendProgress: (sent, total) {
          if (total > 0) onProgress?.call((sent * 100 ~/ total));
        },
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> updateTripPlan({
    required String tripPlanId,
    required String title,
    required String description,
    required String country,
    required String privacy,
    required List<String> tags,
    required List<dynamic> sections,
    File? thumbnailImage,
    void Function(int percent)? onProgress,
  }) async {
    try {
      final formData = FormData.fromMap({
        'title': title,
        'description': description,
        'country': country,
        'privacy': privacy,
        'tags': tags.join(','),
        'sections': sections.toString(),
        if (thumbnailImage != null)
          'thumbnailImage': await MultipartFile.fromFile(
            thumbnailImage.path,
            filename: 'thumbnail.jpg',
          ),
      });

      await _dio.put(
        ApiConstants.tripPlanById(tripPlanId),
        data: formData,
        options: Options(headers: {'Content-Type': 'multipart/form-data'}),
        onSendProgress: (sent, total) {
          if (total > 0) onProgress?.call((sent * 100 ~/ total));
        },
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<List<CommentModel>> getComments(String tripPlanId) async {
    try {
      final res =
          await _dio.get(ApiConstants.tripPlanComments(tripPlanId));
      final list = res.data['data'] as List? ?? [];
      return list.map((c) => CommentModel.fromJson(c)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<CommentModel> createComment(
      String tripPlanId, String content) async {
    try {
      final res = await _dio.post(
        ApiConstants.tripPlanComments(tripPlanId),
        data: {'content': content},
      );
      return CommentModel.fromJson(res.data['data']);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> deleteComment(String tripPlanId, String commentId) async {
    try {
      await _dio
          .delete(ApiConstants.tripPlanComment(tripPlanId, commentId));
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<CommentModel> updateComment(
      String tripPlanId, String commentId, String content) async {
    try {
      final res = await _dio.patch(
        ApiConstants.tripPlanComment(tripPlanId, commentId),
        data: {'content': content},
      );
      return CommentModel.fromJson(res.data['data']);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}

final tripPlanRepositoryProvider = Provider<TripPlanRepository>((ref) {
  return TripPlanRepository(ref.read(dioClientProvider));
});
