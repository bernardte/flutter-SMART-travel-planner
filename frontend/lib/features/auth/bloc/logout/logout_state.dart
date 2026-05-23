abstract class LogoutState {}

class LogoutInitial extends LogoutState {}

class LogoutLoading extends LogoutState {}

class LogoutSuccess extends LogoutState {
  final String message;

  LogoutSuccess(this.message);
}

class LogoutFailure extends LogoutState {
  final String errorMessage;

  LogoutFailure(this.errorMessage);
}