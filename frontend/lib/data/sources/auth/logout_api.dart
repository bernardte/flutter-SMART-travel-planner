import 'package:dio/dio.dart';
import 'package:frontend/core/config/api_client.dart';
import 'package:frontend/core/helpers/api/api_result.dart';

class AuthLogoutRemoteSource {
  Future<ApiResultType> logout() async {
    try {
      final response = await ApiClient.dio.post(
        "/api/users/logout",
        options: Options(extra: {"skipAuth": true}),
      );

      return ApiResult.success(response.data);
    } on DioException catch (error) {
      final message =
          error.response?.data["message"]?.toString() ??
          error.message ??
          "Unknown error";
      print("Logout API Error: ${message}");
      return ApiResult.failure(message);
    }
  }
}
