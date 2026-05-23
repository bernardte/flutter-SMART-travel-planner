import 'package:frontend/data/models/user/user_model.dart';
enum AuthStatus { initializing, authenticated, unauthenticated }

class GlobalState {
  final AuthStatus status;
  final UserModel? user;
  final String? token;

  const GlobalState._({required this.status, this.user, this.token});

  factory GlobalState.initial() =>
      const GlobalState._(status: AuthStatus.initializing);
  factory GlobalState.unauthenticated() =>
      const GlobalState._(status: AuthStatus.unauthenticated);
  factory GlobalState.authenticated({
    required String token,
    required UserModel user,
  }) =>
      GlobalState._(status: AuthStatus.authenticated, token: token, user: user);

  bool get isInitializing => status == AuthStatus.initializing;
  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isUnauthenticated => status == AuthStatus.unauthenticated;
}
