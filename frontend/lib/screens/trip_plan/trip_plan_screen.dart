// lib/screens/trip_plan/trip_plan_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/trip_model.dart';
import '../../repositories/trip_plan_repository.dart';
import '../../repositories/trip_repository.dart';
import '../../core/utils/snackbar.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _kBlue       = Color(0xFF3B82F6);
const _kCyan       = Color(0xFF06B6D4);
const _kDark       = Color(0xFF1F2937);
const _kDarkBlue   = Color(0xFF1E3A8A);
const _kInputFill  = Color(0xFFF0F9FF);
const _kInputBorder = Color(0xFFBAE6FD);

// ── Category meta ─────────────────────────────────────────────────────────────
const _categories = [
  (value: 'attraction', label: 'Attraction', icon: Icons.museum_outlined,    color: Color(0xFF3B82F6)),
  (value: 'restaurant', label: 'Restaurant', icon: Icons.restaurant_outlined, color: Color(0xFFEF4444)),
  (value: 'cafe',       label: 'Café',       icon: Icons.coffee_outlined,     color: Color(0xFF92400E)),
  (value: 'viewpoint',  label: 'Viewpoint',  icon: Icons.landscape_outlined,  color: Color(0xFF10B981)),
  (value: 'other',      label: 'Other',      icon: Icons.place_outlined,      color: Color(0xFF6B7280)),
];

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

  TripModel? _trip;
  List<Map<String, dynamic>> _sections = [];
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
      final trip =
          await ref.read(tripRepositoryProvider).getTripById(widget.tripId);
      if (!mounted) return;
      setState(() {
        _trip = trip;
        _titleCtrl.text = 'My Trip to ${trip.country}';
        _sections = _buildSections(trip);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppSnackbar.error(context, 'Failed to load trip: $e');
    }
  }

  List<Map<String, dynamic>> _buildSections(TripModel trip) {
    final list = <Map<String, dynamic>>[];
    list.add({
      'id': 'tips',
      'type': 'tips',
      'title': 'General Tips',
      'content': '',
      'notes': '',
      'route': <Map<String, dynamic>>[],
      'places': <Map<String, dynamic>>[],
      'listItems': <Map<String, dynamic>>[],
      'isOpen': true,
    });

    for (int i = 0; i < trip.days.length; i++) {
      final day = trip.days[i];
      final route = day.locations.asMap().entries.map((e) {
        final loc = e.value;
        return <String, dynamic>{
          'id': loc.id.isNotEmpty ? loc.id : 'stop_${i}_${e.key}',
          'name': loc.name, 'lat': loc.lat, 'lng': loc.lng, 'order': e.key,
        };
      }).toList();

      final places = day.locations.asMap().entries.map((e) {
        final loc = e.value;
        return <String, dynamic>{
          'order': e.key, 'name': loc.name,
          'description': loc.note.isNotEmpty ? loc.note : '',
          'lat': loc.lat, 'lng': loc.lng,
          'category': 'attraction',
          'address': loc.note.isNotEmpty ? loc.note : '',
        };
      }).toList();

      list.add({
        'id': 'day${i + 1}', 'type': 'day', 'title': 'Day ${i + 1}',
        'content': '', 'notes': '',
        'route': route, 'places': places,
        'listItems': <Map<String, dynamic>>[], 'isOpen': true,
      });
    }
    return list;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(tripPlanRepositoryProvider).createTripPlan(
            tripId: widget.tripId,
            title: _titleCtrl.text.trim(),
            authorIntro: _introCtrl.text.trim(),
            sections: _sections,
          );
      if (!mounted) return;
      AppSnackbar.success(context, 'Travel guide created! 🎉');
      context.go('/dashboard');
    } catch (e) {
      if (mounted) AppSnackbar.error(context, 'Failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF4F9FF),
        body: Center(child: CircularProgressIndicator(color: _kBlue)),
      );
    }
    final trip = _trip;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F9FF),
      appBar: _buildAppBar(context),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Trip summary banner ──────────────────────────────────
              if (trip != null) _TripBanner(trip: trip),
              const SizedBox(height: 24),

              // ── Step 1: Guide details ────────────────────────────────
              _StepCard(
                step: 1,
                title: 'Guide Details',
                icon: Icons.edit_note_rounded,
                child: Column(children: [
                  TextFormField(
                    controller: _titleCtrl,
                    maxLength: 80,
                    style: const TextStyle(fontSize: 15, color: _kDark),
                    decoration: _sysInput(
                      label: 'Guide Title *',
                      hint: 'e.g. 7 Days in Japan on a Budget',
                      icon: Icons.title_rounded,
                      counterText: '',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Title is required'
                        : null,
                    onChanged: (_) => setState(() {}),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${_titleCtrl.text.length}/80',
                        style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _introCtrl,
                    maxLines: 3,
                    maxLength: 200,
                    style: const TextStyle(fontSize: 15, color: _kDark),
                    decoration: _sysInput(
                      label: 'About You (optional)',
                      hint: 'e.g. Travel photographer, 40+ countries...',
                      icon: Icons.person_outline_rounded,
                      alignLabel: true,
                      counterText: '',
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 16),

              // ── Step 2: Sections ─────────────────────────────────────
              _StepCard(
                step: 2,
                title: 'Sections (${_sections.length})',
                icon: Icons.list_alt_rounded,
                subtitle:
                    'Expand each section to add place categories, notes and checklists.',
                child: Column(
                  children: _sections.asMap().entries.map((e) {
                    return _SectionSetupCard(
                      key: ValueKey(e.value['id']),
                      index: e.key,
                      section: e.value,
                      onSectionUpdated: (updated) =>
                          setState(() => _sections[e.key] = updated),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 28),

              // ── Publish button ───────────────────────────────────────
              _PublishButton(saving: _saving, onTap: _submit),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: _kBlue),
        onPressed: () =>
            context.canPop() ? context.pop() : context.go('/dashboard'),
      ),
      title: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_kBlue, _kCyan],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.auto_awesome_rounded,
              color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        const Text(
          'Create Travel Guide',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: _kDarkBlue,
          ),
        ),
      ]),
      centerTitle: false,
      backgroundColor: Colors.white,
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: Colors.grey[100]),
      ),
    );
  }
}

// ── System-styled input decoration ───────────────────────────────────────────

InputDecoration _sysInput({
  required String label,
  String? hint,
  required IconData icon,
  bool alignLabel = false,
  String? counterText,
}) =>
    InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
      counterText: counterText,
      prefixIcon: Container(
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          gradient:
              const LinearGradient(colors: [_kBlue, _kCyan]),
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      alignLabelWithHint: alignLabel,
    );

// ── Inner section input (lighter, for use inside section cards) ───────────────

InputDecoration _innerInput({
  required String label,
  String? hint,
  required IconData icon,
  Color? iconColor,
  bool alignLabel = false,
}) =>
    InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
      prefixIcon:
          Icon(icon, size: 16, color: iconColor ?? Colors.grey[500]),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kInputBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kInputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kBlue, width: 1.5),
      ),
      alignLabelWithHint: alignLabel,
    );

// ── Trip summary banner ───────────────────────────────────────────────────────

class _TripBanner extends StatelessWidget {
  final TripModel trip;
  const _TripBanner({required this.trip});

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

  @override
  Widget build(BuildContext context) {
    final totalLocs = trip.days.fold(0, (s, d) => s + d.locations.length);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1D4ED8), Color(0xFF0891B2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _kBlue.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.flight_takeoff_rounded,
              color: Colors.white, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trip.country,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3),
              ),
              const SizedBox(height: 3),
              Text(
                '${_fmt(trip.startDate)}  –  ${_fmt(trip.endDate)}',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12),
              ),
              const SizedBox(height: 8),
              Row(children: [
                _BannerChip(
                    icon: Icons.calendar_today_outlined,
                    label: '${trip.days.length} day${trip.days.length == 1 ? '' : 's'}'),
                const SizedBox(width: 8),
                _BannerChip(
                    icon: Icons.place_outlined,
                    label: '$totalLocs place${totalLocs == 1 ? '' : 's'}'),
              ]),
            ],
          ),
        ),
      ]),
    );
  }
}

class _BannerChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _BannerChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: Colors.white),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ── Step card wrapper ─────────────────────────────────────────────────────────

class _StepCard extends StatelessWidget {
  final int step;
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget child;

  const _StepCard({
    required this.step,
    required this.title,
    required this.icon,
    required this.child,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(children: [
            // Gradient step circle
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [_kBlue, _kCyan]),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text('$step',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(width: 10),
            // Icon badge
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _kBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 16, color: _kBlue),
            ),
            const SizedBox(width: 10),
            Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _kDarkBlue)),
          ]),
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(58, 5, 16, 0),
            child: Text(subtitle!,
                style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          ),
        const SizedBox(height: 16),
        const Divider(height: 1, color: Color(0xFFF3F4F6)),
        Padding(padding: const EdgeInsets.all(16), child: child),
      ]),
    );
  }
}

// ── Section setup card ────────────────────────────────────────────────────────

class _SectionSetupCard extends StatefulWidget {
  final int index;
  final Map<String, dynamic> section;
  final ValueChanged<Map<String, dynamic>> onSectionUpdated;

  const _SectionSetupCard({
    super.key,
    required this.index,
    required this.section,
    required this.onSectionUpdated,
  });

  @override
  State<_SectionSetupCard> createState() => _SectionSetupCardState();
}

class _SectionSetupCardState extends State<_SectionSetupCard>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _contentCtrl;
  late List<Map<String, dynamic>> _places;
  late List<Map<String, dynamic>> _listItems;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(
        text: widget.section['title'] as String? ?? '');
    _notesCtrl = TextEditingController(
        text: widget.section['notes'] as String? ?? '');
    _contentCtrl = TextEditingController(
        text: widget.section['content'] as String? ?? '');

    _places = _copyList(widget.section['places']);
    _listItems = _copyList(widget.section['listItems']);

    _titleCtrl.addListener(_notify);
    _notesCtrl.addListener(_notify);
    _contentCtrl.addListener(_notify);
  }

  List<Map<String, dynamic>> _copyList(dynamic raw) =>
      (raw is List)
          ? raw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : [];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  void _notify() {
    widget.onSectionUpdated({
      ...widget.section,
      'title': _titleCtrl.text,
      'notes': _notesCtrl.text,
      'content': _contentCtrl.text,
      'places': _places,
      'listItems': _listItems,
    });
  }

  void _setPlaceCategory(int i, String cat) {
    setState(() => _places[i]['category'] = cat);
    _notify();
  }

  void _setPlaceDescription(int i, String desc) {
    setState(() => _places[i]['description'] = desc);
    _notify();
  }

  void _addListItem(String type) {
    setState(() => _listItems.add({
          'order': _listItems.length,
          'text': '',
          'type': type,
          'checked': false,
        }));
    _notify();
  }

  void _removeListItem(int i) {
    setState(() {
      _listItems.removeAt(i);
      for (int j = 0; j < _listItems.length; j++) {
        _listItems[j]['order'] = j;
      }
    });
    _notify();
  }

  void _setListItemText(int i, String text) {
    setState(() => _listItems[i]['text'] = text);
    _notify();
  }

  void _toggleChecked(int i) {
    setState(() => _listItems[i]['checked'] =
        !(_listItems[i]['checked'] as bool? ?? false));
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.section['type'] as String? ?? 'day';
    final isTips = type == 'tips';
    final listCount = _listItems.length;
    final placeCount = _places.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _expanded ? _kBlue : const Color(0xFFE5E7EB),
          width: _expanded ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _expanded ? 0.06 : 0.03),
            blurRadius: _expanded ? 14 : 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(children: [
          // ── Collapsed header ───────────────────────────────────────
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              child: Row(children: [
                // Section type icon
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: isTips
                        ? const LinearGradient(
                            colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : const LinearGradient(
                            colors: [_kBlue, _kCyan],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isTips
                        ? Icons.lightbulb_rounded
                        : Icons.calendar_today_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _titleCtrl.text.isNotEmpty
                            ? _titleCtrl.text
                            : (widget.section['title'] as String? ?? ''),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: _kDark),
                      ),
                      if (!isTips && _places.isNotEmpty)
                        Text(
                          '${_places.length} place${_places.length == 1 ? '' : 's'}',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[500]),
                        ),
                    ],
                  ),
                ),
                // Summary badges
                if (placeCount > 0) ...[
                  _Badge(
                      label: '$placeCount place${placeCount > 1 ? 's' : ''}',
                      bg: const Color(0xFFDBEAFE),
                      fg: _kBlue),
                  const SizedBox(width: 4),
                ],
                if (listCount > 0) ...[
                  _Badge(
                      label: '$listCount item${listCount > 1 ? 's' : ''}',
                      bg: const Color(0xFFEDE9FE),
                      fg: const Color(0xFF7C3AED)),
                  const SizedBox(width: 4),
                ],
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: _expanded ? _kBlue : Colors.grey[400],
                  ),
                ),
              ]),
            ),
          ),

          // ── Expanded content ───────────────────────────────────────
          if (_expanded) ...[
            Container(height: 1, color: _kBlue.withValues(alpha: 0.15)),
            Container(
              color: const Color(0xFFF8FAFF),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section title
                  TextField(
                    controller: _titleCtrl,
                    style: const TextStyle(fontSize: 14, color: _kDark),
                    decoration: _innerInput(
                      label: 'Section title',
                      icon: Icons.edit_outlined,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Notes / content
                  if (!isTips)
                    TextField(
                      controller: _notesCtrl,
                      maxLines: 3,
                      style: const TextStyle(fontSize: 14, color: _kDark),
                      decoration: _innerInput(
                        label: 'Day notes (optional)',
                        hint: 'Highlights, what to expect, travel tips...',
                        icon: Icons.notes_outlined,
                        alignLabel: true,
                      ),
                    )
                  else
                    TextField(
                      controller: _contentCtrl,
                      maxLines: 4,
                      style: const TextStyle(fontSize: 14, color: _kDark),
                      decoration: _innerInput(
                        label: 'General tips',
                        hint:
                            'Currency, transport, packing, etiquette...',
                        icon: Icons.lightbulb_outline,
                        iconColor: const Color(0xFFF59E0B),
                        alignLabel: true,
                      ),
                    ),

                  // ── Places ─────────────────────────────────────────
                  if (!isTips && _places.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _InnerLabel(
                        icon: Icons.place_outlined,
                        label: 'Places (${_places.length})'),
                    const SizedBox(height: 8),
                    ..._places.asMap().entries.map((e) => _PlaceEditor(
                          index: e.key,
                          place: e.value,
                          onCategoryChanged: (c) =>
                              _setPlaceCategory(e.key, c),
                          onDescriptionChanged: (d) =>
                              _setPlaceDescription(e.key, d),
                        )),
                  ],

                  // ── List items ─────────────────────────────────────
                  const SizedBox(height: 16),
                  _InnerLabel(
                    icon: Icons.checklist_rounded,
                    label: 'List Items (${_listItems.length})',
                  ),
                  const SizedBox(height: 8),
                  if (_listItems.isNotEmpty)
                    ..._listItems.asMap().entries.map((e) => _ListItemRow(
                          index: e.key,
                          item: e.value,
                          onTextChanged: (t) =>
                              _setListItemText(e.key, t),
                          onToggleChecked: () => _toggleChecked(e.key),
                          onRemove: () => _removeListItem(e.key),
                        )),
                  const SizedBox(height: 4),
                  Row(children: [
                    _AddItemButton(
                      icon: Icons.check_box_outlined,
                      label: 'Checklist',
                      onTap: () => _addListItem('checklist'),
                    ),
                    const SizedBox(width: 8),
                    _AddItemButton(
                      icon: Icons.text_fields,
                      label: 'Text',
                      onTap: () => _addListItem('text'),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

// ── Place editor ──────────────────────────────────────────────────────────────

class _PlaceEditor extends StatefulWidget {
  final int index;
  final Map<String, dynamic> place;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onDescriptionChanged;

  const _PlaceEditor({
    required this.index,
    required this.place,
    required this.onCategoryChanged,
    required this.onDescriptionChanged,
  });

  @override
  State<_PlaceEditor> createState() => _PlaceEditorState();
}

class _PlaceEditorState extends State<_PlaceEditor> {
  late final TextEditingController _descCtrl;

  @override
  void initState() {
    super.initState();
    _descCtrl = TextEditingController(
        text: widget.place['description'] as String? ?? '');
    _descCtrl.addListener(
        () => widget.onDescriptionChanged(_descCtrl.text));
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.place['name'] as String? ?? '';
    final currentCat = widget.place['category'] as String? ?? 'attraction';
    final catMeta = _categories.firstWhere(
      (c) => c.value == currentCat,
      orElse: () => _categories.first,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4F0FF)),
        boxShadow: [
          BoxShadow(
            color: _kBlue.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Gradient left bar
          Container(
            width: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [catMeta.color, catMeta.color.withValues(alpha: 0.5)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                bottomLeft: Radius.circular(14),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Place name + number
                  Row(children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: catMeta.color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${widget.index + 1}',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: catMeta.color),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: _kDark),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),

                  // Category selector
                  Row(children: [
                    Text('Category:',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[500])),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: catMeta.color.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color:
                                    catMeta.color.withValues(alpha: 0.25)),
                          ),
                          child: DropdownButton<String>(
                            value: currentCat,
                            isDense: true,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: catMeta.color),
                            dropdownColor: Colors.white,
                            icon: Icon(Icons.arrow_drop_down,
                                size: 18, color: catMeta.color),
                            items: _categories.map((c) {
                              return DropdownMenuItem(
                                value: c.value,
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(c.icon,
                                          size: 14, color: c.color),
                                      const SizedBox(width: 6),
                                      Text(c.label,
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: c.color)),
                                    ]),
                              );
                            }).toList(),
                            onChanged: (v) {
                              if (v != null) widget.onCategoryChanged(v);
                            },
                          ),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),

                  // Description
                  TextField(
                    controller: _descCtrl,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 13, color: _kDark),
                    decoration: InputDecoration(
                      labelText: 'Description (optional)',
                      hintText: 'What makes this place special...',
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: _kInputBorder)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: _kInputBorder)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: _kBlue, width: 1.5)),
                      filled: true,
                      fillColor: _kInputFill,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── List item row ─────────────────────────────────────────────────────────────

class _ListItemRow extends StatefulWidget {
  final int index;
  final Map<String, dynamic> item;
  final ValueChanged<String> onTextChanged;
  final VoidCallback onToggleChecked;
  final VoidCallback onRemove;

  const _ListItemRow({
    required this.index,
    required this.item,
    required this.onTextChanged,
    required this.onToggleChecked,
    required this.onRemove,
  });

  @override
  State<_ListItemRow> createState() => _ListItemRowState();
}

class _ListItemRowState extends State<_ListItemRow> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: widget.item['text'] as String? ?? '');
    _ctrl.addListener(() => widget.onTextChanged(_ctrl.text));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isChecklist = widget.item['type'] == 'checklist';
    final checked = widget.item['checked'] as bool? ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
        // Leading: checkbox or bullet
        GestureDetector(
          onTap: isChecklist ? widget.onToggleChecked : null,
          child: SizedBox(
            width: 28,
            height: 28,
            child: Center(
              child: isChecklist
                  ? Icon(
                      checked
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 20,
                      color: checked ? _kBlue : Colors.grey[350],
                    )
                  : Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [_kBlue, _kCyan]),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(width: 6),

        // Text field
        Expanded(
          child: TextField(
            controller: _ctrl,
            decoration: InputDecoration(
              hintText:
                  isChecklist ? 'Checklist item...' : 'Text item...',
              hintStyle:
                  TextStyle(fontSize: 13, color: Colors.grey[400]),
              isDense: true,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 4),
            ),
            style: TextStyle(
              fontSize: 13,
              color: checked ? Colors.grey[400] : _kDark,
              decoration:
                  checked ? TextDecoration.lineThrough : null,
            ),
          ),
        ),

        // Type chip
        Container(
          margin: const EdgeInsets.only(left: 6),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: isChecklist
                ? const Color(0xFFDBEAFE)
                : const Color(0xFFEDE9FE),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            isChecklist ? 'check' : 'text',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: isChecklist ? _kBlue : const Color(0xFF7C3AED),
            ),
          ),
        ),

        // Remove
        GestureDetector(
          onTap: widget.onRemove,
          child: Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.close_rounded,
                  size: 13, color: Color(0xFFDC2626)),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Publish button ────────────────────────────────────────────────────────────

class _PublishButton extends StatelessWidget {
  final bool saving;
  final VoidCallback onTap;
  const _PublishButton({required this.saving, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Container(
        decoration: BoxDecoration(
          gradient: saving
              ? null
              : const LinearGradient(
                  colors: [Color(0xFF0369A1), _kBlue, _kCyan],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
          color: saving ? Colors.grey[200] : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: saving
              ? null
              : [
                  BoxShadow(
                    color: _kBlue.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 5),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: saving ? null : onTap,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (saving)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                else
                  const Icon(Icons.publish_rounded,
                      color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(
                  saving ? 'Creating guide...' : 'Publish Travel Guide',
                  style: TextStyle(
                    color: saving ? Colors.grey[400] : Colors.white,
                    fontSize: 16,
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

// ── Small helpers ─────────────────────────────────────────────────────────────

class _InnerLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InnerLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 4,
        height: 16,
        decoration: BoxDecoration(
          color: _kBlue,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Icon(icon, size: 14, color: _kBlue),
      const SizedBox(width: 5),
      Text(label,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _kDarkBlue)),
    ]);
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color bg, fg;
  const _Badge({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, color: fg, fontWeight: FontWeight.w600)),
    );
  }
}

class _AddItemButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _AddItemButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _kInputFill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kBlue.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: _kBlue),
          const SizedBox(width: 5),
          Text('+ $label',
              style: const TextStyle(
                  fontSize: 12,
                  color: _kBlue,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}
