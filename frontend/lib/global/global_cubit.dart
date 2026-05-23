import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/config/service_locator.dart';
import 'package:frontend/core/config/token_service.dart';
import 'package:frontend/core/config/user_storage_service.dart';
import 'package:frontend/data/repository/auth/logout_repository.dart';
import 'package:frontend/data/repository/user/user_repository.dart';
import 'package:frontend/global/global_state.dart';

class GlobalCubit extends Cubit<GlobalState> {
  final UserRepository userRepository;
  final LogoutRepository logoutRepository;

  GlobalCubit(this.userRepository, this.logoutRepository)
    : super(GlobalState.initial());

  /// Called once at app boot — equivalent to React's useEffect on Context init
  Future<void> initAuth() async {
    final token = await getIt<TokenStorageService>().getToken();

    if (token == null) {
      emit(GlobalState.unauthenticated());
      return;
    }

    // Instantly hydrate from cache (like React Context default value)
    final cachedUser = await getIt<UserStorageService>().getUser();
    if (cachedUser != null) {
      emit(GlobalState.authenticated(token: token, user: cachedUser));
    }
    print("trigger this intiAuth()");
    // Sync fresh data silently in background
    await getUserDetails();
  }

  Future<void> getUserDetails() async {
    try {
      final user = await userRepository.getLoginUser();
      await getIt<UserStorageService>().saveUser(user);
      emit(GlobalState.authenticated(token: user.token, user: user));
    } catch (_) {
      await _clearSession();
      emit(GlobalState.unauthenticated());
    }
  }

  Future<void> logout() async {
    try {
      await logoutRepository.logout();
    } catch (_) {}
    await _clearSession();
    emit(GlobalState.unauthenticated());
  }

  Future<void> _clearSession() async {
    await getIt<TokenStorageService>().clearTokens();
    await getIt<UserStorageService>().clearUser();
  }
}
