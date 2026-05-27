class UserModel {
  final String id;
  final String username;
  final String name;
  final String email;
  final String profilePicture;
  final String token;
   final String? refreshToken;

  UserModel({
    required this.id,
    required this.username,
    required this.name,
    required this.email,
    required this.profilePicture,
    required this.token,
    this.refreshToken,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json["_id"],
      username: json["username"],
      name: json["name"],
      email: json["email"],
      profilePicture: json["profilePicture"] ?? "",
      token: json["token"] ?? "",
      refreshToken: json["refreshToken"],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "_id": id,
      "username": username,
      "name": name,
      "email": email,
      "profilePicture": profilePicture,
      "token": token,
    };
  }
}
