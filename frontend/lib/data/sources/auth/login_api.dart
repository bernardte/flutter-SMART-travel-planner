import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:frontend/core/config/api_client.dart';
import 'package:frontend/core/helpers/api/api_result.dart';
import 'package:frontend/data/models/auth/login_request_model.dart';

class AuthLoginRemoteSource {
  Future<ApiResultType> login(LoginRequestModel request) async {
    try{
      final response = await ApiClient.dio.post(
        "/api/users/login",
        data: request.toJson(),
      );

      debugPrint("Login API Request: ${request}");
      debugPrint("Login API Response: ${response.data}");

      return ApiResult.success(response.data);
    } on DioException catch (error){
       final message =
          error.response?.data["message"]?.toString() ??
          error.message ??
          "Unknown error";
      print("Login API Error: ${message}");
      return ApiResult.failure(message);
    }
  }
}
