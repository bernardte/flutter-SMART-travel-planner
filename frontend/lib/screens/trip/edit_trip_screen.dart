// lib/screens/trip/edit_trip_screen.dart

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
import '../../core/utils/cached_tile_provider.dart';

// ── Design tokens (matches plan_trip_screen) ──────────────────────────────────
const _kBlue = Color(0xFF3B82F6);
const _kCyan = Color(0xFF06B6D4);
const _kDark = Color(0xFF1F2937);
const _kInputFill = Color(0xFFF0F9FF);
const _kInputBorder = Color(0xFFBAE6FD);

class EditTripScreen extends ConsumerStatefulWidget {
  final String tripId;
  const EditTripScreen({super.key, required this.tripId});

  @override
  ConsumerState<EditTripScreen> createState() => _EditTripScreenState();
}

class _EditTripScreenState extends ConsumerState<EditTripScreen>
    with TickerProviderStateMixin {
  final _countryCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _locationFocusNode = FocusNode();
  final _mapController = MapController();
  AnimationController? _mapAnim;

  bool _loading = true;
  bool _saving = false;
  bool _addingLocation = false;

  String _startDate = '';
  String _endDate = '';
  List<DayModel> _itinerary = [];
  String? _activeDate;

  @override
  void initState() {
    super.initState();
    _loadTrip();
  }

  @override
  void dispose() {
    _countryCtrl.dispose();
    _locationCtrl.dispose();
    _locationFocusNode.dispose();
    _mapController.dispose();
    _mapAnim?.dispose();
    super.dispose();
  }

  void _animateTo(LatLng target, double zoom) {
    _mapAnim?.dispose();
    LatLng startCenter;
    double startZoom;
    try {
      startCenter = _mapController.camera.center;
      startZoom = _mapController.camera.zoom;
    } catch (_) {
      _mapController.move(target, zoom);
      return;
    }
    _mapAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    final curved =
        CurvedAnimation(parent: _mapAnim!, curve: Curves.easeInOutCubic);
    final latTween =
        Tween<double>(begin: startCenter.latitude, end: target.latitude);
    final lngTween =
        Tween<double>(begin: startCenter.longitude, end: target.longitude);
    final zoomTween = Tween<double>(begin: startZoom, end: zoom);
    _mapAnim!.addListener(() {
      _mapController.move(
        LatLng(latTween.evaluate(curved), lngTween.evaluate(curved)),
        zoomTween.evaluate(curved),
      );
    });
    _mapAnim!.forward();
  }

  Future<void> _loadTrip() async {
    try {
      final repo = ref.read(tripRepositoryProvider);
      final trip = await repo.getTripById(widget.tripId);
      setState(() {
        _countryCtrl.text = trip.country;
        _startDate = trip.startDate;
        _endDate = trip.endDate;
        _itinerary = List.from(trip.days);
        _activeDate = trip.days.isNotEmpty ? trip.days.first.date : null;
        _loading = false;
      });
      // Defer map pan until after FlutterMap has rendered and attached the controller.
      WidgetsBinding.instance.addPostFrameCallback((_) => _panToActiveDay());
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) AppSnackbar.error(context, 'Failed to load trip: $e');
    }
  }

  void _panToActiveDay() {
    if (_activeDate == null) return;
    try {
      final day = _itinerary.firstWhere((d) => d.date == _activeDate);
      if (day.locations.isNotEmpty) {
        _animateTo(LatLng(day.locations.first.lat, day.locations.first.lng), 13);
      }
    } catch (_) {}
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
      final data =
          jsonDecode(res.data is String ? res.data : jsonEncode(res.data))
              as List?;
      if (data != null && data.isNotEmpty) {
        return LatLng(
            double.parse(data[0]['lat']), double.parse(data[0]['lon']));
      }
    } catch (_) {}
    return const LatLng(48.8566, 2.3522);
  }

  Future<void> _addLocation() async {
    if (_locationCtrl.text.trim().isEmpty || _activeDate == null) return;
    setState(() => _addingLocation = true);
    final coords =
        await _geocode('${_locationCtrl.text.trim()}, ${_countryCtrl.text}');
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
    _animateTo(coords, 13);
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
      if (mounted) {
        AppSnackbar.success(context, 'Trip updated!');
        context.go('/trips/${widget.tripId}');
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, 'Failed to update: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  DayModel? get _activeDay {
    try {
      return _itinerary.firstWhere((d) => d.date == _activeDate);
    } catch (_) {
      return null;
    }
  }

  int get _totalStops =>
      _itinerary.fold(0, (s, d) => s + d.locations.length);

  List<Marker> get _markers {
    final all = _itinerary.expand((d) => d.locations).toList();
    return all.asMap().entries.map((e) {
      final loc = e.value;
      final ownerDay = _itinerary.firstWhere(
        (d) => d.locations.any((l) => l.id == loc.id),
        orElse: () => DayModel(date: '', locations: []),
      );
      return Marker(
        point: LatLng(loc.lat, loc.lng),
        width: 38,
        height: 38,
        child: GestureDetector(
          onTap: () {
            if (ownerDay.date.isNotEmpty) {
              setState(() => _activeDate = ownerDay.date);
            }
            _animateTo(LatLng(loc.lat, loc.lng), 15);
          },
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_kBlue, _kCyan],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _kBlue.withAlpha(128),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Text(
                '${e.key + 1}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  LatLng get _mapCenter {
    final all = _itinerary.expand((d) => d.locations).toList();
    if (all.isEmpty) return const LatLng(20, 0);
    return LatLng(all.first.lat, all.first.lng);
  }

  String _fmtDayTab(DateTime dt) {
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${m[dt.month - 1]}';
  }

  void _handleVerticalDrag(DragEndDetails details) {
    if (details.primaryVelocity != null && details.primaryVelocity! > 800) {
      context.canPop() ? context.pop() : context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: _kBlue)),
      );
    }

    final destination = _countryCtrl.text.trim();
    final hasDates = _startDate.isNotEmpty && _endDate.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Full-screen map ────────────────────────────────────────────
          RepaintBoundary(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _mapCenter,
                initialZoom: _totalStops > 0 ? 10 : 2,
                backgroundColor: const Color(0xFFECEFF1),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.smart_travel_planner',
                  tileProvider: CachedTileProvider(),
                  keepBuffer: 4,
                  panBuffer: 1,
                  maxNativeZoom: 19,
                ),
                MarkerLayer(markers: _markers),
              ],
            ),
          ),

          // ── Back button overlaid on map ────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            child: _MapPillButton(
              icon: Icons.arrow_back_rounded,
              label: 'Back',
              onTap: () => context.canPop()
                  ? context.pop()
                  : context.go('/trips/${widget.tripId}'),
            ),
          ),

          // ── Draggable bottom sheet ─────────────────────────────────────
          DraggableScrollableSheet(
            initialChildSize: 0.65,
            minChildSize: 0.35,
            maxChildSize: 0.95,
            builder: (_, scrollCtrl) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x20000000),
                    blurRadius: 20,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Drag handle
                  GestureDetector(
                    onVerticalDragEnd: _handleVerticalDrag,
                    child: Container(
                      padding: const EdgeInsets.only(top: 12, bottom: 6),
                      child: Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Scrollable form content
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollCtrl,
                      padding:
                          const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Sheet header
                          _buildSheetHeader(destination),

                          // Destination
                          const _SectionHeader(
                            icon: Icons.flight_takeoff_outlined,
                            label: 'Destination',
                          ),
                          const SizedBox(height: 10),
                          _StyledInput(
                            controller: _countryCtrl,
                            hint: 'e.g. Japan, Paris, Bali...',
                            icon: Icons.public,
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 20),

                          // Dates
                          const _SectionHeader(
                            icon: Icons.calendar_month_outlined,
                            label: 'Travel dates',
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _DateCard(
                                  label: 'Depart',
                                  value: _startDate,
                                  onChanged: (d) {
                                    setState(() => _startDate = d);
                                    if (_endDate.isNotEmpty) {
                                      _rebuildItinerary(d, _endDate);
                                    }
                                  },
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8),
                                child: Icon(Icons.arrow_forward,
                                    size: 16, color: Colors.grey[400]),
                              ),
                              Expanded(
                                child: _DateCard(
                                  label: 'Return',
                                  value: _endDate,
                                  onChanged: (d) {
                                    setState(() => _endDate = d);
                                    if (_startDate.isNotEmpty) {
                                      _rebuildItinerary(_startDate, d);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          if (hasDates) ...[
                            const SizedBox(height: 10),
                            _DurationChip(
                                start: _startDate, end: _endDate),
                          ],

                          // Itinerary
                          if (_itinerary.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            const _SectionHeader(
                              icon: Icons.route_outlined,
                              label: 'Itinerary',
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 80,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _itinerary.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (_, i) {
                                  final day = _itinerary[i];
                                  final isActive =
                                      day.date == _activeDate;
                                  final dt = DateTime.parse(day.date);
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() => _activeDate = day.date);
                                      _panToActiveDay();
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                          milliseconds: 220),
                                      curve: Curves.easeOutCubic,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        gradient: isActive
                                            ? const LinearGradient(
                                                colors: [_kBlue, _kCyan],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              )
                                            : null,
                                        color:
                                            isActive ? null : _kInputFill,
                                        borderRadius:
                                            BorderRadius.circular(16),
                                        border: isActive
                                            ? null
                                            : Border.all(
                                                color: _kInputBorder,
                                                width: 1),
                                        boxShadow: isActive
                                            ? [
                                                BoxShadow(
                                                  color:
                                                      _kBlue.withAlpha(97),
                                                  blurRadius: 12,
                                                  offset:
                                                      const Offset(0, 4),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Day ${i + 1}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: isActive
                                                  ? Colors.white
                                                  : _kDark,
                                            ),
                                          ),
                                          Text(
                                            _fmtDayTab(dt),
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: isActive
                                                  ? Colors.white70
                                                  : Colors.grey[500],
                                            ),
                                          ),
                                          if (day.locations.isNotEmpty)
                                            Container(
                                              margin: const EdgeInsets
                                                  .only(top: 4),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 1),
                                              decoration: BoxDecoration(
                                                color: isActive
                                                    ? Colors.white
                                                        .withAlpha(64)
                                                    : _kBlue.withAlpha(31),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        8),
                                              ),
                                              child: Text(
                                                '${day.locations.length} ●',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight:
                                                      FontWeight.w700,
                                                  color: isActive
                                                      ? Colors.white
                                                      : _kBlue,
                                                ),
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
                            ..._activeDay!.locations
                                .asMap()
                                .entries
                                .map((e) => _LocationCard(
                                      key: ValueKey(e.value.id),
                                      index: e.key,
                                      location: e.value,
                                      onDelete: () =>
                                          _removeLocation(e.value.id),
                                      onNoteChanged: (v) =>
                                          _updateNote(e.value.id, v),
                                      onPan: () => _animateTo(
                                        LatLng(e.value.lat, e.value.lng),
                                        15,
                                      ),
                                    )),
                            const SizedBox(height: 8),
                            _AddLocationRow(
                              controller: _locationCtrl,
                              focusNode: _locationFocusNode,
                              isLoading: _addingLocation,
                              onAdd: _addLocation,
                            ),
                          ],

                          // Update button
                          if (_itinerary.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            _UpdateButton(
                              totalStops: _totalStops,
                              isSaving: _saving,
                              onSave: _save,
                            ),
                          ],
                          const SizedBox(height: 35),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSheetHeader(String destination) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _kBlue.withAlpha(26),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kBlue.withAlpha(64)),
            ),
            child:
                const Icon(Icons.edit_outlined, color: _kBlue, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  destination.isEmpty
                      ? 'Edit Trip'
                      : 'Edit: $destination',
                  style: const TextStyle(
                      color: _kDark,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3),
                ),
                Text(
                  _itinerary.isNotEmpty
                      ? '${_itinerary.length} day${_itinerary.length != 1 ? 's' : ''}  ·  $_totalStops stop${_totalStops != 1 ? 's' : ''}'
                      : 'Update your itinerary below',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Map overlay pill button ───────────────────────────────────────────────────

class _MapPillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MapPillButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2937).withAlpha(220),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(60),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section header (gradient icon + label) ────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_kBlue, _kCyan],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 14),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _kDark,
              letterSpacing: -0.2),
        ),
      ],
    );
  }
}

// ── Styled text input ─────────────────────────────────────────────────────────

class _StyledInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final FocusNode? focusNode;
  const _StyledInput({
    required this.controller,
    required this.hint,
    required this.icon,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: const TextStyle(fontSize: 15, color: _kDark),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
        prefixIcon: Container(
          margin: const EdgeInsets.all(10),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_kBlue, _kCyan]),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 14),
        ),
        filled: true,
        fillColor: _kInputFill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kInputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kInputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kBlue, width: 1.5),
        ),
      ),
    );
  }
}

// ── Date card ─────────────────────────────────────────────────────────────────

class _DateCard extends StatelessWidget {
  final String label;
  final String value;
  final void Function(String) onChanged;
  const _DateCard(
      {required this.label, required this.value, required this.onChanged});

  String _fmt(String iso) {
    final dt = DateTime.parse(iso);
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final hasDate = value.isNotEmpty;
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: hasDate ? DateTime.parse(value) : DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
        );
        if (picked != null) {
          onChanged(picked.toIso8601String().split('T').first);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: hasDate ? _kInputFill : Colors.grey[50],
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: hasDate ? _kInputBorder : Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                gradient: hasDate
                    ? const LinearGradient(colors: [_kBlue, _kCyan])
                    : null,
                color: hasDate ? null : Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.calendar_today,
                  size: 13,
                  color: hasDate ? Colors.white : Colors.grey[400]),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                        fontSize: 10,
                        color: hasDate ? _kBlue : Colors.grey[400],
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3),
                  ),
                  Text(
                    hasDate ? _fmt(value) : 'Select date',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: hasDate
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: hasDate ? _kDark : Colors.grey[400]),
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

// ── Duration chip ─────────────────────────────────────────────────────────────

class _DurationChip extends StatelessWidget {
  final String start, end;
  const _DurationChip({required this.start, required this.end});

  @override
  Widget build(BuildContext context) {
    final days =
        DateTime.parse(end).difference(DateTime.parse(start)).inDays + 1;
    return Center(
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_kBlue, _kCyan],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _kBlue.withAlpha(71),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wb_sunny_outlined,
                color: Colors.white, size: 14),
            const SizedBox(width: 6),
            Text(
              '$days day${days != 1 ? 's' : ''} trip',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Editable location card ────────────────────────────────────────────────────

class _LocationCard extends StatefulWidget {
  final int index;
  final LocationModel location;
  final VoidCallback onDelete;
  final void Function(String) onNoteChanged;
  final VoidCallback? onPan;
  const _LocationCard({
    super.key,
    required this.index,
    required this.location,
    required this.onDelete,
    required this.onNoteChanged,
    this.onPan,
  });

  @override
  State<_LocationCard> createState() => _LocationCardState();
}

class _LocationCardState extends State<_LocationCard> {
  late final TextEditingController _noteCtrl;

  @override
  void initState() {
    super.initState();
    _noteCtrl = TextEditingController(text: widget.location.note);
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4F0FF)),
        boxShadow: [
          BoxShadow(
            color: _kBlue.withAlpha(18),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_kBlue, _kCyan],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_kBlue, _kCyan],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _kBlue.withAlpha(89),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            '${widget.index + 1}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(widget.location.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: _kDark)),
                      ),
                      if (widget.onPan != null)
                        GestureDetector(
                          onTap: widget.onPan,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: _kBlue.withAlpha(20),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.my_location_rounded,
                                size: 14, color: _kBlue),
                          ),
                        ),
                      GestureDetector(
                        onTap: widget.onDelete,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFFF4444).withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.close,
                              size: 14, color: Color(0xFFFF4444)),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _noteCtrl,
                      onChanged: widget.onNoteChanged,
                      maxLines: 2,
                      style:
                          const TextStyle(fontSize: 13, color: _kDark),
                      decoration: InputDecoration(
                        hintText: 'Add a note about this stop...',
                        hintStyle: TextStyle(
                            fontSize: 12, color: Colors.grey[400]),
                        isDense: true,
                        filled: true,
                        fillColor: _kInputFill,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: _kInputBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: _kInputBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: _kBlue, width: 1.5),
                        ),
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

// ── Add location row ──────────────────────────────────────────────────────────

class _AddLocationRow extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;
  final VoidCallback onAdd;
  const _AddLocationRow({
    required this.controller,
    required this.focusNode,
    required this.isLoading,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: _StyledInput(
          controller: controller,
          focusNode: focusNode,
          hint: 'Search a place to add...',
          icon: Icons.search,
          onSubmitted: (_) => onAdd(),
        ),
      ),
      const SizedBox(width: 10),
      GestureDetector(
        onTap: isLoading ? null : onAdd,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: isLoading
                ? null
                : const LinearGradient(
                    colors: [_kBlue, _kCyan],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            color: isLoading ? Colors.grey[200] : null,
            borderRadius: BorderRadius.circular(14),
            boxShadow: isLoading
                ? null
                : [
                    BoxShadow(
                      color: _kBlue.withAlpha(97),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: isLoading
              ? const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: _kBlue),
                  ),
                )
              : const Icon(Icons.add, color: Colors.white, size: 22),
        ),
      ),
    ]);
  }
}

// ── Update button ─────────────────────────────────────────────────────────────

class _UpdateButton extends StatelessWidget {
  final int totalStops;
  final bool isSaving;
  final VoidCallback onSave;
  const _UpdateButton({
    required this.totalStops,
    required this.isSaving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final canSave = totalStops > 0 && !isSaving;
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: Container(
        decoration: BoxDecoration(
          gradient: canSave
              ? const LinearGradient(
                  colors: [Color(0xFF0369A1), _kBlue, _kCyan],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: canSave ? null : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
          boxShadow: canSave
              ? [
                  BoxShadow(
                    color: _kBlue.withAlpha(107),
                    blurRadius: 16,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: canSave ? onSave : null,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isSaving)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                else
                  Icon(
                    totalStops > 0
                        ? Icons.check_circle_outline
                        : Icons.info_outline,
                    color: canSave ? Colors.white : Colors.grey[400],
                    size: 20,
                  ),
                const SizedBox(width: 8),
                Text(
                  isSaving
                      ? 'Saving changes...'
                      : totalStops > 0
                          ? 'Update Trip  ·  $totalStops stop${totalStops != 1 ? 's' : ''}'
                          : 'Add stops to update',
                  style: TextStyle(
                    color: canSave ? Colors.white : Colors.grey[400],
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
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
