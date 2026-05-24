import 'package:hive/hive.dart';
import 'package:frontend/data/models/user/user_model.dart';

class UserStorageService {
  static const String _boxName = 'userBox';
  static const String _userKey = 'currentUser';

  Future<void> saveUser(UserModel user) async {
    final box = await Hive.openBox(_boxName);

    await box.put(_userKey, user.toJson());
  }

  Future<UserModel?> getUser() async {
    final box = await Hive.openBox(_boxName);

    final data = box.get(_userKey);

    if (data == null) return null;

    return UserModel.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> clearUser() async {
    final box = await Hive.openBox(_boxName);

    await box.delete(_userKey);
  }
}
