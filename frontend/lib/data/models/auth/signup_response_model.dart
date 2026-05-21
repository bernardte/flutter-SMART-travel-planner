import 'package:frontend/data/models/user/user_model.dart';

class SignupResponse {
  final UserModel? user;
  final bool success;
  final String message;

  SignupResponse({required this.user, required this.success, this.message = ""});

  //? success response
  factory SignupResponse.success(Map<String, dynamic> json) {
    final data = json["data"];

    if (data == null) {
      throw Exception("SignupResponse: data is null");
    }

    return SignupResponse(
      success: json["success"] ?? false,
      message: json["message"] ?? "",
      user: UserModel.fromJson(data),
    );
  }
  //? failure response
  factory SignupResponse.failure(String message) {
    return SignupResponse(success: false, message: message, user: null);
  }
}
