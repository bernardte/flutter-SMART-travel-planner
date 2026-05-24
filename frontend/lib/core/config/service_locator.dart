import 'package:frontend/core/config/token_service.dart';
import 'package:frontend/core/config/user_storage_service.dart';
import 'package:frontend/data/repository/auth/login_repository.dart';
import 'package:frontend/data/repository/auth/logout_repository.dart';
import 'package:frontend/data/repository/auth/signup_repository.dart';
import 'package:frontend/data/repository/user/user_repository.dart';
import 'package:frontend/data/sources/auth/login_api.dart';
import 'package:frontend/data/sources/auth/logout_api.dart';
import 'package:frontend/data/sources/auth/signup_api.dart';
import 'package:frontend/data/sources/user/get_login_user_api.dart';
import 'package:get_it/get_it.dart';

final getIt = GetIt.instance;

void setupServiceLocator() {
  //! service
  getIt.registerLazySingleton<TokenStorageService>(() => TokenStorageService());
  getIt.registerLazySingleton<UserStorageService>(() => UserStorageService());

  //! source
  getIt.registerLazySingleton<AuthLoginRemoteSource>(
    () => AuthLoginRemoteSource(),
  );

  getIt.registerLazySingleton<AuthSignupRemoteSource>(
    () => AuthSignupRemoteSource(),
  );

  getIt.registerLazySingleton<AuthLogoutRemoteSource>(
    () => AuthLogoutRemoteSource(),
  );

  getIt.registerLazySingleton<GetLoginUserApiSource>(
    () => GetLoginUserApiSource(),
  );

  //! repository
  getIt.registerLazySingleton<LoginRepository>(
    () => LoginRepository(getIt<AuthLoginRemoteSource>()),
  );

  getIt.registerLazySingleton<SignupRepository>(
    () => SignupRepository(getIt<AuthSignupRemoteSource>()),
  );

  getIt.registerLazySingleton<LogoutRepository>(
    () => LogoutRepository(getIt<AuthLogoutRemoteSource>()),
  );

  getIt.registerLazySingleton<UserRepository>(
    () => UserRepository(getIt<GetLoginUserApiSource>()),
  );
}
