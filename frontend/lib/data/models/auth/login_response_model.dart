import 'package:frontend/data/models/user/user_model.dart';

class LoginResponse {
  final UserModel user;
  final bool success;
  final String message;

  LoginResponse({ required this.user, required this.success, this.message = "" });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    final data = json["data"];
    
    if(data == null){
      throw Exception("LoginResponse: data is null");
    }

    return LoginResponse(
      success: json["success"] ?? false,
      message: json["message"] ?? "",
      user: UserModel.fromJson(data),
    );
  }
}
