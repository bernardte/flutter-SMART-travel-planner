// lib/core/errors/api_exception.dart
import 'package:dio/dio.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException({required this.message, this.statusCode});

  factory ApiException.fromDioError(DioException e) {
    final data = e.response?.data;
    String msg = 'Something went wrong. Please try again.';

    if (data is Map && data['message'] != null) {
      msg = data['message'].toString();
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      msg = 'Connection timed out. Check your internet connection.';
    } else if (e.type == DioExceptionType.connectionError) {
      msg = 'Cannot connect to the server. Is the backend running?';
    }

    return ApiException(
      message: msg,
      statusCode: e.response?.statusCode,
    );
  }

  @override
  String toString() => message;
}
