// lib/models/user_model.dart
// Mirrors the User interface from frontend/src/types/interface.type.ts

class UserModel {
  final String id;
  final String email;
  final String username;
  final String name;
  final String? profilePicture;
  final String? bio;
  final List<String> followers;
  final List<String> following;
  final bool isVerified;

  UserModel({
    required this.id,
    required this.email,
    required this.username,
    required this.name,
    this.profilePicture,
    this.bio,
    required this.followers,
    required this.following,
    this.isVerified = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['_id'] ?? '',
        email: json['email'] ?? '',
        username: json['username'] ?? '',
        name: json['name'] ?? '',
        profilePicture: json['profilePicture'],
        bio: json['bio'],
        followers: List<String>.from(json['followers'] ?? []),
        following: List<String>.from(json['following'] ?? []),
        isVerified: json['isVerified'] ?? false,
      );

  Map<String, dynamic> toJson() => {
        '_id': id,
        'email': email,
        'username': username,
        'name': name,
        'profilePicture': profilePicture,
        'bio': bio,
        'followers': followers,
        'following': following,
        'isVerified': isVerified,
      };
}

class PostUserSummary {
  final String id;
  final String name;
  final String username;
  final String profilePicture;

  PostUserSummary({
    required this.id,
    required this.name,
    required this.username,
    required this.profilePicture,
  });

  factory PostUserSummary.fromJson(Map<String, dynamic> json) =>
      PostUserSummary(
        id: json['_id'] ?? '',
        name: json['name'] ?? '',
        username: json['username'] ?? '',
        profilePicture: json['profilePicture'] ?? '',
      );
}
