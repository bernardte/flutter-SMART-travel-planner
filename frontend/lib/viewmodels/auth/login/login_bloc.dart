import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/data/repository/auth/login_repository.dart';
import 'package:frontend/viewmodels/auth/login/login_event.dart';
import 'package:frontend/viewmodels/auth/login/login_state.dart';

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
        emit(LoginSuccess(user: response.user, message: response.message));
      } else {
        emit(LoginFailure(response.message));
      }
    } catch (e) {
      emit(LoginFailure(e.toString()));
    }
  }
}