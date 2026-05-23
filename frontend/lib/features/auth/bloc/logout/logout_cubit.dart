import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/data/repository/auth/logout_repository.dart';
import 'package:frontend/features/auth/bloc/logout/logout_state.dart';
class LogoutCubit extends Cubit<LogoutState> {
  final LogoutRepository repository;

  LogoutCubit(this.repository) : super(LogoutInitial());

  Future<void> logout() async {
    emit(LogoutLoading());

    try {
      final response = await repository.logout();

      if(!response.success){
        emit(LogoutFailure(response.message));
      } else {
        emit(LogoutSuccess("Logout successful")); 
      }

    }catch(error){
      emit(LogoutFailure(error.toString()));
    }
  }
}