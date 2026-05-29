// lib/models/travel_guide_model.dart
// Mirrors TravelGuide from interface.type.ts

import 'user_model.dart';

// Returns a PostUserSummary only when [raw] is a populated Map.
// When the API returns an unpopulated ObjectId String, returns null
// instead of throwing "type 'String' is not a subtype of Map<String,dynamic>".
PostUserSummary? _parseAuthor(dynamic raw) {
  if (raw == null || raw is! Map) return null;
  return PostUserSummary.fromJson(Map<String, dynamic>.from(raw));
}

class TravelGuideModel {
  final String id;
  final String title;
  final String description;
  final String country;
  final String thumbnailImage;
  final List<String> imagePreviews;
  final PostUserSummary? author;
  final List<String> tags;
  final List<String> postSavedByUser;
  final List<String> viewBy;
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
    required this.postSavedByUser,
    required this.viewBy,
    required this.likes,
    required this.saves,
    required this.views,
    required this.isLiked,
    required this.isSaved,
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
        postSavedByUser: List<String>.from(json['postSavedByUser'] ?? []),
        // API uses "viewsBy" (plural), model field kept as "viewBy" for compat.
        viewBy: List<String>.from(json['viewBy'] ?? json['viewsBy'] ?? []),
        imagePreviews: List<String>.from(json['imagePreviews'] ?? []),
        // author/authorId may be a populated Map OR an unpopulated ObjectId
        // String. Only parse it when it is actually a Map.
        author: _parseAuthor(json['author'] ?? json['authorId']),
        tags: List<String>.from(json['tags'] ?? []),
        // API returns likes as an ARRAY of user IDs, not a count.
        // Convert to count so the int field stays valid.
        likes: json['likes'] is List
            ? (json['likes'] as List).length
            : (json['likes'] as int? ?? 0),
        saves: json['saves'] ?? 0,
        views: json['views'] ?? 0,
        isLiked: json['isLiked'] ?? false,
        isSaved: json['isSaved'] ?? false,
        privacy: json['privacy'] ?? 'public',
        createdAt: json['createdAt'] ?? '',
        // API returns "itineraryId" as a plain String ObjectId when unpopulated,
        // or "itinerary" as a populated Map. Wrap the bare ID in a minimal map
        // so guide.itinerary?['_id'] always resolves for navigation.
        itinerary: json['itinerary'] is Map
            ? Map<String, dynamic>.from(json['itinerary'] as Map)
            : json['itineraryId'] != null
                ? <String, dynamic>{'_id': json['itineraryId'].toString()}
                : null,
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
        postSavedByUser: postSavedByUser,
        viewBy: viewBy,
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
