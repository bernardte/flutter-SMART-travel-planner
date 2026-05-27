// lib/repositories/favourite_repository.dart
// Replaces frontend/src/api/favourite.api.ts

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';
import '../core/errors/api_exception.dart';
import '../core/utils/api_constants.dart';
import '../models/travel_guide_model.dart';

class FavouriteRepository {
  final Dio _dio;
  FavouriteRepository(this._dio);

  Future<List<TravelGuideModel>> getAllFavourites() async {
    try {
      final res = await _dio.get(ApiConstants.favourites);
      final list = res.data['data'] as List? ?? [];
      return list.map((g) => TravelGuideModel.fromJson(g)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}

final favouriteRepositoryProvider = Provider<FavouriteRepository>((ref) {
  ref.keepAlive();
  return FavouriteRepository(ref.read(dioClientProvider));
});
