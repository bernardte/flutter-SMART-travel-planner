// lib/screens/trip_plan/trip_plan_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/trip_model.dart';
import '../../repositories/trip_plan_repository.dart';
import '../../repositories/trip_repository.dart';
import '../../core/utils/snackbar.dart';

// ── Category meta (mirrors CategoryItem enum in section.model.ts) ─────────────
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

    // Tips section — type:"tips" (ITipsSection)
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

      // IRouteStop: id, name, lat, lng, order
      final route = day.locations.asMap().entries.map((e) {
        final loc = e.value;
        return <String, dynamic>{
          'id': loc.id.isNotEmpty ? loc.id : 'stop_${i}_${e.key}',
          'name': loc.name,
          'lat': loc.lat,
          'lng': loc.lng,
          'order': e.key,
        };
      }).toList();

      // IPlace: order, name, description, lat, lng, category (enum), address
      final places = day.locations.asMap().entries.map((e) {
        final loc = e.value;
        return <String, dynamic>{
          'order': e.key,
          'name': loc.name,
          'description': loc.note.isNotEmpty ? loc.note : '',
          'lat': loc.lat,
          'lng': loc.lng,
          'category': 'attraction', // default; user can change in the card
          'address': loc.note.isNotEmpty ? loc.note : '',
        };
      }).toList();

      list.add({
        'id': 'day${i + 1}',
        'type': 'day',
        'title': 'Day ${i + 1}',
        'content': '',
        'notes': '',
        'route': route,
        'places': places,
        'listItems': <Map<String, dynamic>>[],
        'isOpen': true,
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
          body: Center(child: CircularProgressIndicator()));
    }
    final trip = _trip;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F9FF),
      appBar: AppBar(
        title: const Text('Create Travel Guide'),
        backgroundColor: const Color(0xFF1D4ED8),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/dashboard'),
        ),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Trip summary banner ──────────────────────────────
              if (trip != null) _TripBanner(trip: trip),
              const SizedBox(height: 20),

              // ── Step 1: Guide details ────────────────────────────
              _StepCard(
                step: 1,
                title: 'Guide Details',
                icon: Icons.edit_note_rounded,
                child: Column(children: [
                  TextFormField(
                    controller: _titleCtrl,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      labelText: 'Guide Title *',
                      hintText: 'e.g. 7 Days in Japan on a Budget',
                      prefixIcon: Icon(Icons.title),
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Title is required'
                        : null,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text('${_titleCtrl.text.length}/80',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[400])),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _introCtrl,
                    maxLines: 3,
                    maxLength: 200,
                    decoration: const InputDecoration(
                      labelText: 'About You (optional)',
                      hintText:
                          'e.g. Travel photographer, 40+ countries...',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                      counterText: '',
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 16),

              // ── Step 2: Sections ─────────────────────────────────
              _StepCard(
                step: 2,
                title: 'Sections (${_sections.length})',
                icon: Icons.list_alt_rounded,
                subtitle:
                    'Expand to set place categories, add notes, and build checklists.',
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

              // ── Publish button ───────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.publish_rounded, size: 20),
                  label: Text(
                    _saving ? 'Creating...' : 'Publish Travel Guide',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
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

// ── Trip banner ───────────────────────────────────────────────────────────────

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
    final totalLocations =
        trip.days.fold(0, (sum, d) => sum + d.locations.length);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1D4ED8), Color(0xFF0891B2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.flight_takeoff_rounded,
              color: Colors.white, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(trip.country,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('${_fmt(trip.startDate)} – ${_fmt(trip.endDate)}',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12)),
              const SizedBox(height: 4),
              Row(children: [
                _BannerChip(
                    icon: Icons.calendar_today,
                    label: '${trip.days.length} days'),
                const SizedBox(width: 8),
                _BannerChip(
                    icon: Icons.place,
                    label: '$totalLocations locations'),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: Colors.white),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(color: Colors.white, fontSize: 11)),
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(children: [
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                  color: Color(0xFF3B82F6), shape: BoxShape.circle),
              child: Center(
                child: Text('$step',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 10),
            Icon(icon, size: 18, color: const Color(0xFF3B82F6)),
            const SizedBox(width: 6),
            Text(title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A))),
          ]),
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(54, 4, 16, 0),
            child: Text(subtitle!,
                style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          ),
        const SizedBox(height: 12),
        const Divider(height: 1),
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

class _SectionSetupCardState extends State<_SectionSetupCard> {
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

  // ── Place helpers ──────────────────────────────────────────────────
  void _setPlaceCategory(int i, String cat) {
    setState(() => _places[i]['category'] = cat);
    _notify();
  }

  void _setPlaceDescription(int i, String desc) {
    setState(() => _places[i]['description'] = desc);
    _notify();
  }

  // ── List-item helpers ──────────────────────────────────────────────
  void _addListItem(String type) {
    setState(() => _listItems.add({
          'order': _listItems.length,
          'text': '',
          'type': type,   // "text" | "checklist"
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
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _expanded ? const Color(0xFF3B82F6) : Colors.grey[200]!,
          width: _expanded ? 1.5 : 1,
        ),
      ),
      child: Column(children: [
        // ── Collapsed header ───────────────────────────────────────
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isTips ? Colors.amber[50] : Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isTips ? Icons.lightbulb_outline : Icons.map_outlined,
                  size: 16,
                  color: isTips ? Colors.amber[700] : Colors.blue[600],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _titleCtrl.text.isNotEmpty
                      ? _titleCtrl.text
                      : (widget.section['title'] as String? ?? ''),
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              // Summary badges
              if (placeCount > 0) ...[
                _Badge(
                    label: '$placeCount place${placeCount > 1 ? 's' : ''}',
                    color: Colors.blue),
                const SizedBox(width: 4),
              ],
              if (listCount > 0) ...[
                _Badge(
                    label: '$listCount item${listCount > 1 ? 's' : ''}',
                    color: Colors.purple),
                const SizedBox(width: 4),
              ],
              Icon(
                _expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: Colors.grey[400],
              ),
            ]),
          ),
        ),

        // ── Expanded content ───────────────────────────────────────
        if (_expanded) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section title (all types)
                TextField(
                  controller: _titleCtrl,
                  decoration: _inputDecor(
                    label: 'Section title',
                    icon: Icons.edit_outlined,
                  ),
                ),
                const SizedBox(height: 12),

                // Notes (day) or Content (tips)
                if (!isTips)
                  TextField(
                    controller: _notesCtrl,
                    maxLines: 3,
                    decoration: _inputDecor(
                      label: 'Day notes (optional)',
                      hint: 'Highlights, what to expect, travel tips...',
                      icon: Icons.notes_outlined,
                    ),
                  )
                else
                  TextField(
                    controller: _contentCtrl,
                    maxLines: 4,
                    decoration: _inputDecor(
                      label: 'General tips',
                      hint: 'Currency, transport, packing, etiquette...',
                      icon: Icons.lightbulb_outline,
                      iconColor: Colors.amber[600],
                    ),
                  ),

                // ── Places editor (day only) ───────────────────────
                if (!isTips && _places.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _SectionLabel(
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

                // ── List items editor (all types) ──────────────────
                const SizedBox(height: 16),
                _SectionLabel(
                  icon: Icons.checklist_rounded,
                  label: 'List Items (${_listItems.length})',
                ),
                const SizedBox(height: 8),

                if (_listItems.isNotEmpty)
                  ..._listItems.asMap().entries.map((e) => _ListItemRow(
                        index: e.key,
                        item: e.value,
                        onTextChanged: (t) => _setListItemText(e.key, t),
                        onToggleChecked: () => _toggleChecked(e.key),
                        onRemove: () => _removeListItem(e.key),
                      )),

                // Add item buttons
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
    );
  }

  InputDecoration _inputDecor({
    required String label,
    String? hint,
    required IconData icon,
    Color? iconColor,
  }) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
        alignLabelWithHint: hint != null,
        prefixIcon:
            Icon(icon, size: 16, color: iconColor ?? Colors.grey[500]),
      );
}

// ── Place editor row ──────────────────────────────────────────────────────────

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
    final currentCat =
        widget.place['category'] as String? ?? 'attraction';
    final catMeta = _categories.firstWhere(
      (c) => c.value == currentCat,
      orElse: () => _categories.first,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Place name + category badge
        Row(children: [
          Icon(Icons.place_outlined, size: 14, color: Colors.blue[400]),
          const SizedBox(width: 6),
          Expanded(
            child: Text(name,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ]),
        const SizedBox(height: 10),

        // Category selector
        Row(children: [
          Text('Category:',
              style:
                  TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: catMeta.color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: catMeta.color.withValues(alpha: 0.3)),
                ),
                child: DropdownButton<String>(
                  value: currentCat,
                  isDense: true,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
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
                            Icon(c.icon, size: 14, color: c.color),
                            const SizedBox(width: 6),
                            Text(c.label,
                                style: TextStyle(
                                    fontSize: 12, color: c.color)),
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

        // Description field
        TextField(
          controller: _descCtrl,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: 'Description (optional)',
            hintText: 'What makes this place special...',
            isDense: true,
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          style: const TextStyle(fontSize: 13),
        ),
      ]),
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        // Leading: checkbox or bullet
        GestureDetector(
          onTap: isChecklist ? widget.onToggleChecked : null,
          child: Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            child: isChecklist
                ? Icon(
                    checked
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    size: 20,
                    color: checked
                        ? const Color(0xFF3B82F6)
                        : Colors.grey[400],
                  )
                : Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.grey[500],
                      shape: BoxShape.circle,
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
              hintText: isChecklist
                  ? 'Checklist item...'
                  : 'Text item...',
              isDense: true,
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 8),
            ),
            style: TextStyle(
              fontSize: 13,
              decoration:
                  checked ? TextDecoration.lineThrough : null,
              color: checked ? Colors.grey[400] : null,
            ),
          ),
        ),

        // Type badge
        Container(
          margin: const EdgeInsets.only(left: 6),
          padding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isChecklist
                ? Colors.blue[50]
                : Colors.purple[50],
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            isChecklist ? 'check' : 'text',
            style: TextStyle(
              fontSize: 9,
              color: isChecklist
                  ? Colors.blue[700]
                  : Colors.purple[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        // Remove button
        GestureDetector(
          onTap: widget.onRemove,
          child: Padding(
            padding: const EdgeInsets.only(left: 6),
            child:
                Icon(Icons.close, size: 16, color: Colors.grey[400]),
          ),
        ),
      ]),
    );
  }
}

// ── Small helpers ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 14, color: const Color(0xFF3B82F6)),
      const SizedBox(width: 6),
      Text(label,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E3A8A))),
    ]);
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final MaterialColor color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color[50],
        borderRadius: BorderRadius.circular(20),
      ),
      child:
          Text(label, style: TextStyle(fontSize: 10, color: color[700])),
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
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F6FF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: const Color(0xFF3B82F6)),
          const SizedBox(width: 5),
          Text('+ $label',
              style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF3B82F6),
                  fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}
