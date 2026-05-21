import 'package:flutter/foundation.dart';
import 'package:frontend/core/config/api_client.dart';
import 'package:frontend/data/models/auth/login_request_model.dart';

class AuthRemoteSource {
  Future<Map<String, dynamic>> login(LoginRequestModel request) async {
    final response = await ApiClient.dio.post(
      "/api/users/login",
      data: request.toJson(),
    );

    debugPrint("Login API Response: ${response.data}");

    return response.data;
  }
}
