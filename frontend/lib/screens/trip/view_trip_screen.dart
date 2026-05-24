// lib/screens/trip/view_trip_screen.dart
// Replaces frontend/src/pages/planNewTrip/viewTripPage.tsx

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../repositories/trip_repository.dart';
import '../../models/trip_model.dart';

class ViewTripScreen extends ConsumerStatefulWidget {
  final String tripId;
  const ViewTripScreen({super.key, required this.tripId});

  @override
  ConsumerState<ViewTripScreen> createState() => _ViewTripScreenState();
}

class _ViewTripScreenState extends ConsumerState<ViewTripScreen> {
  TripModel? _trip;
  bool _loading = true;
  String? _error;
  String? _activeDate;

  @override
  void initState() {
    super.initState();
    _loadTrip();
  }

  Future<void> _loadTrip() async {
    try {
      final repo = ref.read(tripRepositoryProvider);
      final trip = await repo.getTripById(widget.tripId);
      setState(() {
        _trip = trip;
        _activeDate = trip.days.isNotEmpty ? trip.days.first.date : null;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      const months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[d.month]} ${d.day}, ${d.year}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text(_error!)),
      );
    }

    final trip = _trip!;
    final activeDay = trip.days.firstWhere(
      (d) => d.date == _activeDate,
      orElse: () => DayModel(date: '', locations: []),
    );
    final allMarkers = trip.days.expand((d) => d.locations).toList();
    final hasMarkers = allMarkers.isNotEmpty;
    final mapCenter = hasMarkers
        ? LatLng(allMarkers.first.lat, allMarkers.first.lng)
        : const LatLng(20, 0);

    return Scaffold(
      appBar: AppBar(
        title: Text('Trip to ${trip.country}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.go('/trips/${trip.id}/edit'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Map
          SizedBox(
            height: 220,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: mapCenter,
                initialZoom: hasMarkers ? 10 : 2,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.smart_travel_planner',
                ),
                MarkerLayer(
                  markers: allMarkers.asMap().entries.map((e) {
                    final loc = e.value;
                    return Marker(
                      point: LatLng(loc.lat, loc.lng),
                      width: 30,
                      height: 30,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF3B82F6),
                              Color(0xFF06B6D4)
                            ],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${e.key + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // Trip info
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.calendar_today,
                    size: 14, color: Colors.grey[500]),
                const SizedBox(width: 6),
                Text(
                  '${_formatDate(trip.startDate)} – ${_formatDate(trip.endDate)}',
                  style:
                      TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const Spacer(),
                Text(
                  '${trip.days.length} days',
                  style:
                      TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          // Day tabs
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: trip.days.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final day = trip.days[i];
                final isActive = day.date == _activeDate;
                return GestureDetector(
                  onTap: () => setState(() => _activeDate = day.date),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: isActive
                          ? const LinearGradient(
                              colors: [
                                Color(0xFF3B82F6),
                                Color(0xFF06B6D4)
                              ],
                            )
                          : null,
                      color: isActive ? null : Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Day ${i + 1}',
                      style: TextStyle(
                        color: isActive ? Colors.white : Colors.grey[700],
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // Locations for active day
          Expanded(
            child: activeDay.locations.isEmpty
                ? Center(
                    child: Text(
                      'No locations for this day',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: activeDay.locations.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final loc = activeDay.locations[i];
                      return Card(
                        child: ListTile(
                          leading: Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFF3B82F6),
                                  Color(0xFF06B6D4)
                                ],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          title: Text(loc.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          subtitle: loc.note.isNotEmpty
                              ? Text(loc.note,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[500]))
                              : null,
                          trailing: Text(
                            '${loc.lat.toStringAsFixed(3)}, ${loc.lng.toStringAsFixed(3)}',
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey[400]),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
