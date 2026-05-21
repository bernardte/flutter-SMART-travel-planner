import 'package:frontend/data/repository/auth/login_repository.dart';
import 'package:frontend/data/repository/auth/signup_repository.dart';
import 'package:frontend/data/sources/auth/login_api.dart';
import 'package:frontend/data/sources/auth/signup_api.dart';
import 'package:get_it/get_it.dart';

final getIt = GetIt.instance;

void setupServiceLocator() {
  //! source
  getIt.registerLazySingleton<AuthLoginRemoteSource>(
    () => AuthLoginRemoteSource()
  );

  getIt.registerLazySingleton<AuthSignupRemoteSource>(
    () => AuthSignupRemoteSource()
  );

  //! repository
  getIt.registerLazySingleton<LoginRepository>(
    () => LoginRepository(getIt<AuthLoginRemoteSource>(),)
  );

  getIt.registerLazySingleton<SignupRepository>(
    () => SignupRepository(getIt<AuthSignupRemoteSource>())
  );
}