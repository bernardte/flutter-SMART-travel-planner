// lib/repositories/trip_repository.dart
// Replaces frontend/src/api/trip.api.ts

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';
import '../core/errors/api_exception.dart';
import '../core/utils/api_constants.dart';
import '../models/trip_model.dart';

class TripRepository {
  final Dio _dio;
  TripRepository(this._dio);

  Future<List<TripModel>> getMyTrips() async {
    try {
      final res = await _dio.get(ApiConstants.myTrips);
      final list = res.data['data']['trips'] as List? ?? [];
      return list.map((t) => TripModel.fromJson(t)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<List<dynamic>> getPopularDestinations() async {
    try {
      final res = await _dio.get(ApiConstants.popularDestination);
      return res.data['data'] as List? ?? [];
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<TripModel> getTripById(String id) async {
    try {
      final res = await _dio.get(ApiConstants.tripById(id));
      return TripModel.fromJson(res.data['data']['trip']);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> saveTrip({
    required String country,
    required String startDate,
    required String endDate,
    required List<DayModel> days,
  }) async {
    try {
      await _dio.post(ApiConstants.saveTrip, data: {
        'country': country,
        'startDate': startDate,
        'endDate': endDate,
        'days': days.map((d) => d.toJson()).toList(),
      });
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> updateTrip({
    required String id,
    required String country,
    required String startDate,
    required String endDate,
    required List<DayModel> days,
  }) async {
    try {
      await _dio.put(ApiConstants.tripById(id), data: {
        'country': country,
        'startDate': startDate,
        'endDate': endDate,
        'days': days.map((d) => d.toJson()).toList(),
      });
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> deleteTrip(String id) async {
    try {
      await _dio.delete(ApiConstants.tripById(id));
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}

// FIX: keepAlive: true — ensures the TripRepository (and the Dio it holds)
// is never recreated mid-session. Without this, navigating away from
// plan_trip_screen could cause a fresh TripRepository to be built, which
// reads dioClientProvider again — and if that was also being recreated, the
// new Dio's onRequest interceptor would race against the token write,
// producing "Access token not found" on /trips/save.
final tripRepositoryProvider = Provider<TripRepository>((ref) {
  ref.keepAlive();
  return TripRepository(ref.read(dioClientProvider));
});
