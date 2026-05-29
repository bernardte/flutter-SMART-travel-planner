// lib/screens/trip/edit_trip_screen.dart
// Replaces frontend/src/pages/planNewTrip/editTripPage.tsx

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:dio/dio.dart';
import '../../repositories/trip_repository.dart';
import '../../models/trip_model.dart';
import '../../core/utils/snackbar.dart';

class EditTripScreen extends ConsumerStatefulWidget {
  final String tripId;
  const EditTripScreen({super.key, required this.tripId});

  @override
  ConsumerState<EditTripScreen> createState() => _EditTripScreenState();
}

class _EditTripScreenState extends ConsumerState<EditTripScreen> {
  final _countryCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _addingLocation = false;

  String _startDate = '';
  String _endDate = '';
  List<DayModel> _itinerary = [];
  String? _activeDate;
  TripModel? _originalTrip;

  @override
  void initState() {
    super.initState();
    _loadTrip();
  }

  @override
  void dispose() {
    _countryCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTrip() async {
    try {
      final repo = ref.read(tripRepositoryProvider);
      final trip = await repo.getTripById(widget.tripId);
      setState(() {
        _originalTrip = trip;
        _countryCtrl.text = trip.country;
        _startDate = trip.startDate;
        _endDate = trip.endDate;
        _itinerary = List.from(trip.days);
        _activeDate = trip.days.isNotEmpty ? trip.days.first.date : null;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        AppSnackbar.error(context, 'Failed to load trip: $e');
      }
    }
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

  void _rebuildItinerary(String start, String end) {
    final dates = _generateDateRange(start, end);
    setState(() {
      _itinerary = dates.map((d) {
        return _itinerary.firstWhere(
          (e) => e.date == d,
          orElse: () => DayModel(date: d, locations: []),
        );
      }).toList();
      if (_activeDate == null || !dates.contains(_activeDate)) {
        _activeDate = dates.isNotEmpty ? dates.first : null;
      }
    });
  }

  Future<LatLng> _geocode(String query) async {
    try {
      final dio = Dio();
      final res = await dio.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {'q': query, 'format': 'json', 'limit': 1},
        options: Options(headers: {'User-Agent': 'SmartTravelPlanner/1.0'}),
      );
      final data = jsonDecode(res.data is String ? res.data : jsonEncode(res.data)) as List?;
      if (data != null && data.isNotEmpty) {
        return LatLng(double.parse(data[0]['lat']), double.parse(data[0]['lon']));
      }
    } catch (_) {}
    return const LatLng(48.8566, 2.3522);
  }

  Future<void> _addLocation() async {
    if (_locationCtrl.text.trim().isEmpty || _activeDate == null) return;
    setState(() => _addingLocation = true);
    final coords = await _geocode('${_locationCtrl.text.trim()}, ${_countryCtrl.text}');
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
          return DayModel(date: d.date, locations: [...d.locations, newLoc]);
        }
        return d;
      }).toList();
      _locationCtrl.clear();
      _addingLocation = false;
    });
  }

  void _removeLocation(String locId) {
    setState(() {
      _itinerary = _itinerary.map((d) {
        if (d.date == _activeDate) {
          return DayModel(date: d.date, locations: d.locations.where((l) => l.id != locId).toList());
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
              return l.id == locId ? LocationModel(id: l.id, name: l.name, note: note, lat: l.lat, lng: l.lng) : l;
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
    setState(() => _saving = true);
    try {
      final repo = ref.read(tripRepositoryProvider);
      await repo.updateTrip(
        id: widget.tripId,
        country: _countryCtrl.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        days: _itinerary,
      );
      AppSnackbar.success(context, 'Trip updated! ✅');
      if (mounted) context.go('/trips/${widget.tripId}');
    } catch (e) {
      AppSnackbar.error(context, 'Failed to update: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  DayModel? get _activeDay => _itinerary.cast<DayModel?>().firstWhere(
        (d) => d?.date == _activeDate,
        orElse: () => null,
      );

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
            gradient: LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)]),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text('${e.key + 1}',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final allLocs = _itinerary.expand((d) => d.locations).toList();
    final mapCenter = allLocs.isNotEmpty ? LatLng(allLocs.first.lat, allLocs.first.lng) : const LatLng(20, 0);

    return Scaffold(
      appBar: AppBar(
        title: Text('Edit: ${_countryCtrl.text}'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.canPop() ? context.pop() : context.go('/dashboard')),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check),
            label: Text(_saving ? 'Saving...' : 'Update'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Map
          SizedBox(
            height: 200,
            child: FlutterMap(
              options: MapOptions(initialCenter: mapCenter, initialZoom: allLocs.isNotEmpty ? 10 : 2),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.smart_travel_planner',
                ),
                MarkerLayer(markers: _markers),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _countryCtrl,
                    decoration: const InputDecoration(labelText: 'Destination', prefixIcon: Icon(Icons.public)),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _DateField(label: 'Start Date', value: _startDate, onChanged: (d) {
                        setState(() => _startDate = d);
                        if (_endDate.isNotEmpty) _rebuildItinerary(d, _endDate);
                      })),
                      const SizedBox(width: 12),
                      Expanded(child: _DateField(label: 'End Date', value: _endDate, onChanged: (d) {
                        setState(() => _endDate = d);
                        if (_startDate.isNotEmpty) _rebuildItinerary(_startDate, d);
                      })),
                    ],
                  ),
                  if (_itinerary.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 48,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _itinerary.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final day = _itinerary[i];
                          final isActive = day.date == _activeDate;
                          return GestureDetector(
                            onTap: () => setState(() => _activeDate = day.date),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: isActive
                                    ? const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)])
                                    : null,
                                color: isActive ? null : Colors.grey[100],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text('Day ${i + 1}',
                                  style: TextStyle(
                                      color: isActive ? Colors.white : Colors.grey[700],
                                      fontWeight: FontWeight.w600)),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  if (_activeDay != null) ...[
                    const SizedBox(height: 16),
                    ..._activeDay!.locations.asMap().entries.map((e) {
                      final loc = e.value;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Container(
                                width: 28, height: 28,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)]),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(child: Text('${e.key + 1}',
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Text(loc.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                onPressed: () => _removeLocation(loc.id),
                              ),
                            ]),
                            const SizedBox(height: 8),
                            TextFormField(
                              initialValue: loc.note,
                              decoration: const InputDecoration(hintText: 'Add a note...', isDense: true, border: OutlineInputBorder()),
                              maxLines: 2,
                              onChanged: (v) => _updateNote(loc.id, v),
                            ),
                          ]),
                        ),
                      );
                    }),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _locationCtrl,
                          decoration: const InputDecoration(hintText: 'Add location...', prefixIcon: Icon(Icons.search)),
                          onSubmitted: (_) => _addLocation(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _addingLocation ? null : _addLocation,
                        child: _addingLocation
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.add),
                      ),
                    ]),
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

class _DateField extends StatelessWidget {
  final String label, value;
  final void Function(String) onChanged;
  const _DateField({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value.isNotEmpty ? DateTime.parse(value) : DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
        );
        if (picked != null) onChanged(picked.toIso8601String().split('T').first);
      },
      child: AbsorbPointer(
        child: TextField(
          controller: TextEditingController(text: value),
          decoration: InputDecoration(labelText: label, prefixIcon: const Icon(Icons.calendar_today, size: 18)),
        ),
      ),
    );
  }
}
