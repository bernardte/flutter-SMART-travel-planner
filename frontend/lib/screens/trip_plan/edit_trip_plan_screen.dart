// lib/screens/trip_plan/edit_trip_plan_screen.dart
// Replaces edit travel guide page

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../repositories/trip_plan_repository.dart';

class EditTripPlanScreen extends ConsumerStatefulWidget {
  final String tripPlanId;
  const EditTripPlanScreen({super.key, required this.tripPlanId});

  @override
  ConsumerState<EditTripPlanScreen> createState() => _EditTripPlanScreenState();
}

class _EditTripPlanScreenState extends ConsumerState<EditTripPlanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();

  File? _newThumbnail;
  String? _existingThumbnailUrl;
  String _privacy = 'public';
  List<String> _tags = [];
  bool _loading = true;
  bool _saving = false;
  int _uploadProgress = 0;

  @override
  void initState() {
    super.initState();
    _loadExistingPlan();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _countryCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExistingPlan() async {
    try {
      final repo = ref.read(tripPlanRepositoryProvider);
      final data = await repo.getTripPlan(widget.tripPlanId);
      setState(() {
        _titleCtrl.text = data['title'] ?? '';
        _descCtrl.text = data['description'] ?? '';
        _countryCtrl.text = data['country'] ?? '';
        _privacy = data['privacy'] ?? 'public';
        _existingThumbnailUrl = data['thumbnailImage'];
        _tags = List<String>.from(data['tags'] ?? []);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load guide: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) setState(() => _newThumbnail = File(picked.path));
  }

  void _addTag() {
    final tag = _tagCtrl.text.trim().replaceAll('#', '');
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() { _tags.add(tag); _tagCtrl.clear(); });
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
        description: _descCtrl.text.trim(),
        country: _countryCtrl.text.trim(),
        privacy: _privacy,
        tags: _tags,
        sections: [],
        thumbnailImage: _newThumbnail,
        onProgress: (p) => setState(() => _uploadProgress = p),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Guide updated! ✅'),
          backgroundColor: Colors.green,
        ),
      );
      if (mounted) context.go('/dashboard');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Travel Guide'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Stack(fit: StackFit.expand, children: [
                      if (_newThumbnail != null)
                        Image.file(_newThumbnail!, fit: BoxFit.cover)
                      else if (_existingThumbnailUrl != null)
                        CachedNetworkImage(imageUrl: _existingThumbnailUrl!, fit: BoxFit.cover)
                      else
                        Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.add_photo_alternate_outlined, size: 48, color: Colors.grey[400]),
                          Text('Tap to add thumbnail', style: TextStyle(color: Colors.grey[500])),
                        ]),
                      Positioned(
                        bottom: 8, right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                          child: const Text('Change photo', style: TextStyle(color: Colors.white, fontSize: 11)),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Guide Title', prefixIcon: Icon(Icons.title)),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: 'Description', prefixIcon: Icon(Icons.description_outlined)),
                maxLines: 3,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _countryCtrl,
                decoration: const InputDecoration(labelText: 'Country', prefixIcon: Icon(Icons.public)),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              const Text('Privacy', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'public', label: Text('Public'), icon: Icon(Icons.public, size: 16)),
                  ButtonSegment(value: 'private', label: Text('Private'), icon: Icon(Icons.lock_outline, size: 16)),
                ],
                selected: {_privacy},
                onSelectionChanged: (s) => setState(() => _privacy = s.first),
              ),
              const SizedBox(height: 16),
              const Text('Tags', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _tagCtrl,
                    decoration: const InputDecoration(hintText: 'Add a tag...', prefixIcon: Icon(Icons.tag, size: 18), isDense: true),
                    onSubmitted: (_) => _addTag(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(onPressed: _addTag, icon: const Icon(Icons.add_circle_outline), color: Colors.blue),
              ]),
              if (_tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: _tags.map((tag) => Chip(
                    label: Text('#$tag', style: const TextStyle(fontSize: 12)),
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onDeleted: () => setState(() => _tags.remove(tag)),
                    backgroundColor: Colors.blue[50],
                    labelStyle: TextStyle(color: Colors.blue[700]),
                  )).toList(),
                ),
              ],
              const SizedBox(height: 24),
              if (_saving && _uploadProgress > 0) ...[
                Text('Uploading: $_uploadProgress%'),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: _uploadProgress / 100),
                const SizedBox(height: 16),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
