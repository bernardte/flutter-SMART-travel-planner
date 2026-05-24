import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers/auth_provider.dart';
import 'screens/landing/landing_screen.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/trip/plan_trip_screen.dart';
import 'screens/trip/view_trip_screen.dart';
import 'screens/trip/edit_trip_screen.dart';
import 'screens/trip_plan/trip_plan_screen.dart';
import 'screens/trip_plan/edit_trip_plan_screen.dart';
import 'screens/trip_plan/view_trip_plan_screen.dart';
import 'screens/community/community_screen.dart';
import 'screens/post/post_screen.dart';
import 'screens/saved/saved_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/not_found/not_found_screen.dart';
import 'widgets/common/main_scaffold.dart';

class SmartTravelPlannerApp extends ConsumerWidget {
  const SmartTravelPlannerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    final router = GoRouter(
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
        final isGoingToProtected = protectedRoutes
            .any((r) => state.matchedLocation.startsWith(r));

        if (isGoingToProtected && !isAuth) {
          return '/auth';
        }
        if (state.matchedLocation == '/auth' && isAuth) {
          return '/dashboard';
        }
        return null;
      },
      routes: [
        // Public routes with bottom nav
        ShellRoute(
          builder: (context, state, child) {
            final showNavRoutes = [
              '/home',
              '/community-guide',
              '/dashboard',
              '/favourite-post',
            ];
            final show = showNavRoutes
                .any((r) => state.matchedLocation.startsWith(r));
            return MainScaffold(showBottomNav: show, child: child);
          },
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const LandingScreen(),
            ),
            GoRoute(
              path: '/community-guide',
              builder: (context, state) => const CommunityScreen(),
            ),
            GoRoute(
              path: '/dashboard',
              builder: (context, state) => const DashboardScreen(),
            ),
            GoRoute(
              path: '/favourite-post',
              builder: (context, state) => const SavedScreen(),
            ),
            GoRoute(
              path: '/post',
              builder: (context, state) => const PostScreen(),
            ),
            GoRoute(
              path: '/profile/:username',
              builder: (context, state) {
                final username = state.pathParameters['username']!;
                return ProfileScreen(username: username);
              },
            ),
          ],
        ),
        // Auth
        GoRoute(
          path: '/auth',
          builder: (context, state) => const AuthScreen(),
        ),
        // Trip planning (full-screen, no bottom nav)
        GoRoute(
          path: '/plan',
          builder: (context, state) => const PlanTripScreen(),
        ),
        GoRoute(
          path: '/trips/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return ViewTripScreen(tripId: id);
          },
        ),
        GoRoute(
          path: '/trips/:id/edit',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return EditTripScreen(tripId: id);
          },
        ),
        GoRoute(
          path: '/create-travel-guide/:tripId',
          builder: (context, state) {
            final tripId = state.pathParameters['tripId']!;
            return TripPlanScreen(tripId: tripId);
          },
        ),
        GoRoute(
          path: '/edit-travel-guide/:tripPlanId',
          builder: (context, state) {
            final tripPlanId = state.pathParameters['tripPlanId']!;
            return EditTripPlanScreen(tripPlanId: tripPlanId);
          },
        ),
        GoRoute(
          path: '/trip-plan/view/:tripPlanId',
          builder: (context, state) {
            final tripPlanId = state.pathParameters['tripPlanId']!;
            return ViewTripPlanScreen(tripPlanId: tripPlanId);
          },
        ),
        // 404
        GoRoute(
          path: '/:path(.*)',
          builder: (context, state) => const NotFoundScreen(),
        ),
      ],
    );

    return MaterialApp.router(
      routerConfig: router,
      title: 'Smart Travel Planner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3B82F6),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1F2937),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B82F6),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}
