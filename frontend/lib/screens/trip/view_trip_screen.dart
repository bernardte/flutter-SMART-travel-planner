// lib/screens/trip/view_trip_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../repositories/trip_repository.dart';
import '../../models/trip_model.dart';
import '../../core/utils/cached_tile_provider.dart';

// ── Design tokens (matches plan_trip_screen) ──────────────────────────────────
const _kBlue = Color(0xFF3B82F6);
const _kCyan = Color(0xFF06B6D4);
const _kDark = Color(0xFF1F2937);
const _kInputFill = Color(0xFFF0F9FF);
const _kInputBorder = Color(0xFFBAE6FD);

class ViewTripScreen extends ConsumerStatefulWidget {
  final String tripId;
  const ViewTripScreen({super.key, required this.tripId});

  @override
  ConsumerState<ViewTripScreen> createState() => _ViewTripScreenState();
}

class _ViewTripScreenState extends ConsumerState<ViewTripScreen>
    with TickerProviderStateMixin {
  TripModel? _trip;
  bool _loading = true;
  String? _error;
  String? _activeDate;
  final _mapController = MapController();
  AnimationController? _mapAnim;

  @override
  void initState() {
    super.initState();
    _loadTrip();
  }

  @override
  void dispose() {
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
        _trip = trip;
        _activeDate = trip.days.isNotEmpty ? trip.days.first.date : null;
        _loading = false;
      });
      // Defer map pan until after FlutterMap has rendered and attached the controller.
      WidgetsBinding.instance.addPostFrameCallback((_) => _panToActiveDay());
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _panToActiveDay() {
    if (_trip == null || _activeDate == null) return;
    final day = _trip!.days.firstWhere(
      (d) => d.date == _activeDate,
      orElse: () => DayModel(date: '', locations: []),
    );
    if (day.locations.isNotEmpty) {
      final loc = day.locations.first;
      _animateTo(LatLng(loc.lat, loc.lng), 13);
    }
  }

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

  String _fmtTab(DateTime dt) {
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${m[dt.month - 1]}';
  }

  List<Marker> get _markers {
    if (_trip == null) return [];
    final all = _trip!.days.expand((d) => d.locations).toList();
    return all.asMap().entries.map((e) {
      final loc = e.value;
      // Find which day owns this location so we can activate the right tab.
      final ownerDay = _trip!.days.firstWhere(
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
    if (_trip == null) return const LatLng(20, 0);
    final all = _trip!.days.expand((d) => d.locations).toList();
    if (all.isEmpty) return const LatLng(20, 0);
    return LatLng(all.first.lat, all.first.lng);
  }

  DayModel? get _activeDay {
    if (_trip == null) return null;
    try {
      return _trip!.days.firstWhere((d) => d.date == _activeDate);
    } catch (_) {
      return null;
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
    if (_error != null || _trip == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, color: Colors.white60, size: 48),
            const SizedBox(height: 12),
            Text(_error ?? 'Trip not found',
                style: const TextStyle(color: Colors.white60)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/dashboard'),
              child: const Text('Go back'),
            ),
          ]),
        ),
      );
    }

    final trip = _trip!;
    final totalLocs = trip.days.fold(0, (s, d) => s + d.locations.length);
    final hasMap = totalLocs > 0;

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
                initialZoom: hasMap ? 10 : 2,
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

          // ── Map overlay buttons ────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            child: _MapPillButton(
              icon: Icons.arrow_back_rounded,
              label: 'Back',
              onTap: () =>
                  context.canPop() ? context.pop() : context.go('/dashboard'),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 16,
            child: _MapPillButton(
              icon: Icons.edit_outlined,
              label: 'Edit',
              onTap: () => context.go('/trips/${trip.id}/edit'),
              color: _kBlue,
            ),
          ),

          // ── Draggable bottom sheet ────────────────────────────────────
          DraggableScrollableSheet(
            initialChildSize: 0.55,
            minChildSize: 0.25,
            maxChildSize: 0.93,
            builder: (_, scrollCtrl) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x30000000),
                    blurRadius: 20,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Drag handle
                  Container(
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

                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Trip header ──────────────────────────────
                          _TripViewHeader(
                            country: trip.country,
                            startDate: _fmt(trip.startDate),
                            endDate: _fmt(trip.endDate),
                            days: trip.days.length,
                            places: totalLocs,
                          ),
                          const SizedBox(height: 20),

                          // ── Day tabs ─────────────────────────────────
                          if (trip.days.isNotEmpty) ...[
                            const _SheetSectionHeader(
                              icon: Icons.route_outlined,
                              label: 'Itinerary',
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 80,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: trip.days.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (_, i) {
                                  final day = trip.days[i];
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
                                        color: isActive ? null : _kInputFill,
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
                                                  color: _kBlue.withAlpha(97),
                                                  blurRadius: 12,
                                                  offset: const Offset(0, 4),
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
                                            _fmtTab(dt),
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: isActive
                                                  ? Colors.white70
                                                  : Colors.grey[500],
                                            ),
                                          ),
                                          if (day.locations.isNotEmpty)
                                            Container(
                                              margin: const EdgeInsets.only(
                                                  top: 4),
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
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                '${day.locations.length} ●',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w700,
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
                            const SizedBox(height: 16),
                          ],

                          // ── Locations for active day ─────────────────
                          if (_activeDay != null) ...[
                            if (_activeDay!.locations.isEmpty)
                              _EmptyDay()
                            else
                              ..._activeDay!.locations.asMap().entries.map(
                                (e) => _ViewLocationTile(
                                  key: ValueKey(e.value.id),
                                  index: e.key,
                                  location: e.value,
                                  onTap: () => _animateTo(
                                    LatLng(e.value.lat, e.value.lng),
                                    15,
                                  ),
                                ),
                              ),
                          ],
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
}

// ── Map overlay pill button ───────────────────────────────────────────────────

class _MapPillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _MapPillButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color ?? const Color(0xFF1F2937);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: bg.withAlpha(220),
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

// ── Trip view header ──────────────────────────────────────────────────────────

class _TripViewHeader extends StatelessWidget {
  final String country, startDate, endDate;
  final int days, places;
  const _TripViewHeader({
    required this.country,
    required this.startDate,
    required this.endDate,
    required this.days,
    required this.places,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_kBlue, _kCyan],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.travel_explore,
              color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Trip to $country',
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _kDark,
                    letterSpacing: -0.4),
              ),
              const SizedBox(height: 3),
              Text(
                '$startDate – $endDate',
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _StatPill(
                      icon: Icons.calendar_today_outlined,
                      label: '$days day${days == 1 ? '' : 's'}'),
                  const SizedBox(width: 8),
                  _StatPill(
                      icon: Icons.place_outlined,
                      label: '$places place${places == 1 ? '' : 's'}'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _kInputFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kInputBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: _kBlue),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _kBlue)),
        ],
      ),
    );
  }
}

// ── Sheet section header (gradient icon + label) ──────────────────────────────

class _SheetSectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SheetSectionHeader({required this.icon, required this.label});

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
                end: Alignment.bottomRight),
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

// ── View-only location tile ───────────────────────────────────────────────────

class _ViewLocationTile extends StatelessWidget {
  final int index;
  final LocationModel location;
  final VoidCallback? onTap;
  const _ViewLocationTile(
      {super.key, required this.index, required this.location, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
            // Gradient left bar
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
                padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Circle number
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
                          '${index + 1}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            location.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: _kDark),
                          ),
                          if (location.note.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              location.note,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                  height: 1.4),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${location.lat.toStringAsFixed(3)},\n${location.lng.toStringAsFixed(3)}',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),   // closes Container
  );     // closes GestureDetector
  }
}

// ── Empty day placeholder ─────────────────────────────────────────────────────

class _EmptyDay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: _kInputFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kInputBorder),
      ),
      child: Column(
        children: [
          Icon(Icons.place_outlined, color: Colors.grey[400], size: 32),
          const SizedBox(height: 8),
          Text(
            'No locations added for this day',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
