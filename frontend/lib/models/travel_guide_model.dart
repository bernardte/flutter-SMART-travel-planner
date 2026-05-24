// lib/models/travel_guide_model.dart
// Mirrors TravelGuide from interface.type.ts

import 'user_model.dart';

class TravelGuideModel {
  final String id;
  final String title;
  final String description;
  final String country;
  final String thumbnailImage;
  final List<String> imagePreviews;
  final PostUserSummary? author;
  final List<String> tags;
  final int likes;
  final int saves;
  final int views;
  final bool isLiked;
  final bool isSaved;
  final String privacy;
  final String createdAt;
  final Map<String, dynamic>? itinerary;

  TravelGuideModel({
    required this.id,
    required this.title,
    required this.description,
    required this.country,
    required this.thumbnailImage,
    this.imagePreviews = const [],
    this.author,
    required this.tags,
    required this.likes,
    required this.saves,
    required this.views,
    this.isLiked = false,
    this.isSaved = false,
    required this.privacy,
    required this.createdAt,
    this.itinerary,
  });

  factory TravelGuideModel.fromJson(Map<String, dynamic> json) =>
      TravelGuideModel(
        id: json['_id'] ?? '',
        title: json['title'] ?? '',
        description: json['description'] ?? '',
        country: json['country'] ?? '',
        thumbnailImage: json['thumbnailImage'] ?? '',
        imagePreviews: List<String>.from(json['imagePreviews'] ?? []),
        author: json['author'] != null || json['authorId'] != null
            ? PostUserSummary.fromJson(
                json['author'] ?? json['authorId'] ?? {})
            : null,
        tags: List<String>.from(json['tags'] ?? []),
        likes: (json['likes'] is List)
            ? (json['likes'] as List).length
            : (json['likes'] ?? 0),
        saves: json['saves'] ?? 0,
        views: json['views'] ?? 0,
        isLiked: json['isLiked'] ?? false,
        isSaved: json['isSaved'] ?? false,
        privacy: json['privacy'] ?? 'public',
        createdAt: json['createdAt'] ?? '',
        itinerary: json['itinerary'] as Map<String, dynamic>?,
      );

  TravelGuideModel copyWith({
    int? likes,
    int? saves,
    bool? isLiked,
    bool? isSaved,
  }) =>
      TravelGuideModel(
        id: id,
        title: title,
        description: description,
        country: country,
        thumbnailImage: thumbnailImage,
        imagePreviews: imagePreviews,
        author: author,
        tags: tags,
        likes: likes ?? this.likes,
        saves: saves ?? this.saves,
        views: views,
        isLiked: isLiked ?? this.isLiked,
        isSaved: isSaved ?? this.isSaved,
        privacy: privacy,
        createdAt: createdAt,
        itinerary: itinerary,
      );
}

class PopularDestinationModel {
  final String country;
  final String thumbnailImage;
  final String description;
  final String guideId;

  PopularDestinationModel({
    required this.country,
    required this.thumbnailImage,
    required this.description,
    required this.guideId,
  });

  factory PopularDestinationModel.fromJson(Map<String, dynamic> json) {
    final topGuide = json['topGuide'] ?? {};
    return PopularDestinationModel(
      country: json['country'] ?? '',
      thumbnailImage: topGuide['thumbnailImage'] ?? '',
      description: topGuide['description'] ?? '',
      guideId: topGuide['_id'] ?? '',
    );
  }
}
