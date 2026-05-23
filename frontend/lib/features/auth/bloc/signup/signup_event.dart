abstract class SignupEvent {}
class SignupSubmittedEvent extends SignupEvent {
  final String name;
  final String username;
  final String email;
  final String password;

  SignupSubmittedEvent({
    required this.name,
    required this.username,
    required this.email,
    required this.password
  });
}