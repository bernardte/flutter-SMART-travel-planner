import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/data/repository/auth/signup_repository.dart';
import 'package:frontend/viewmodels/auth/signup/signup_event.dart';
import 'package:frontend/viewmodels/auth/signup/signup_state.dart';

class SignupBloc extends Bloc<SignupEvent, SignupState> {
  final SignupRepository repository;
  SignupBloc(this.repository) : super(SignupInitial()){
    on<SignupSubmittedEvent>(_onSignupSubmit);
  }

  Future<void> _onSignupSubmit(SignupSubmittedEvent event, Emitter<SignupState> emit) async {
    if(event.name.isEmpty || event.email.isEmpty || event.password.isEmpty) {
      emit(SignupFailure("Please fill in all required fields"));
      return;
    }

    emit(SignupLoading());

    try{
      final response = await repository.signup(event.name, event.username, event.email, event.password);

      if(response.success){
        emit(SignupSuccess(user: response.user!, message: response.message));
      }else{
        emit(SignupFailure(response.message));
      }
    }catch(error){
      emit(SignupFailure(error.toString()));
    }

  }
}
