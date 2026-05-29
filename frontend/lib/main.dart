import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'app.dart';

void main() {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  // Keep the native splash visible until SplashScreen calls remove()
  FlutterNativeSplash.preserve(widgetsBinding: binding);
  runApp(
    const ProviderScope(
      child: SmartTravelPlannerApp(),
    ),
  );
}
