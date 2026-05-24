// lib/widgets/common/main_scaffold.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';

class MainScaffold extends ConsumerWidget {
  final Widget child;
  final bool showBottomNav;

  const MainScaffold({
    super.key,
    required this.child,
    this.showBottomNav = true,
  });

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/dashboard')) return 1;
    if (location.startsWith('/community-guide')) return 2;
    if (location.startsWith('/favourite-post')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final idx = _currentIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: showBottomNav
          ? NavigationBar(
              selectedIndex: idx,
              onDestinationSelected: (i) {
                switch (i) {
                  case 0:
                    context.go('/home');
                    break;
                  case 1:
                    if (authState.isAuthenticated) {
                      context.go('/dashboard');
                    } else {
                      context.go('/auth');
                    }
                    break;
                  case 2:
                    context.go('/community-guide');
                    break;
                  case 3:
                    if (authState.isAuthenticated) {
                      context.go('/favourite-post');
                    } else {
                      context.go('/auth');
                    }
                    break;
                }
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.map_outlined),
                  selectedIcon: Icon(Icons.map),
                  label: 'My Trips',
                ),
                NavigationDestination(
                  icon: Icon(Icons.people_outline),
                  selectedIcon: Icon(Icons.people),
                  label: 'Community',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bookmark_outline),
                  selectedIcon: Icon(Icons.bookmark),
                  label: 'Saved',
                ),
              ],
            )
          : null,
    );
  }
}
