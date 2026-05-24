// lib/providers/trip_provider.dart
// Replaces frontend/src/stores/useTripStore.ts

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/trip_model.dart';
import '../repositories/trip_repository.dart';

class TripState {
  final List<TripModel> trips;
  final bool isLoading;
  final String? error;

  const TripState({
    this.trips = const [],
    this.isLoading = false,
    this.error,
  });

  TripState copyWith({
    List<TripModel>? trips,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      TripState(
        trips: trips ?? this.trips,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : error ?? this.error,
      );
}

class TripNotifier extends StateNotifier<TripState> {
  final TripRepository _repo;
  TripNotifier(this._repo) : super(const TripState());

  Future<void> fetchMyTrips() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final trips = await _repo.getMyTrips();
      state = TripState(trips: trips);
    } catch (e) {
      state = TripState(error: e.toString());
    }
  }

  Future<bool> saveTrip({
    required String country,
    required String startDate,
    required String endDate,
    required List<DayModel> days,
  }) async {
    try {
      await _repo.saveTrip(
        country: country,
        startDate: startDate,
        endDate: endDate,
        days: days,
      );
      await fetchMyTrips();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> deleteTrip(String id) async {
    try {
      await _repo.deleteTrip(id);
      state = state.copyWith(
        trips: state.trips.where((t) => t.id != id).toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}

final tripProvider =
    StateNotifierProvider<TripNotifier, TripState>((ref) {
  return TripNotifier(ref.read(tripRepositoryProvider));
});
