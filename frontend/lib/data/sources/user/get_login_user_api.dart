import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:frontend/core/config/api_client.dart';
import 'package:frontend/core/helpers/api/api_result.dart';

class GetLoginUserApiSource {
  Future<ApiResultType> getLoginUser() async {
    try {
      final response = await ApiClient.dio.get("/api/users/get-login-user");
      debugPrint("Get Login User API Response: ${response}");

      return ApiResult.success(response.data);
    }on DioException catch (error){
       final message =
          error.response?.data["message"]?.toString() ??
          error.message ??
          "Unknown error";
      debugPrint("Get Login User API Error: ${error}");
      return ApiResult.failure(message);
    }
  }
}