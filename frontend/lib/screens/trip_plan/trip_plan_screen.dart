// lib/screens/trip_plan/trip_plan_screen.dart
// Create a travel guide from an existing trip's itinerary.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../repositories/trip_plan_repository.dart';
import '../../repositories/trip_repository.dart';
import '../../core/utils/snackbar.dart';

class TripPlanScreen extends ConsumerStatefulWidget {
  final String tripId;
  const TripPlanScreen({super.key, required this.tripId});

  @override
  ConsumerState<TripPlanScreen> createState() => _TripPlanScreenState();
}

class _TripPlanScreenState extends ConsumerState<TripPlanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _introCtrl = TextEditingController();

  Map<String, dynamic>? _trip;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadTrip();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _introCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTrip() async {
    try {
      final repo = ref.read(tripRepositoryProvider);
      final trip = await repo.getTripById(widget.tripId);
      setState(() {
        // Convert TripModel to map for display
        _trip = {
          'country': trip.country,
          'startDate': trip.startDate,
          'endDate': trip.endDate,
          'days': trip.days.map((d) => d.toJson()).toList(),
        };
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) AppSnackbar.error(context, 'Failed to load trip: $e');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_trip == null) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(tripPlanRepositoryProvider);

      // Build sections from the trip days
      final days = (_trip!['days'] as List? ?? []);
      final sections = <Map<String, dynamic>>[];

      // Add a general tips section first
      sections.add({
        'id': 'tips',
        'type': 'tips',
        'title': 'General Tips',
        'content': '',
        'route': [],
        'places': [],
        'listItems': [],
        'isOpen': true,
      });

      // Add one section per day
      for (int i = 0; i < days.length; i++) {
        final day = days[i] as Map<String, dynamic>;
        sections.add({
          'id': 'day${i + 1}',
          'type': 'day',
          'title': day['title'] ?? 'Day ${i + 1}',
          'route': day['activities'] ?? [],
          'places': day['places'] ?? [],
          'listItems': [],
          'notes': day['notes'] ?? '',
          'isOpen': true,
        });
      }

      await repo.createTripPlan(
        tripId: widget.tripId,
        title: _titleCtrl.text.trim(),
        authorIntro: _introCtrl.text.trim(),
        sections: sections,
      );

      AppSnackbar.success(context, 'Travel guide created! 🎉');
      if (mounted) context.go('/dashboard');
    } catch (e) {
      if (mounted) AppSnackbar.error(context, 'Failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final days = (_trip?['days'] as List? ?? []);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Travel Guide'),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Trip summary card
              if (_trip != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    Icon(Icons.map_outlined, color: Colors.blue[600]),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(_trip!['country'] ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        Text(
                            '${days.length} day${days.length == 1 ? '' : 's'} · ${_trip!['startDate'] ?? ''} – ${_trip!['endDate'] ?? ''}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.blue[700])),
                      ]),
                    ),
                  ]),
                ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                    labelText: 'Guide Title',
                    prefixIcon: Icon(Icons.title),
                    hintText: 'e.g. My 7 Days in Japan'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Title is required' : null,
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _introCtrl,
                decoration: const InputDecoration(
                    labelText: 'Your intro / bio',
                    prefixIcon: Icon(Icons.person_outline),
                    hintText: 'e.g. Travel blogger, visited 30+ countries'),
                maxLines: 2,
              ),
              const SizedBox(height: 20),

              // Preview sections that will be created
              if (days.isNotEmpty) ...[
                const Text('Sections that will be created',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                _SectionPreviewChip(label: '💡 General Tips'),
                ...List.generate(
                    days.length,
                    (i) => _SectionPreviewChip(
                        label:
                            '📅 ${(days[i] as Map)['title'] ?? 'Day ${i + 1}'}')),
                const SizedBox(height: 8),
                Text(
                    'You can edit these sections after creating the guide.',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.publish),
                  label: Text(_saving ? 'Creating...' : 'Create Travel Guide'),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionPreviewChip extends StatelessWidget {
  final String label;
  const _SectionPreviewChip({required this.label});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(children: [
          const Icon(Icons.drag_handle, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(fontSize: 13)),
        ]),
      );
}
