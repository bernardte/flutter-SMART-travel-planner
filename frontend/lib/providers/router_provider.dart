import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'auth_provider.dart';
// screens
import '../screens/landing/landing_screen.dart';
import '../screens/auth/auth_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/not_found/not_found_screen.dart';
import '../widgets/common/main_scaffold.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/home',
    redirect: (context, state) {
      final isAuth = authState.isAuthenticated;

      final protectedRoutes = [
        '/dashboard',
        '/plan',
        '/profile',
        '/favourite-post',
        '/post',
      ];

      final isProtected = protectedRoutes.any(
        (r) => state.matchedLocation.startsWith(r),
      );

      if (isProtected && !isAuth) return '/auth';

      if (state.matchedLocation == '/auth' && isAuth) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          final showNavRoutes = [
            '/home',
            '/community-guide',
            '/dashboard',
            '/favourite-post',
          ];

          final show = showNavRoutes.any(
            (r) => state.matchedLocation.startsWith(r),
          );

          return MainScaffold(showBottomNav: show, child: child);
        },
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const LandingScreen(),
          ),
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/:path(.*)',
        builder: (context, state) => const NotFoundScreen(),
      ),
    ],
  );
});
