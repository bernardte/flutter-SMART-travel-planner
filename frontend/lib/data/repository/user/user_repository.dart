import 'package:frontend/data/models/user/user_model.dart';
import 'package:frontend/data/sources/user/get_login_user_api.dart';

class UserRepository {
  final GetLoginUserApiSource getLoginUserApiSource;

  UserRepository(this.getLoginUserApiSource);

  Future<UserModel> getLoginUser() async {
    try {
      final response = await getLoginUserApiSource.getLoginUser();

      if(!response.isSuccess){
        throw Exception(response.error!);
      }

      return UserModel.fromJson(response.data!["data"]);
    } catch(error){
      throw Exception(error.toString());
    }
  }
}