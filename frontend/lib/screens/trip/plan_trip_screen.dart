// lib/screens/trip/plan_trip_screen.dart
// Replaces frontend/src/pages/planNewTrip/planNewTripPage.tsx

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:dio/dio.dart';
import '../../providers/trip_provider.dart';
import '../../models/trip_model.dart';
import '../../core/utils/snackbar.dart';

class PlanTripScreen extends ConsumerStatefulWidget {
  const PlanTripScreen({super.key});

  @override
  ConsumerState<PlanTripScreen> createState() => _PlanTripScreenState();
}

class _PlanTripScreenState extends ConsumerState<PlanTripScreen> {
  final _countryCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _mapController = MapController();

  String _startDate = '';
  String _endDate = '';
  List<DayModel> _itinerary = [];
  String? _activeDate;
  LatLng _mapCenter = const LatLng(20, 0);
  double _mapZoom = 2;
  bool _isAddingLocation = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _countryCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  List<String> _generateDateRange(String start, String end) {
    if (start.isEmpty || end.isEmpty) return [];
    final dates = <String>[];
    var cur = DateTime.parse(start);
    final last = DateTime.parse(end);
    while (!cur.isAfter(last)) {
      dates.add(cur.toIso8601String().split('T').first);
      cur = cur.add(const Duration(days: 1));
    }
    return dates;
  }

  void _updateDates(String start, String end) {
    final dates = _generateDateRange(start, end);
    final newItinerary = dates.map((d) {
      final existing = _itinerary.firstWhere(
        (e) => e.date == d,
        orElse: () => DayModel(date: d, locations: []),
      );
      return existing;
    }).toList();
    setState(() {
      _itinerary = newItinerary;
      _activeDate = dates.isNotEmpty ? dates.first : null;
    });
  }

  Future<LatLng> _geocode(String query) async {
    try {
      final dio = Dio();
      final res = await dio.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': query,
          'format': 'json',
          'limit': 1,
        },
        options: Options(headers: {'User-Agent': 'SmartTravelPlanner/1.0'}),
      );
      final data = jsonDecode(res.data is String
          ? res.data
          : jsonEncode(res.data)) as List?;
      if (data != null && data.isNotEmpty) {
        return LatLng(
          double.parse(data[0]['lat']),
          double.parse(data[0]['lon']),
        );
      }
    } catch (_) {}
    return const LatLng(48.8566, 2.3522); // default to Paris
  }

  Future<void> _addLocation() async {
    if (_locationCtrl.text.trim().isEmpty || _activeDate == null) return;
    setState(() => _isAddingLocation = true);

    final query = '${_locationCtrl.text.trim()}, ${_countryCtrl.text}';
    final coords = await _geocode(query);

    final newLoc = LocationModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _locationCtrl.text.trim(),
      note: '',
      lat: coords.latitude,
      lng: coords.longitude,
    );

    setState(() {
      _itinerary = _itinerary.map((d) {
        if (d.date == _activeDate) {
          return DayModel(
              date: d.date, locations: [...d.locations, newLoc]);
        }
        return d;
      }).toList();
      _mapCenter = coords;
      _mapZoom = 13;
      _locationCtrl.clear();
      _isAddingLocation = false;
    });
  }

  void _removeLocation(String locId) {
    setState(() {
      _itinerary = _itinerary.map((d) {
        if (d.date == _activeDate) {
          return DayModel(
            date: d.date,
            locations: d.locations.where((l) => l.id != locId).toList(),
          );
        }
        return d;
      }).toList();
    });
  }

  void _updateNote(String locId, String note) {
    setState(() {
      _itinerary = _itinerary.map((d) {
        if (d.date == _activeDate) {
          return DayModel(
            date: d.date,
            locations: d.locations.map((l) {
              return l.id == locId
                  ? LocationModel(
                      id: l.id,
                      name: l.name,
                      note: note,
                      lat: l.lat,
                      lng: l.lng)
                  : l;
            }).toList(),
          );
        }
        return d;
      }).toList();
    });
  }

  Future<void> _save() async {
    if (_countryCtrl.text.trim().isEmpty) {
      AppSnackbar.show(context, 'Please enter a destination');
      return;
    }
    if (_startDate.isEmpty || _endDate.isEmpty) {
      AppSnackbar.show(context, 'Please select travel dates');
      return;
    }
    final totalLocs =
        _itinerary.fold(0, (s, d) => s + d.locations.length);
    if (totalLocs == 0) {
      AppSnackbar.show(context, 'Add at least one location');
      return;
    }

    setState(() => _isSaving = true);
    final ok = await ref.read(tripProvider.notifier).saveTrip(
          country: _countryCtrl.text.trim(),
          startDate: _startDate,
          endDate: _endDate,
          days: _itinerary,
        );
    if (mounted) {
      setState(() => _isSaving = false);
      if (ok) {
        AppSnackbar.success(context, 'Trip saved!');
        context.go('/dashboard');
      } else {
        AppSnackbar.error(context, 'Failed to save trip');
      }
    }
  }

  DayModel? get _activeDay =>
      _itinerary.firstWhereOrNull((d) => d.date == _activeDate);

  List<Marker> get _markers {
    final all = _itinerary.expand((d) => d.locations).toList();
    return all.asMap().entries.map((e) {
      final loc = e.value;
      return Marker(
        point: LatLng(loc.lat, loc.lng),
        width: 30,
        height: 30,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
            ),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '${e.key + 1}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
        title: Text(
          _countryCtrl.text.isEmpty
              ? 'Plan New Trip'
              : 'Trip to ${_countryCtrl.text}',
        ),
        actions: [
          if (_itinerary.isNotEmpty)
            TextButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check),
              label: Text(_isSaving ? 'Saving...' : 'Save'),
            ),
        ],
      ),
      body: Column(
        children: [
          // Map
          SizedBox(
            height: 250,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _mapCenter,
                initialZoom: _mapZoom,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.smart_travel_planner',
                ),
                MarkerLayer(markers: _markers),
              ],
            ),
          ),
          // Controls
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Destination input
                  TextField(
                    controller: _countryCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Destination (country/city)',
                      prefixIcon: Icon(Icons.public),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  // Date pickers
                  Row(
                    children: [
                      Expanded(
                        child: _DatePickerField(
                          label: 'Start Date',
                          value: _startDate,
                          onChanged: (d) {
                            setState(() => _startDate = d);
                            if (_endDate.isNotEmpty) {
                              _updateDates(d, _endDate);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DatePickerField(
                          label: 'End Date',
                          value: _endDate,
                          onChanged: (d) {
                            setState(() => _endDate = d);
                            if (_startDate.isNotEmpty) {
                              _updateDates(_startDate, d);
                            }
                          },
                        ),
                      ),
                    ],
                  ),

                  // Day tabs
                  if (_itinerary.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('Select Day',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 56,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _itinerary.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final day = _itinerary[i];
                          final isActive = day.date == _activeDate;
                          return GestureDetector(
                            onTap: () =>
                                setState(() => _activeDate = day.date),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
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
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Day ${i + 1}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isActive
                                          ? Colors.white
                                          : Colors.grey,
                                    ),
                                  ),
                                  if (day.locations.isNotEmpty)
                                    Text(
                                      '${day.locations.length} stop${day.locations.length > 1 ? 's' : ''}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isActive
                                            ? Colors.white70
                                            : Colors.grey[400],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  // Active day locations
                  if (_activeDay != null) ...[
                    const SizedBox(height: 16),
                    // Location entries
                    ..._activeDay!.locations.asMap().entries.map((e) {
                      final loc = e.value;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
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
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      loc.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: Colors.red, size: 18),
                                    onPressed: () =>
                                        _removeLocation(loc.id),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                decoration: const InputDecoration(
                                  hintText: 'Add a note about this stop...',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                                maxLines: 2,
                                onChanged: (v) => _updateNote(loc.id, v),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                    // Add location input
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _locationCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Add a location...',
                              prefixIcon: Icon(Icons.search),
                            ),
                            onSubmitted: (_) => _addLocation(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _isAddingLocation ? null : _addLocation,
                          child: _isAddingLocation
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white))
                              : const Icon(Icons.add),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final String value;
  final void Function(String) onChanged;

  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
        );
        if (picked != null) {
          onChanged(picked.toIso8601String().split('T').first);
        }
      },
      child: AbsorbPointer(
        child: TextField(
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.calendar_today, size: 18),
          ),
          controller:
              TextEditingController(text: value.isEmpty ? '' : value),
        ),
      ),
    );
  }
}

extension ListExtension<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
