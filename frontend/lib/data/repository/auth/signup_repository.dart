import 'package:frontend/data/models/auth/signup_request_model.dart';
import 'package:frontend/data/models/auth/signup_response_model.dart';
import 'package:frontend/data/sources/auth/signup_api.dart';

class SignupRepository {
  final AuthSignupRemoteSource authRemoteSource;

  SignupRepository(this.authRemoteSource);
  Future<SignupResponse> signup (String name, String username, String email, String password) async {
    try{
      final request = SignupRequestModel(name: name, username: username, email: email, password: password);

      final response = await authRemoteSource.signup(request);

      if(!response.isSuccess){
        return SignupResponse.failure(response.error!);
      }

      return SignupResponse.success(response.data!);
    }catch(error){
      throw Exception(error.toString());
    }
  }
}