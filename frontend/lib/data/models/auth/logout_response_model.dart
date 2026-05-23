class LogoutResponse {
  final String message;
  final bool success;
  final dynamic data;

  LogoutResponse({ this.message = "" , required this.success, this.data  });

  factory LogoutResponse.fromJson(Map<String, dynamic> json){
    return LogoutResponse (success: json["success"], message: json["message"], data: json["data"]);
  }

}