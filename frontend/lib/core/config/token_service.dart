import 'package:frontend/core/storage/secure_storage.dart';

class TokenStorageService {
  // Delegates entirely to SecureStorage so both the BLoC system
  // and the Riverpod system always use the same token.

  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    await SecureStorage.saveAccessToken(accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await SecureStorage.saveRefreshToken(refreshToken);
    }
  }

  Future<String?> getToken() => SecureStorage.getAccessToken();
  Future<String?> getRefreshToken() => SecureStorage.getRefreshToken();

  Future<void> clearTokens() => SecureStorage.clearAll();

  // backwards compat
  Future<void> saveToken(String token) => saveTokens(accessToken: token);
  Future<void> clearToken() => clearTokens();
}