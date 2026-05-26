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
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final tripState = ref.watch(tripProvider);
    final communityState = ref.watch(communityProvider);
    final trips = tripState.trips;
    final totalCountries = trips.map((t) => t.country).toSet().length;
    final totalDays = trips.fold(0, (sum, t) => sum + t.days.length);
    final totalLocations = trips.fold(0, (sum, t) => sum + t.totalLocations);

    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, ${user?.username ?? ''}! ✨'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.go('/profile/${user?.username ?? ''}'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/home');
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/plan'),
        icon: const Icon(Icons.add),
        label: const Text('Plan New Trip'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(tripProvider.notifier).fetchMyTrips();
          await ref.read(communityProvider.notifier).fetchRecommendedGuides();
          await ref.read(communityProvider.notifier).fetchFollowersGuides();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                _StatCard(label: 'Trips', value: trips.length.toString(), icon: Icons.route, color: const Color(0xFF3B82F6)),
                const SizedBox(width: 10),
                _StatCard(label: 'Days', value: totalDays.toString(), icon: Icons.calendar_today, color: const Color(0xFF10B981)),
                const SizedBox(width: 10),
                _StatCard(label: 'Countries', value: totalCountries.toString(), icon: Icons.public, color: const Color(0xFFF43F5E)),
                const SizedBox(width: 10),
                _StatCard(label: 'Places', value: totalLocations.toString(), icon: Icons.place, color: const Color(0xFFF59E0B)),
              ]),
              const SizedBox(height: 24),
              const Text('My Trips', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (tripState.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (trips.isEmpty)
                _EmptyTripsState(onAdd: () => context.go('/plan'))
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: trips.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _TripCard(
                    trip: trips[i],
                    onView: () => context.go('/trips/${trips[i].id}'),
                    onEdit: () => context.go('/trips/${trips[i].id}/edit'),
                    onDelete: () async {
                      final ok = await ref.read(tripProvider.notifier).deleteTrip(trips[i].id);
                      if (!ok && context.mounted) AppSnackbar.error(context, 'Failed to delete trip');
                    },
                    onCreateGuide: trips[i].isTravelGuideCreated ? null : () => context.go('/create-travel-guide/${trips[i].id}'),
                    onEditGuide: trips[i].isTravelGuideCreated ? () => context.go('/edit-travel-guide/${trips[i].tripPlanId}') : null,
                  ),
                ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Recommended for You', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  TextButton(onPressed: () => context.go('/community-guide'), child: const Text('See all →')),
                ],
              ),
              const SizedBox(height: 12),
              if (communityState.recommendedGuides.isEmpty)
                Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('No recommendations yet. Follow more travellers!',
                      textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[500])),
                ))
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: communityState.recommendedGuides.length.clamp(0, 5),
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final g = communityState.recommendedGuides[i];
                    return GuideCard(
                      guide: g,
                      onTap: () => context.go('/trip-plan/view/${g.itinerary?['_id']}'),
                      onLike: () => ref.read(communityProvider.notifier).toggleLike(g.id),
                      onSave: () => ref.read(communityProvider.notifier).toggleSave(g.id),
                    );
                  },
                ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ]),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final TripModel trip;
  final VoidCallback onView, onEdit, onDelete;
  final VoidCallback? onCreateGuide, onEditGuide;
  const _TripCard({required this.trip, required this.onView, required this.onEdit, required this.onDelete, this.onCreateGuide, this.onEditGuide});

  String _fmt(String iso) {
    try {
      final d = DateTime.parse(iso);
      const m = ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${m[d.month]} ${d.day}, ${d.year}';
    } catch (_) { return iso; }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.place, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(trip.country, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text('${_fmt(trip.startDate)} – ${_fmt(trip.endDate)}', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              Text('${trip.days.length} days • ${trip.totalLocations} locations', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
            ])),
            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), onPressed: onDelete),
          ]),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: onView, icon: const Icon(Icons.visibility_outlined, size: 16), label: const Text('View', style: TextStyle(fontSize: 12)))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 16), label: const Text('Edit', style: TextStyle(fontSize: 12)))),
            const SizedBox(width: 8),
            Expanded(child: onEditGuide != null
                ? ElevatedButton(onPressed: onEditGuide, style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8)), child: const Text('Edit Guide', style: TextStyle(fontSize: 11)))
                : ElevatedButton(onPressed: onCreateGuide, style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8)), child: const Text('+ Guide', style: TextStyle(fontSize: 11)))),
          ]),
        ]),
      ),
    );
  }
}

class _EmptyTripsState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyTripsState({required this.onAdd});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        Icon(Icons.calendar_today_outlined, size: 48, color: Colors.grey[300]),
        const SizedBox(height: 12),
        const Text('No trips yet', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text('Tap "Plan New Trip" to get started!', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
      ]),
    );
  }
}
