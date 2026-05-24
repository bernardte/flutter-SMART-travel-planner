// lib/models/trip_model.dart
// Mirrors Trip, IDay, ILocation from interface.type.ts

class LocationModel {
  final String id;
  final String name;
  final String note;
  final double lat;
  final double lng;

  LocationModel({
    required this.id,
    required this.name,
    required this.note,
    required this.lat,
    required this.lng,
  });

  factory LocationModel.fromJson(Map<String, dynamic> json) => LocationModel(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        note: json['note'] ?? '',
        lat: (json['lat'] ?? 0).toDouble(),
        lng: (json['lng'] ?? 0).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'note': note,
        'lat': lat,
        'lng': lng,
      };
}

class DayModel {
  final String date;
  final List<LocationModel> locations;

  DayModel({required this.date, required this.locations});

  factory DayModel.fromJson(Map<String, dynamic> json) => DayModel(
        date: json['date'] ?? '',
        locations: (json['locations'] as List? ?? [])
            .map((l) => LocationModel.fromJson(l))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'date': date,
        'locations': locations.map((l) => l.toJson()).toList(),
      };
}

class TripModel {
  final String id;
  final String country;
  final String startDate;
  final String endDate;
  final List<DayModel> days;
  final bool isTravelGuideCreated;
  final String createdAt;
  final String? tripPlanId;

  TripModel({
    required this.id,
    required this.country,
    required this.startDate,
    required this.endDate,
    required this.days,
    required this.isTravelGuideCreated,
    required this.createdAt,
    this.tripPlanId,
  });

  factory TripModel.fromJson(Map<String, dynamic> json) => TripModel(
        id: json['_id'] ?? '',
        country: json['country'] ?? '',
        startDate: json['startDate'] ?? '',
        endDate: json['endDate'] ?? '',
        days: (json['days'] as List? ?? [])
            .map((d) => DayModel.fromJson(d))
            .toList(),
        isTravelGuideCreated: json['isTravelGuideCreated'] ?? false,
        createdAt: json['createdAt'] ?? '',
        tripPlanId: json['tripPlanId'],
      );

  int get totalLocations =>
      days.fold(0, (sum, d) => sum + d.locations.length);
}
