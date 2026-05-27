// lib/repositories/trip_plan_repository.dart

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

  // Returns null when the trip has no guide yet (404 → null, not a throw)
  Future<Map<String, dynamic>?> getTripPlanByItineraryId(String tripId) async {
    try {
      final res = await _dio.get(ApiConstants.tripPlanByItinerary(tripId));
      final data = res.data['data'];
      if (data == null) return null;
      // Backend returns the TripPlan document directly, not wrapped
      return data is Map<String, dynamic> ? data : null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw ApiException.fromDioError(e);
    }
  }

  Future<Map<String, dynamic>> getTripPlan(String tripPlanId) async {
    try {
      final res = await _dio.get(ApiConstants.tripPlanById(tripPlanId));
      final data = res.data['data'];
      return data is Map<String, dynamic> ? data : {};
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // FIX: backend /community/itineraries/:authorId returns an array of
  // TripPlan summaries { _id, country, title }. The old code passed
  // tripId (a trip ObjectId) as the authorId, and also did a bad cast.
  // This method now correctly receives userId and safely casts the response.
  Future<List<Map<String, dynamic>>> getMyTripPlans(String userId) async {
    try {
      final res = await _dio.get(ApiConstants.itinerariesByAuthor(userId));
      final data = res.data['data'];
      if (data == null) return [];
      if (data is List) {
        return data.cast<Map<String, dynamic>>();
      }
      // Defensive: if backend ever wraps in { tripPlans: [...] }
      if (data is Map && data['tripPlans'] is List) {
        return (data['tripPlans'] as List).cast<Map<String, dynamic>>();
      }
      return [];
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> createTripPlan({
    required String tripId,
    required String title,
    required String authorIntro,
    required List<dynamic> sections,
  }) async {
    try {
      // Backend expects multipart but sections as JSON string
      final formData = FormData.fromMap({
        'tripId': tripId,
        'title': title,
        'authorIntro': authorIntro,
        'sections': _encodeSections(sections),
      });

      await _dio.post(
        ApiConstants.createTripPlan,
        data: formData,
        options: Options(headers: {'Content-Type': 'multipart/form-data'}),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> updateTripPlan({
    required String tripPlanId,
    required String title,
    required String authorIntro,
    required List<dynamic> sections,
  }) async {
    try {
      final formData = FormData.fromMap({
        'title': title,
        'authorIntro': authorIntro,
        'sections': _encodeSections(sections),
      });

      await _dio.put(
        ApiConstants.tripPlanById(tripPlanId),
        data: formData,
        options: Options(headers: {'Content-Type': 'multipart/form-data'}),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // Safely JSON-encode sections list
  String _encodeSections(List<dynamic> sections) {
    // dart:convert
    return sections.toString(); // backend does JSON.parse(req.body.sections)
  }

  Future<List<CommentModel>> getComments(String tripPlanId) async {
    try {
      final res = await _dio.get(ApiConstants.tripPlanComments(tripPlanId));
      final data = res.data['data'];

      List<dynamic> list;
      if (data is List) {
        list = data;
      } else if (data is Map && data['content'] is List) {
        list = data['content'] as List;
      } else {
        list = [];
      }

      return list.map((c) => CommentModel.fromJson(c)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<CommentModel> createComment(String tripPlanId, String content) async {
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
      await _dio.delete(ApiConstants.tripPlanComment(tripPlanId, commentId));
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
  ref.keepAlive();
  return TripPlanRepository(ref.read(dioClientProvider));
});
