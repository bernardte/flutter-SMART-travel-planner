// lib/models/comment_model.dart
import 'user_model.dart';

class CommentModel {
  final String? id;
  final UserModel user;
  final String content;
  final String createdAt;

  CommentModel({
    this.id,
    required this.user,
    required this.content,
    required this.createdAt,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    // BUG FIX: json['user'] may be an unpopulated MongoDB ObjectId String.
    // Calling UserModel.fromJson(String) throws
    // "type 'String' is not a subtype of type 'Map<String, dynamic>'".
    // Fall back to an anonymous placeholder when the user isn't populated.
    final rawUser = json['user'];
    final user = rawUser is Map
        ? UserModel.fromJson(Map<String, dynamic>.from(rawUser))
        : UserModel(
            id: rawUser?.toString() ?? '',
            email: '',
            username: 'unknown',
            name: 'Unknown User',
            followers: [],
            following: [],
          );

    return CommentModel(
      id: json['_id'],
      user: user,
      content: json['content'] ?? '',
      createdAt: json['createdAt'] ?? '',
    );
  }
}
