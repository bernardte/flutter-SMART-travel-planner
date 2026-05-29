// lib/providers/auth_provider.dart
// Replaces frontend/src/stores/useAuthStore.ts + AuthProvider.tsx

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';
import '../core/storage/secure_storage.dart';

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;

  const AuthState({this.user, this.isLoading = false, this.error});

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    String? error,
    bool clearUser = false,
    bool clearError = false,
  }) =>
      AuthState(
        user: clearUser ? null : user ?? this.user,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : error ?? this.error,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;

  AuthNotifier(this._repo) : super(const AuthState()) {
    _tryRestoreSession();
  }

  /// On app start, check if we have a stored access token and fetch current user
  Future<void> _tryRestoreSession() async {
    final token = await SecureStorage.getAccessToken();
    if (token == null || token.isEmpty) return; // nothing stored, skip silently

    state = state.copyWith(isLoading: true);
    try {
      final user = await _repo.getLoginUser();
      state = AuthState(user: user);
    } catch (e) {
      // ONLY clear tokens on a confirmed 401 — not on network errors,
      // timeouts, server errors, or any other transient failure.
      // If the backend is temporarily unreachable, we must keep the token.
      final msg = e.toString().toLowerCase();
      final isDefinitelyUnauthorized =
          msg.contains('401') || msg.contains('unauthorized');

      if (isDefinitelyUnauthorized) {
        print('🗑️ Session restore: confirmed 401 — clearing tokens');
        await SecureStorage.clearAll();
      } else {
        // Keep the token — the error is transient (network, server, etc.)
        // The user will appear logged out on screen but the token survives.
        print('⚠️ Session restore failed (non-401): $e — keeping token');
      }
      state = const AuthState();
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _repo.login(email, password);
      print("user: $user");
      state = AuthState(user: user);
    } catch (e) {
      state = AuthState(error: e.toString());
      rethrow;
    }
  }

  Future<void> register({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _repo.register(
        name: name,
        username: username,
        email: email,
        password: password,
      );
      state = AuthState(user: user);
    } catch (e) {
      state = AuthState(error: e.toString());
      rethrow;
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState();
  }

  void updateUser(UserModel user) {
    state = state.copyWith(user: user);
  }
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(authRepositoryProvider));
});
