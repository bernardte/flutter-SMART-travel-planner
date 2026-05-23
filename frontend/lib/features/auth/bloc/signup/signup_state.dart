import 'package:frontend/data/models/user/user_model.dart';

abstract class SignupState {}

class SignupInitial extends SignupState {}

class SignupLoading extends SignupState {}

class SignupSuccess extends SignupState {
  final String message;
  final UserModel user;

  SignupSuccess({required this.user, this.message = ""});
}

class SignupFailure extends SignupState {
  final String errorMessage;

  SignupFailure(this.errorMessage);
}
