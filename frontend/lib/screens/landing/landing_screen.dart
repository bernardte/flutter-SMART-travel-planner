// lib/screens/landing/landing_screen.dart
// Replaces frontend/src/pages/landing/LandingPage.tsx

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/trip_repository.dart';
import '../../models/travel_guide_model.dart';

class LandingScreen extends ConsumerStatefulWidget {
  const LandingScreen({super.key});

  @override
  ConsumerState<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends ConsumerState<LandingScreen> {
  List<PopularDestinationModel> _destinations = [];
  bool _loadingDestinations = true;

  @override
  void initState() {
    super.initState();
    _fetchDestinations();
  }

  Future<void> _fetchDestinations() async {
    try {
      final repo = ref.read(tripRepositoryProvider);
      final data = await repo.getPopularDestinations();
      setState(() {
        _destinations =
            data.map((d) => PopularDestinationModel.fromJson(d)).toList();
        _loadingDestinations = false;
      });
    } catch (_) {
      setState(() => _loadingDestinations = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.flight_takeoff,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
            const Text('TravelBuddy',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          if (!authState.isAuthenticated)
            TextButton(
              onPressed: () => context.go('/auth'),
              child: const Text('Login'),
            )
          else
            TextButton.icon(
              onPressed: () =>
                  context.go('/profile/${authState.user!.username}'),
              icon: const Icon(Icons.person_outline, size: 18),
              label: Text('@${authState.user!.username}'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero Section
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFEFF6FF), Colors.white, Color(0xFFF0FDFF)],
                ),
              ),
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  const Text(
                    'Plan Smarter,\nTravel Better',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'AI-powered trip planning that turns your dream destinations into detailed itineraries.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton.icon(
                    onPressed: () => context.go(
                        authState.isAuthenticated ? '/plan' : '/auth'),
                    icon: const Icon(Icons.add),
                    label: Text(authState.isAuthenticated
                        ? 'Plan a New Trip'
                        : 'Get Started Free'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 14),
                    ),
                  ),
                ],
              ),
            ),

            // Features Section
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Everything you need to plan the perfect trip',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.4,
                    children: const [
                      _FeatureCard(
                        icon: Icons.map_outlined,
                        title: 'Smart Itinerary',
                        description: 'Day-by-day planning with map pins',
                        gradient: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
                      ),
                      _FeatureCard(
                        icon: Icons.people_outline,
                        title: 'Community',
                        description: 'Share and discover travel guides',
                        gradient: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                      ),
                      _FeatureCard(
                        icon: Icons.bookmark_border,
                        title: 'Save Guides',
                        description: 'Bookmark your favourite content',
                        gradient: [Color(0xFF10B981), Color(0xFF14B8A6)],
                      ),
                      _FeatureCard(
                        icon: Icons.insights_outlined,
                        title: 'Travel Stats',
                        description: 'Track your adventures',
                        gradient: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Popular Destinations
            if (_destinations.isNotEmpty || _loadingDestinations)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Popular Destinations',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        TextButton(
                          onPressed: () => context.go('/community-guide'),
                          child: const Text('See all →'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_loadingDestinations)
                      const Center(child: CircularProgressIndicator())
                    else
                      SizedBox(
                        height: 200,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _destinations.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 12),
                          itemBuilder: (context, i) {
                            final d = _destinations[i];
                            return _DestinationCard(destination: d);
                          },
                        ),
                      ),
                  ],
                ),
              ),

            // CTA Banner
            Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const Icon(Icons.explore, color: Colors.white, size: 40),
                  const SizedBox(height: 12),
                  const Text(
                    'Ready to explore?',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Join thousands of travellers sharing their adventures',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: Colors.white.withOpacity(0.85)),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.go('/community-guide'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF3B82F6),
                    ),
                    child: const Text('Browse Community Guides'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final List<Color> gradient;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [gradient[0].withOpacity(0.1), gradient[1].withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: gradient[0].withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: gradient[0], size: 24),
          const SizedBox(height: 8),
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          Text(description,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              maxLines: 2),
        ],
      ),
    );
  }
}

class _DestinationCard extends StatelessWidget {
  final PopularDestinationModel destination;

  const _DestinationCard({required this.destination});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 160,
        child: Stack(
          fit: StackFit.expand,
          children: [
            destination.thumbnailImage.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: destination.thumbnailImage,
                    fit: BoxFit.cover,
                  )
                : Container(color: Colors.grey[300]),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Text(
                destination.country,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
