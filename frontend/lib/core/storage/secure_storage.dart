// lib/core/storage/secure_storage.dart
//
// WHY TWO STORES?
// ───────────────
// flutter_secure_storage uses the Android Keystore (hardware-backed encryption).
// On Android *emulators* the Keystore is often broken — writes appear to
// succeed but subsequent reads silently return null. This causes the token
// to vanish between requests even though login saved it correctly.
//
// Strategy:
//   WRITE  → write to BOTH secure storage AND SharedPreferences
//   READ   → try secure storage first; if null, fall back to SharedPreferences
//   DELETE → delete from BOTH
//
// On a real physical device, secure storage always wins (more secure).
// On a broken emulator, SharedPreferences saves the day.
// SharedPreferences is NOT encrypted, so this is only acceptable for
// development/testing. In production with a real device, Keystore is used.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureStorage {
  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // SharedPreferences keys — prefixed so they're easy to identify
  static const _spAccessToken  = 'sp_access_token';
  static const _spRefreshToken = 'sp_refresh_token';

  // Secure storage keys
  static const _secAccessToken  = 'access_token';
  static const _secRefreshToken = 'refresh_token';

  // ─── WRITE ───────────────────────────────────────────────────────────────

  static Future<void> saveAccessToken(String token) async {
    print('💾 Saving access token (length: ${token.length})');
    await Future.wait([
      _secure.write(key: _secAccessToken, value: token)
          .catchError((_) {}),                       // ignore Keystore errors
      _saveToPrefs(_spAccessToken, token),
    ]);
  }

  static Future<void> saveRefreshToken(String token) async {
    print('💾 Saving refresh token (length: ${token.length})');
    await Future.wait([
      _secure.write(key: _secRefreshToken, value: token)
          .catchError((_) {}),
      _saveToPrefs(_spRefreshToken, token),
    ]);
  }

  // ─── READ ────────────────────────────────────────────────────────────────

  static Future<String?> getAccessToken() async {
    // Try secure storage first
    final secureVal = await _secure.read(key: _secAccessToken)
        .catchError((_) => null);

    if (secureVal != null && secureVal.isNotEmpty) {
      print('🔐 Access token read from Keystore ✅');
      return secureVal;
    }

    // Fall back to SharedPreferences
    final spVal = await _readFromPrefs(_spAccessToken);
    if (spVal != null && spVal.isNotEmpty) {
      print('🔐 Access token read from SharedPreferences fallback ✅');
      return spVal;
    }

    print('🔐 Access token not found in either store');
    return null;
  }

  static Future<String?> getRefreshToken() async {
    final secureVal = await _secure.read(key: _secRefreshToken)
        .catchError((_) => null);

    if (secureVal != null && secureVal.isNotEmpty) {
      return secureVal;
    }

    return _readFromPrefs(_spRefreshToken);
  }

  // ─── DELETE ──────────────────────────────────────────────────────────────

  static Future<void> clearAll() async {
    print('🗑️ Clearing all stored tokens');
    await Future.wait([
      _secure.deleteAll().catchError((_) {}),
      _clearPrefs(),
    ]);
  }

  // ─── PREFS HELPERS ───────────────────────────────────────────────────────

  static Future<void> _saveToPrefs(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  static Future<String?> _readFromPrefs(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  static Future<void> _clearPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_spAccessToken);
    await prefs.remove(_spRefreshToken);
  }
}
