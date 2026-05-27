// lib/screens/trip_plan/edit_trip_plan_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../repositories/trip_plan_repository.dart';
import '../../core/utils/snackbar.dart';

class EditTripPlanScreen extends ConsumerStatefulWidget {
  final String tripPlanId;
  const EditTripPlanScreen({super.key, required this.tripPlanId});

  @override
  ConsumerState<EditTripPlanScreen> createState() => _EditTripPlanScreenState();
}

class _EditTripPlanScreenState extends ConsumerState<EditTripPlanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _introCtrl = TextEditingController();

  List<Map<String, dynamic>> _sections = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadExistingPlan();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _introCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExistingPlan() async {
    try {
      final repo = ref.read(tripPlanRepositoryProvider);
      final data = await repo.getTripPlan(widget.tripPlanId);
      final rawSections = data['sections'];
      setState(() {
        _titleCtrl.text = data['title'] ?? '';
        _introCtrl.text = data['authorIntro'] ?? '';
        _sections = (rawSections is List)
            ? rawSections.whereType<Map<String, dynamic>>().toList()
            : [];
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) AppSnackbar.error(context, 'Failed to load guide: $e');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(tripPlanRepositoryProvider);
      await repo.updateTripPlan(
        tripPlanId: widget.tripPlanId,
        title: _titleCtrl.text.trim(),
        authorIntro: _introCtrl.text.trim(),
        sections: _sections,
      );
      AppSnackbar.success(context, 'Guide updated! ✅');
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Travel Guide'),
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
              // Info banner — explain what can be edited here
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber[200]!),
                ),
                child: Row(children: [
                  Icon(Icons.info_outline, color: Colors.amber[700], size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You can edit the title, your intro, and section notes here.',
                      style: TextStyle(fontSize: 12, color: Colors.amber[800]),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                    labelText: 'Guide Title',
                    prefixIcon: Icon(Icons.title)),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
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
              const SizedBox(height: 24),

              // Sections preview — show what sections exist
              if (_sections.isNotEmpty) ...[
                const Text('Sections',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                ..._sections.asMap().entries.map((e) =>
                    _SectionNoteEditor(
                      index: e.key,
                      section: e.value,
                      onNotesChanged: (notes) {
                        setState(() => _sections[e.key]['notes'] = notes);
                      },
                    )),
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
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Saving...' : 'Save Changes'),
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

/// Lets the user edit the notes field of a day section inline.
class _SectionNoteEditor extends StatefulWidget {
  final int index;
  final Map<String, dynamic> section;
  final ValueChanged<String> onNotesChanged;

  const _SectionNoteEditor({
    required this.index,
    required this.section,
    required this.onNotesChanged,
  });

  @override
  State<_SectionNoteEditor> createState() => _SectionNoteEditorState();
}

class _SectionNoteEditorState extends State<_SectionNoteEditor> {
  late final TextEditingController _ctrl;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: widget.section['notes'] as String? ?? '');
    _ctrl.addListener(() => widget.onNotesChanged(_ctrl.text));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.section['type'] as String? ?? 'day';
    final title =
        widget.section['title'] as String? ?? 'Section ${widget.index + 1}';
    final isTips = type == 'tips';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Column(children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Icon(
                isTips ? Icons.lightbulb_outline : Icons.map_outlined,
                size: 18,
                color: isTips ? Colors.amber[600] : Colors.blue[600],
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 14))),
              Icon(
                _expanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                color: Colors.grey[400],
              ),
            ]),
          ),
        ),
        if (_expanded && !isTips)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: TextField(
              controller: _ctrl,
              decoration: const InputDecoration(
                labelText: 'Notes for this day',
                hintText: 'Any tips or notes for travellers...',
                isDense: true,
              ),
              maxLines: 3,
            ),
          ),
      ]),
    );
  }
}
