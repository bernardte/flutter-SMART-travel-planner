import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load();
  } catch (_) {
    // Allow app startup when .env is missing; API client fallbacks will be used.
  }
  runApp(
    const ProviderScope(
      child: SmartTravelPlannerApp(),
    ),
  );
}
