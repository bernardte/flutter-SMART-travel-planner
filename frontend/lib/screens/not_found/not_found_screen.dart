// lib/screens/not_found/not_found_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('404', style: TextStyle(fontSize: 72, fontWeight: FontWeight.bold, color: Colors.grey[300])),
            const SizedBox(height: 8),
            const Text('Page not found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text("We couldn't find what you were looking for.",
                style: TextStyle(color: Colors.grey[500])),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.go('/home'),
              icon: const Icon(Icons.home_outlined),
              label: const Text('Go Home'),
            ),
          ],
        ),
      ),
    );
  }
}
