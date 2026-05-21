import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:frontend/core/config/api_client.dart';
import 'package:frontend/core/helpers/api/api_result.dart';
import 'package:frontend/data/models/auth/signup_request_model.dart';

class AuthSignupRemoteSource {
  Future<ApiResultType> signup(
    SignupRequestModel request,
  ) async {
    try {
      final response = await ApiClient.dio.post(
        "/api/users/register-account",
        data: request.toJson(),
      );

      debugPrint("Signup API Response: ${response.data}");

      return ApiResult.success(response.data);
    } on DioException catch (error) {
      final message =
          error.response?.data["message"]?.toString() ??
          error.message ??
          "Unknown error";
      print("Signup API Error: ${message}");
      return ApiResult.failure(message);
    }
  }
}
