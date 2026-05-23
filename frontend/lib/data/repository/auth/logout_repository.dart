import 'package:frontend/data/models/auth/logout_response_model.dart';
import 'package:frontend/data/sources/auth/logout_api.dart';

class LogoutRepository {
  final AuthLogoutRemoteSource remoteSource;

  LogoutRepository(this.remoteSource);

  Future<LogoutResponse> logout() async {
    try {
      final response = await remoteSource.logout();
      
      return LogoutResponse.fromJson(response.data!);
    } catch (error) {
      throw Exception(error.toString());
    }
  }
}
