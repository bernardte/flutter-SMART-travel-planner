import 'package:frontend/core/config/api_client.dart';
import 'package:frontend/data/models/auth/login_request_model.dart';
import 'package:frontend/data/models/auth/login_response_model.dart';
import 'package:frontend/data/sources/auth/login_api.dart';

class LoginRepository {
  final AuthRemoteSource remoteSource;

  LoginRepository(this.remoteSource);

  Future<LoginResponse> login(String email, String password) async {
    //! create request model for normalized parsing JSON data
    final request = LoginRequestModel(email: email, password: password);
    //! call api and get response data
    final response = await remoteSource.login(request);
    //! return response data as readable object;
    return LoginResponse(
      success: response["success"],
      message: response["message"],
      user: response["user"],
    );
  }
}
