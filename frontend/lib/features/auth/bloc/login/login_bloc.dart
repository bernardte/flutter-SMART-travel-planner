import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/config/service_locator.dart';
import 'package:frontend/core/config/token_service.dart';
import 'package:frontend/core/config/user_storage_service.dart';
import 'package:frontend/data/repository/auth/login_repository.dart';
import 'package:frontend/features/auth/bloc/login/login_event.dart';
import 'package:frontend/features/auth/bloc/login/login_state.dart';

class LoginBloc extends Bloc<LoginSubmittedEvent, LoginState> {
  final LoginRepository repository;

  LoginBloc(this.repository) : super(LoginInitial()) {
    on<LoginSubmittedEvent>(_onLoginSubmit);
  }

  Future<void> _onLoginSubmit(
    LoginSubmittedEvent event, Emitter<LoginState> emit) async {
    if (event.email.isEmpty || event.password.isEmpty) {
      emit(LoginFailure("Please fill in all requried fields"));
      return;
    }
    
    emit(LoginLoading());

    try {
      final response = await repository.login(event.email, event.password);

      if (response.success) {
        final user = response.user;
        final token = user?.token;

        if (token != null) {
         await getIt<TokenStorageService>().saveToken(token);
        }

        if (user != null) {
          await getIt<UserStorageService>().saveUser(user);
          emit(LoginSuccess(user: user, message: response.message));
        } else {
          emit(LoginFailure("Login succeeded but user data is missing"));
        }
      } else {
        emit(LoginFailure(response.message));
      }
    } catch (e) {
      emit(LoginFailure(e.toString()));
    }
  }
}