import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/landing/landing_screen.dart';
import '../screens/auth/auth_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/community/community_screen.dart';
import '../screens/post/post_screen.dart';
import '../screens/saved/saved_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/not_found/not_found_screen.dart';
import '../screens/trip/plan_trip_screen.dart';
import '../screens/trip/view_trip_screen.dart';
import '../screens/trip/edit_trip_screen.dart';
import '../screens/trip_plan/trip_plan_screen.dart';
import '../screens/trip_plan/edit_trip_plan_screen.dart';
import '../screens/trip_plan/view_trip_plan_screen.dart';
import '../widgets/common/main_scaffold.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/home',
  redirect: (context, state) {
    // ⚠️ 这里先不放 Riverpod auth（避免 rebuild router）
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

        final show =
            showNavRoutes.any((r) => state.matchedLocation.startsWith(r));

        return MainScaffold(
          showBottomNav: show,
          child: child,
        );
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
    GoRoute(
      path: '/auth',
      builder: (context, state) => const AuthScreen(),
    ),
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
    GoRoute(
      path: '/:path(.*)',
      builder: (context, state) => const NotFoundScreen(),
    ),
  ],
);
