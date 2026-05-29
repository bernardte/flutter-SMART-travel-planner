// lib/repositories/trip_plan_repository.dart

import 'dart:convert';
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
    required List<Map<String, dynamic>> sections,
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
        'sections': _encodeSections(_sanitizeSections(sections)),
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

  // ── Encoding ───────────────────────────────────────────────────────────────

  // Encode sections as a valid JSON string so the backend can JSON.parse() it.
  // Dart's toString() produces {key: value} (no quotes on keys) which causes
  // "Expected property name or '}'" on the server.
  String _encodeSections(List<Map<String, dynamic>> sections) =>
      jsonEncode(sections);

  // ── Schema sanitization ────────────────────────────────────────────────────
  // Strips MongoDB metadata and enforces the exact ISections schema so nothing
  // unexpected reaches the backend validators.

  static const _validCategories = {
    'restaurant', 'attraction', 'cafe', 'viewpoint', 'other'
  };
  static const _validListItemTypes = {'text', 'checklist'};

  List<Map<String, dynamic>> _sanitizeSections(List<dynamic> raw) =>
      raw.map((s) {
        final sec = _asMap(s);
        final type =
            sec['type'] == 'tips' ? 'tips' : 'day';
        return <String, dynamic>{
          'id': sec['id']?.toString() ?? '',
          'type': type,
          'title': sec['title']?.toString() ?? '',
          'isOpen': sec['isOpen'] == true,
          // tips field
          'content': sec['content']?.toString() ?? '',
          // day fields
          'notes': sec['notes']?.toString() ?? '',
          'route': _sanitizeRoute(sec['route']),
          'places': _sanitizePlaces(sec['places']),
          'listItems': _sanitizeListItems(sec['listItems']),
        };
      }).toList();

  // IRouteStop: id, name, lat, lng, order
  List<Map<String, dynamic>> _sanitizeRoute(dynamic raw) {
    if (raw is! List) return [];
    return raw.asMap().entries.map((e) {
      final r = _asMap(e.value);
      return <String, dynamic>{
        'id': r['id']?.toString().isNotEmpty == true
            ? r['id'].toString()
            : 'stop_${e.key}',
        'name': r['name']?.toString() ?? '',
        'lat': _toDouble(r['lat']),
        'lng': _toDouble(r['lng']),
        'order': r['order'] is int ? r['order'] as int : e.key,
      };
    }).toList();
  }

  // IPlace: order, name, description, lat, lng, category (enum), address
  List<Map<String, dynamic>> _sanitizePlaces(dynamic raw) {
    if (raw is! List) return [];
    return raw.asMap().entries.map((e) {
      final p = _asMap(e.value);
      final cat = p['category']?.toString() ?? '';
      return <String, dynamic>{
        'order': p['order'] is int ? p['order'] as int : e.key,
        'name': p['name']?.toString() ?? '',
        'description': p['description']?.toString() ?? '',
        'lat': _toDouble(p['lat']),
        'lng': _toDouble(p['lng']),
        'category': _validCategories.contains(cat) ? cat : 'attraction',
        'address': p['address']?.toString() ?? '',
      };
    }).toList();
  }

  // IListItem: order (required), text, type (required enum), checked
  List<Map<String, dynamic>> _sanitizeListItems(dynamic raw) {
    if (raw is! List) return [];
    return raw.asMap().entries.map((e) {
      final item = _asMap(e.value);
      final t = item['type']?.toString() ?? '';
      return <String, dynamic>{
        'order': item['order'] is int ? item['order'] as int : e.key,
        'text': item['text']?.toString() ?? '',
        'type': _validListItemTypes.contains(t) ? t : 'text',
        'checked': item['checked'] == true,
      };
    }).toList();
  }

  static Map<String, dynamic> _asMap(dynamic v) =>
      v is Map<String, dynamic> ? v : Map<String, dynamic>.from(v as Map);

  static double _toDouble(dynamic v) =>
      v is double ? v : (v is num ? v.toDouble() : 0.0);

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
