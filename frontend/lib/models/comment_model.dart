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

  factory CommentModel.fromJson(Map<String, dynamic> json) => CommentModel(
        id: json['_id'],
        user: UserModel.fromJson(json['user'] ?? {}),
        content: json['content'] ?? '',
        createdAt: json['createdAt'] ?? '',
      );
}
