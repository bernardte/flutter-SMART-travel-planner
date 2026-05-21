import 'package:frontend/data/repository/auth/login_repository.dart';
import 'package:frontend/data/sources/auth/login_api.dart';
import 'package:get_it/get_it.dart';

final getIt = GetIt.instance;


void setupServiceLocator() {
  //! source
  getIt.registerLazySingleton<AuthRemoteSource>(
    () => AuthRemoteSource()
  );

  //! repository
  getIt.registerLazySingleton<LoginRepository>(
    () => LoginRepository(getIt<AuthRemoteSource>(),)
  );
}