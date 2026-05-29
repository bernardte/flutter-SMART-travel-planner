// lib/core/utils/snackbar.dart
//
// Drop-in replacement for Fluttertoast that uses Flutter's built-in
// ScaffoldMessenger — no third-party package, no Kotlin issues.
//
// Usage (same shape as before):
//   AppSnackbar.show(context, 'Trip saved! 🎉');
//   AppSnackbar.show(context, 'Failed', isError: true);

import 'package:flutter/material.dart';

class AppSnackbar {
  AppSnackbar._();

  static void show(
    BuildContext context,
    String message, {
    bool isError = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    // Guard: don't show if the widget is gone
    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(color: Colors.white)),
          backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          duration: duration,
        ),
      );
  }

  static void error(BuildContext context, String message) =>
      show(context, message, isError: true);

  static void success(BuildContext context, String message) =>
      show(context, message);
}
