// lib/screens/landing/landing_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/trip_repository.dart';
import '../../models/travel_guide_model.dart';

// ── Shared design tokens (mirrors auth_screen.dart + community_screen.dart) ──
const _kBlue = Color(0xFF3B82F6);
const _kCyan = Color(0xFF06B6D4);
const _kNavy = Color(0xFF1E3A8A);
const _kDark = Color(0xFF1F2937);
const _kBgStart = Color(0xFF0F172A);
const _kBgMid = Color(0xFF1E3A5F);
const _kPageBg = Color(0xFFF4F9FF); // matches CommunityScreen

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
    final repo = ref.read(tripRepositoryProvider);
    try {
      final data = await repo.getPopularDestinations();
      if (!mounted) return;
      setState(() {
        _destinations =
            data.map((d) => PopularDestinationModel.fromJson(d)).toList();
        _loadingDestinations = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingDestinations = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: _kPageBg,
      // ── AppBar — mirrors CommunityScreen style ───────────────────────────
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_kBlue, _kCyan],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.flight_takeoff,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'TravelBuddy',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: _kNavy,
              ),
            ),
          ],
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey[100]),
        ),
        actions: [
          if (!authState.isAuthenticated)
            (Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ElevatedButton(
                onPressed: () => context.go('/auth'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text('Login',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ))
          else
            (SizedBox(
              child: TextButton.icon(
                onPressed: () =>
                    context.push('/profile/${authState.user!.username}'),
                icon: const Icon(Icons.person_outline, size: 23, color: _kBlue),
                label: Text('@${authState.user!.username}',
                    style: const TextStyle(color: _kBlue)),
              ),
            )),
        ],
      ),

      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Hero ─────────────────────────────────────────────────────────
            _HeroSection(authState: authState),

            // ── Stats row ─────────────────────────────────────────────────────
            const _StatsRow(),

            // ── Features ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Everything you need to plan\nthe perfect trip',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _kDark,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.25,
                    children: const [
                      _FeatureCard(
                        icon: Icons.map_outlined,
                        title: 'Smart Itinerary',
                        description: 'Day-by-day planning with map pins',
                        color: _kBlue,
                      ),
                      _FeatureCard(
                        icon: Icons.people_outline,
                        title: 'Community',
                        description: 'Share and discover travel guides',
                        color: Color(0xFF8B5CF6),
                      ),
                      _FeatureCard(
                        icon: Icons.bookmark_border,
                        title: 'Save Guides',
                        description: 'Bookmark your favourite content',
                        color: Color(0xFF10B981),
                      ),
                      _FeatureCard(
                        icon: Icons.insights_outlined,
                        title: 'Travel Stats',
                        description: 'Track your adventures',
                        color: Color(0xFFF59E0B),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Popular Destinations ──────────────────────────────────────────
            if (_destinations.isNotEmpty || _loadingDestinations)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Popular Destinations',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _kDark,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.go('/community-guide'),
                          child: const Text('See all →',
                              style: TextStyle(color: _kBlue)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_loadingDestinations)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(color: _kBlue),
                      ),
                    )
                  else
                    SizedBox(
                      height: 200,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _destinations.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, i) =>
                            _DestinationCard(destination: _destinations[i]),
                      ),
                    ),
                ],
              ),

            const SizedBox(height: 28),

            // ── CTA Banner ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 36),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_kBlue, _kCyan],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: _kBlue.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4),
                            width: 1.5),
                      ),
                      child: const Icon(Icons.explore,
                          color: Colors.white, size: 30),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Ready to explore?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Join thousands of travellers sharing their adventures',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => context.go('/community-guide'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _kBlue,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 14),
                      ),
                      child: const Text(
                        'Browse Community Guides',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Hero Section ──────────────────────────────────────────────────────────────
// Dark gradient mirrors auth_screen.dart branding section

class _HeroSection extends ConsumerWidget {
  final dynamic authState;
  const _HeroSection({required this.authState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        // Gradient background
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_kBgStart, _kBgMid, _kBlue],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(28, 44, 28, 48),
          child: Column(
            children: [
              // Decorative chip — mirrors auth screen's badge style
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.25)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, size: 13, color: _kCyan),
                    SizedBox(width: 6),
                    Text('Trip Planning',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        )),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              const Text(
                'Plan Smarter,\nTravel Better',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.15,
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 16),

              Text(
                'Turn your dream destinations into detailed\nitineraries — instantly.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 15,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 32),

              // Primary CTA — gradient button matching auth_screen.dart
              _GradientButton(
                label: authState.isAuthenticated
                    ? 'Plan a New Trip'
                    : 'Get Started — It\'s Free',
                icon: Icons.add,
                onPressed: () =>
                    context.go(authState.isAuthenticated ? '/plan' : '/auth'),
              ),

              const SizedBox(height: 14),

              // Secondary CTA
              OutlinedButton.icon(
                onPressed: () => context.go('/community-guide'),
                icon: const Icon(Icons.explore_outlined,
                    size: 18, color: Colors.white),
                label: const Text('Browse Community Guides',
                    style: TextStyle(color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.45)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),

        // Decorative blobs — mirrors auth_screen.dart(bubble)
        Positioned(
          top: -40,
          right: -30,
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.04),
            ),
          ),
        ),
        Positioned(
          top: 60,
          right: 20,
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _kCyan.withValues(alpha: 0.18),
            ),
          ),
        ),
        Positioned(
          top: 100,
          left: -30,
          child: Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
        ),
      ],
    );
  }
}

// Gradient button — mirrors _gradientButton() from auth_screen.dart
class _GradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  const _GradientButton(
      {required this.label, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0369A1), _kBlue, _kCyan],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: _kBlue.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onPressed,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Stats Row ─────────────────────────────────────────────────────────────────
// Matches _StatCard style from dashboard_screen.dart

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      child: const Row(
        children: [
          _StatCard(
              label: 'Trips Planned',
              value: '10K+',
              icon: Icons.route,
              color: _kBlue),
          _StatCard(
              label: 'Destinations',
              value: '50+',
              icon: Icons.public,
              color: Color(0xFF10B981)),
          _StatCard(
              label: 'User Rating',
              value: '4.9★',
              icon: Icons.star,
              color: Color(0xFFF59E0B)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 18, color: color)),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

// ── Feature Card ──────────────────────────────────────────────────────────────
// Matches _StatCard + community filter chip visual language

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13, color: _kDark)),
          const SizedBox(height: 4),
          Text(description,
              style:
                  TextStyle(fontSize: 11, color: Colors.grey[600], height: 1.4),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// ── Destination Card ──────────────────────────────────────────────────────────
// Matches GuideCard thumbnail style

class _DestinationCard extends StatelessWidget {
  final PopularDestinationModel destination;
  const _DestinationCard({required this.destination});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        width: 160,
        child: Stack(
          fit: StackFit.expand,
          children: [
            destination.thumbnailImage.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: destination.thumbnailImage,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: Colors.blue[50]),
                    errorWidget: (_, __, ___) =>
                        Container(color: Colors.grey[200]),
                  )
                : Container(
                    color: Colors.blue[50],
                    child: const Icon(Icons.travel_explore,
                        color: Colors.blue, size: 40)),
            // Gradient overlay — same stops as GuideCard thumbnail
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                  stops: [0.45, 1.0],
                ),
              ),
            ),
            Positioned(
              bottom: 14,
              left: 12,
              right: 12,
              child: Text(
                destination.country,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
