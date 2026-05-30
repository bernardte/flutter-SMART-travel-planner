// lib/screens/dashboard/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_provider.dart';
import '../../providers/community_provider.dart';
import '../../models/trip_model.dart';
import '../../widgets/card/guide_card.dart';
import '../../core/utils/snackbar.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String _tripSearch = '';
  String _tripStatus = 'all'; // 'all' | 'upcoming' | 'ongoing' | 'completed'
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(tripProvider.notifier).fetchMyTrips();
      ref.read(communityProvider.notifier).fetchRecommendedGuides();
      ref.read(communityProvider.notifier).fetchFollowersGuides();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<TripModel> _applyFilter(List<TripModel> trips) {
    var result = trips;

    if (_tripSearch.isNotEmpty) {
      final q = _tripSearch.toLowerCase();
      result = result
          .where((t) => t.country.toLowerCase().contains(q))
          .toList();
    }

    if (_tripStatus != 'all') {
      final now = DateTime.now();
      result = result.where((t) {
        try {
          final start = DateTime.parse(t.startDate);
          final end = DateTime.parse(t.endDate);
          switch (_tripStatus) {
            case 'upcoming':
              return now.isBefore(start);
            case 'ongoing':
              return !now.isBefore(start) && !now.isAfter(end);
            case 'completed':
              return now.isAfter(end);
          }
        } catch (_) {}
        return true;
      }).toList();
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final auth = ref.watch(authProvider);
    final tripState = ref.watch(tripProvider);
    final communityState = ref.watch(communityProvider);
    final trips = tripState.trips;

    final totalCountries = trips.map((t) => t.country).toSet().length;
    final totalDays = trips.fold(0, (sum, t) => sum + t.days.length);
    final totalLocations =
        trips.fold(0, (sum, t) => sum + t.totalLocations);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F9FF),
      appBar: _buildAppBar(user?.username ?? ''),
      floatingActionButton: auth.isAuthenticated
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/plan'),
              icon: const Icon(Icons.add, size: 20),
              label: const Text(
                'Plan New Trip',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3),
              ),
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              elevation: 2,
              shape: const StadiumBorder(),
            )
          : null,
      body: RefreshIndicator(
        color: const Color(0xFF3B82F6),
        onRefresh: () async {
          await ref.read(tripProvider.notifier).fetchMyTrips();
          await ref
              .read(communityProvider.notifier)
              .fetchRecommendedGuides();
          await ref
              .read(communityProvider.notifier)
              .fetchFollowersGuides();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Hero header ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _HeroHeader(
                username: user?.username ?? 'Traveler',
                trips: trips.length,
                days: totalDays,
                countries: totalCountries,
                places: totalLocations,
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // ── My Trips ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _SectionHeader(
                  title: trips.isEmpty
                      ? 'My Trips'
                      : 'My Trips (${_applyFilter(trips).length}/${trips.length})',
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            // ── Filter bar (shown only when trips exist) ──────────────────
            if (!tripState.isLoading && trips.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: _TripFilterBar(
                    controller: _searchCtrl,
                    searchQuery: _tripSearch,
                    statusFilter: _tripStatus,
                    onSearchChanged: (v) =>
                        setState(() => _tripSearch = v),
                    onSearchCleared: () {
                      _searchCtrl.clear();
                      setState(() => _tripSearch = '');
                    },
                    onStatusChanged: (v) =>
                        setState(() => _tripStatus = v),
                  ),
                ),
              ),
            if (tripState.isLoading)
              const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(
                        color: Color(0xFF3B82F6)),
                  ),
                ),
              )
            else if (trips.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _EmptyCard(
                    icon: Icons.map_outlined,
                    title: 'No trips yet',
                    subtitle: 'Tap "Plan New Trip" to start your journey!',
                    actionLabel: 'Plan a Trip',
                    onAction: () => context.push('/plan'),
                  ),
                ),
              )
            else
              Builder(builder: (context) {
                final filtered = _applyFilter(trips);
                if (filtered.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _EmptyCard(
                        icon: Icons.search_off_rounded,
                        title: 'No trips match',
                        subtitle:
                            'Try a different country name or status filter.',
                        actionLabel: 'Clear filters',
                        onAction: () {
                          _searchCtrl.clear();
                          setState(() {
                            _tripSearch = '';
                            _tripStatus = 'all';
                          });
                        },
                      ),
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: Duration(
                              milliseconds: 300 + (i * 50).clamp(0, 500)),
                          builder: (_, v, child) => Opacity(
                            opacity: v,
                            child: Transform.translate(
                              offset: Offset(0, 24 * (1 - v)),
                              child: child,
                            ),
                          ),
                          child: _TripCard(
                            trip: filtered[i],
                            onView: () =>
                                context.push('/trips/${filtered[i].id}'),
                            onEdit: () => context
                                .push('/trips/${filtered[i].id}/edit'),
                            onDelete: () async {
                              final ok = await ref
                                  .read(tripProvider.notifier)
                                  .deleteTrip(filtered[i].id);
                              if (!ok && context.mounted) {
                                AppSnackbar.error(
                                    context, 'Failed to delete trip');
                              }
                            },
                            onCreateGuide:
                                filtered[i].isTravelGuideCreated
                                    ? null
                                    : () => context.push(
                                        '/create-travel-guide/${filtered[i].id}'),
                            onEditGuide: filtered[i].isTravelGuideCreated
                                ? () => context.push(
                                    '/edit-travel-guide/${filtered[i].tripPlanId}')
                                : null,
                          ),
                        ),
                      ),
                      childCount: filtered.length,
                    ),
                  ),
                );
              }),

            const SliverToBoxAdapter(child: SizedBox(height: 28)),

            // ── From People You Follow ────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _SectionHeader(
                  title:
                      'From People You Follow (${communityState.followersGuides.length})',
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            if (communityState.followersGuides.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _EmptyCard(
                    icon: Icons.person_search_outlined,
                    title: 'Nothing here yet',
                    subtitle:
                        'Follow travelers to see their posts — including private ones!',
                    actionLabel: 'Discover Travelers',
                    onAction: () => context.go('/community-guide'),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final guide = communityState.followersGuides[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: Duration(
                              milliseconds:
                                  300 + (i * 50).clamp(0, 500)),
                          builder: (_, v, child) => Opacity(
                            opacity: v,
                            child: Transform.translate(
                              offset: Offset(0, 24 * (1 - v)),
                              child: child,
                            ),
                          ),
                          child: Stack(
                            children: [
                              GuideCard(
                                guide: guide,
                                likedCount: guide.likes,
                                isLiked: guide.isLiked,
                                isSaved: guide.isSaved,
                                onTap: () => context.go(
                                    '/trip-plan/view/${guide.itinerary?['_id']}'),
                                onLike: () => ref
                                    .read(communityProvider.notifier)
                                    .toggleLike(guide.id),
                                onSave: () => ref
                                    .read(communityProvider.notifier)
                                    .toggleSave(guide.id),
                              ),
                              if (guide.privacy == 'private')
                                const Positioned(
                                  top: 12,
                                  left: 12,
                                  child: _PrivateBadge(),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: communityState.followersGuides.length
                        .clamp(0, 5),
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 28)),

            // ── Recommended for You ───────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _SectionHeader(
                  title: 'Recommended for You',
                  trailing: TextButton(
                    onPressed: () => context.go('/community-guide'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF3B82F6),
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('See all →',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            if (communityState.isLoadingRecommendations)
              const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(
                        color: Color(0xFF3B82F6)),
                  ),
                ),
              )
            else if (communityState.recommendedGuides.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: _EmptyCard(
                    icon: Icons.travel_explore_outlined,
                    title: 'No recommendations yet',
                    subtitle:
                        'Follow travelers and like posts to get personalised picks!',
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final guide = communityState.recommendedGuides[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: Duration(
                              milliseconds:
                                  300 + (i * 50).clamp(0, 500)),
                          builder: (_, v, child) => Opacity(
                            opacity: v,
                            child: Transform.translate(
                              offset: Offset(0, 24 * (1 - v)),
                              child: child,
                            ),
                          ),
                          child: GuideCard(
                            guide: guide,
                            likedCount: guide.likes,
                            isLiked: guide.isLiked,
                            isSaved: guide.isSaved,
                            onTap: () => context.go(
                                '/trip-plan/view/${guide.itinerary?['_id']}'),
                            onLike: () => ref
                                .read(communityProvider.notifier)
                                .toggleLike(guide.id),
                            onSave: () => ref
                                .read(communityProvider.notifier)
                                .toggleSave(guide.id),
                          ),
                        ),
                      );
                    },
                    childCount: communityState.recommendedGuides.length
                        .clamp(0, 5),
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  // ── AppBar — matches saved / community pattern exactly ──────────────────────
  PreferredSizeWidget _buildAppBar(String username) {
    return AppBar(
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.flight_takeoff, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Text(
            'TravelBuddy',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 22,
              color: Color(0xFF1E3A8A),
            ),
          ),
        ],
      ),
      centerTitle: false,
      backgroundColor: Colors.white,
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.person_outline, color: Color(0xFF3B82F6)),
          tooltip: 'Profile',
          onPressed: () => context
              .push('/profile/${ref.read(authProvider).user?.username ?? ''}'),
        ),
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.grey),
          tooltip: 'Logout',
          onPressed: () async {
            await ref.read(authProvider.notifier).logout();
            if (mounted) context.go('/home');
          },
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: Colors.grey[100]),
      ),
    );
  }
}

// ── Hero header ───────────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  final String username;
  final int trips, days, countries, places;

  const _HeroHeader({
    required this.username,
    required this.trips,
    required this.days,
    required this.countries,
    required this.places,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
              color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting
          RichText(
            text: TextSpan(
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937)),
              children: [
                const TextSpan(text: 'Welcome back, '),
                TextSpan(
                  text: username,
                  style: const TextStyle(
                      color: Color(0xFF3B82F6),
                      fontWeight: FontWeight.w800),
                ),
                const TextSpan(text: '! ✈️'),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Here's your travel summary.",
            style: TextStyle(
                fontSize: 13, color: Colors.grey[500], height: 1.4),
          ),

          const SizedBox(height: 20),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          const SizedBox(height: 16),

          // Stats row — same pattern as profile _ProfileCard stats
          IntrinsicHeight(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatItem(value: '$trips', label: 'Trips',
                    color: const Color(0xFF3B82F6)),
                const _VertDiv(),
                _StatItem(value: '$days', label: 'Days',
                    color: const Color(0xFF10B981)),
                const _VertDiv(),
                _StatItem(value: '$countries', label: 'Countries',
                    color: const Color(0xFFF43F5E)),
                const _VertDiv(),
                _StatItem(value: '$places', label: 'Places',
                    color: const Color(0xFFF59E0B)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value, label;
  final Color color;
  const _StatItem(
      {required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF9CA3AF),
              fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class _VertDiv extends StatelessWidget {
  const _VertDiv();

  @override
  Widget build(BuildContext context) {
    return Container(
        width: 1, color: const Color(0xFFE5E7EB), margin: const EdgeInsets.symmetric(horizontal: 4));
  }
}

// ── Section header — matches profile screen left-bar pattern ──────────────────

// ── Trip filter bar ───────────────────────────────────────────────────────────

class _TripFilterBar extends StatelessWidget {
  final TextEditingController controller;
  final String searchQuery;
  final String statusFilter;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final ValueChanged<String> onStatusChanged;

  const _TripFilterBar({
    required this.controller,
    required this.searchQuery,
    required this.statusFilter,
    required this.onSearchChanged,
    required this.onSearchCleared,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    const statuses = [
      (value: 'all', label: 'All', icon: Icons.list_rounded),
      (value: 'upcoming', label: 'Upcoming', icon: Icons.schedule_rounded),
      (value: 'ongoing', label: 'Ongoing', icon: Icons.flight_takeoff_rounded),
      (value: 'completed', label: 'Completed', icon: Icons.check_circle_outline_rounded),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search field
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Search by country...',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: Color(0xFF3B82F6), size: 20),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      icon:
                          const Icon(Icons.close_rounded, size: 18),
                      color: Colors.grey[400],
                      splashRadius: 16,
                      onPressed: onSearchCleared,
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFF0F6FF),
              contentPadding: const EdgeInsets.symmetric(
                  vertical: 10, horizontal: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: onSearchChanged,
          ),
          const SizedBox(height: 10),
          // Status chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: statuses.map((s) {
                final active = statusFilter == s.value;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => onStatusChanged(s.value),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: active
                            ? const Color(0xFF3B82F6)
                            : const Color(0xFFF0F6FF),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: active
                              ? const Color(0xFF3B82F6)
                              : const Color(0xFFD1D5DB),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            s.icon,
                            size: 13,
                            color: active
                                ? Colors.white
                                : const Color(0xFF6B7280),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            s.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: active
                                  ? Colors.white
                                  : const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A)),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

// ── Trip card ─────────────────────────────────────────────────────────────────

class _TripCard extends StatelessWidget {
  final TripModel trip;
  final VoidCallback onView, onEdit, onDelete;
  final VoidCallback? onCreateGuide, onEditGuide;

  const _TripCard({
    required this.trip,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    this.onCreateGuide,
    this.onEditGuide,
  });

  String _fmt(String iso) {
    try {
      final d = DateTime.parse(iso);
      const m = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${m[d.month]} ${d.day}, ${d.year}';
    } catch (_) {
      return iso;
    }
  }

  ({Color bg, Color text, IconData icon, String label}) _status() {
    try {
      final now = DateTime.now();
      final start = DateTime.parse(trip.startDate);
      final end = DateTime.parse(trip.endDate);
      if (now.isBefore(start)) {
        return (
          bg: const Color(0xFFDBEAFE),
          text: const Color(0xFF1D4ED8),
          icon: Icons.schedule_rounded,
          label: 'Upcoming'
        );
      } else if (now.isAfter(end)) {
        return (
          bg: const Color(0xFFF3F4F6),
          text: const Color(0xFF6B7280),
          icon: Icons.check_circle_outline_rounded,
          label: 'Completed'
        );
      } else {
        return (
          bg: const Color(0xFFD1FAE5),
          text: const Color(0xFF065F46),
          icon: Icons.flight_takeoff_rounded,
          label: 'Ongoing'
        );
      }
    } catch (_) {
      return (
        bg: const Color(0xFFF3F4F6),
        text: const Color(0xFF6B7280),
        icon: Icons.route,
        label: 'Trip'
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = _status();
    final hasGuide = trip.isTravelGuideCreated;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Gradient header strip ─────────────────────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1D4ED8), Color(0xFF0891B2)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Row(
              children: [
                // Icon container
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.travel_explore,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                // Country + date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip.country,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            letterSpacing: 0.2),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_fmt(trip.startDate)}  –  ${_fmt(trip.endDate)}',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12),
                      ),
                    ],
                  ),
                ),
                // Status chip
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: st.bg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(st.icon, size: 12, color: st.text),
                      const SizedBox(width: 4),
                      Text(
                        st.label,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: st.text),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Body ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info chips
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _Chip(
                      icon: Icons.calendar_today_outlined,
                      label: '${trip.days.length} day${trip.days.length == 1 ? '' : 's'}',
                      color: const Color(0xFF3B82F6),
                    ),
                    _Chip(
                      icon: Icons.place_outlined,
                      label:
                          '${trip.totalLocations} place${trip.totalLocations == 1 ? '' : 's'}',
                      color: const Color(0xFF10B981),
                    ),
                    if (hasGuide)
                      const _Chip(
                        icon: Icons.article_outlined,
                        label: 'Guide created',
                        color: Color(0xFF8B5CF6),
                      ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF3F4F6)),
                const SizedBox(height: 10),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: _ActionBtn(
                        icon: Icons.visibility_outlined,
                        label: 'View',
                        onTap: onView,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionBtn(
                        icon: Icons.edit_outlined,
                        label: 'Edit',
                        onTap: onEdit,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: hasGuide
                          ? _FilledBtn(
                              icon: Icons.edit_note_rounded,
                              label: 'Edit Guide',
                              onTap: onEditGuide ?? () {},
                              color: const Color(0xFF8B5CF6),
                            )
                          : _FilledBtn(
                              icon: Icons.add_rounded,
                              label: 'Guide',
                              onTap: onCreateGuide ?? () {},
                              color: const Color(0xFF3B82F6),
                            ),
                    ),
                    const SizedBox(width: 6),
                    _DeleteBtn(onTap: onDelete),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Small chip (days / places / guide) ───────────────────────────────────────

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Chip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ],
      ),
    );
  }
}

// ── Outlined action button ────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 15),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF374151),
        side: const BorderSide(color: Color(0xFFD1D5DB)),
        padding: const EdgeInsets.symmetric(vertical: 9),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

// ── Filled action button ──────────────────────────────────────────────────────

class _FilledBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  const _FilledBtn(
      {required this.icon,
      required this.label,
      required this.onTap,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 15),
      label: Text(label, style: const TextStyle(fontSize: 10)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 9),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

// ── Delete icon button ────────────────────────────────────────────────────────

class _DeleteBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _DeleteBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFEE2E2),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: const Padding(
          padding: EdgeInsets.all(9),
          child: Icon(Icons.delete_outline_rounded,
              color: Color(0xFFDC2626), size: 19),
        ),
      ),
    );
  }
}

// ── Private post badge ────────────────────────────────────────────────────────

class _PrivateBadge extends StatelessWidget {
  const _PrivateBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFD97706),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_rounded, size: 11, color: Colors.white),
          SizedBox(width: 4),
          Text(
            'Private',
            style: TextStyle(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// ── Generic empty card ────────────────────────────────────────────────────────

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onAction;
  final String? actionLabel;

  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 28, color: const Color(0xFF3B82F6)),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: Color(0xFF1E3A8A)),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF9CA3AF), height: 1.4),
          ),
          if (onAction != null && actionLabel != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(actionLabel!,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
        ],
      ),
    );
  }
}
