// lib/screens/post/post_screen.dart
// Replaces frontend/src/pages/post/PostPage.tsx

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/auth_provider.dart';
import '../../providers/community_provider.dart';
import '../../repositories/community_repository.dart';
import '../../repositories/user_repository.dart';
import '../../core/utils/snackbar.dart';

class PostScreen extends ConsumerStatefulWidget {
  const PostScreen({super.key});

  @override
  ConsumerState<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends ConsumerState<PostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();

  File? _image;
  String _privacy = 'private';
  List<String> _tags = [];
  List<Map<String, dynamic>> _itineraries = [];
  String? _selectedItineraryId;
  bool _saving = false;
  bool _loadingItineraries = true;
  int _uploadProgress = 0;

  @override
  void initState() {
    super.initState();
    _loadItineraries();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _countryCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadItineraries() async {
    final user = ref.read(authProvider).user;
    if (user == null) { setState(() => _loadingItineraries = false); return; }
    try {
      final repo = ref.read(communityRepositoryProvider);
      final data = await repo.getItinerariesByAuthor(user.id);
      setState(() {
        _itineraries = data.cast<Map<String, dynamic>>();
        _loadingItineraries = false;
      });
    } catch (_) {
      setState(() => _loadingItineraries = false);
    }
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) setState(() => _image = File(picked.path));
  }

  void _addTag() {
    final tag = _tagCtrl.text.trim().replaceAll('#', '');
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() { _tags.add(tag); _tagCtrl.clear(); });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedItineraryId == null) {
      AppSnackbar.show(context, 'Please select an itinerary');
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(communityRepositoryProvider);
      final user = ref.read(authProvider).user!;
      final guide = await repo.createPost(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        country: _countryCtrl.text.trim(),
        privacy: _privacy,
        tags: _tags,
        itineraryId: _selectedItineraryId!,
        authorId: user.id,
        image: _image,
        onProgress: (p) => setState(() => _uploadProgress = p),
      );
      ref.read(communityProvider.notifier).addPost(guide);
      AppSnackbar.success(context, 'Post created! 🎉');
      if (mounted) context.go('/dashboard');
    } catch (e) {
      AppSnackbar.error(context, 'Failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => context.pop()),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image picker
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: _image != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.file(_image!, fit: BoxFit.cover),
                        )
                      : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.add_photo_alternate_outlined, size: 40, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text('Add cover image (optional)', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                        ]),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Title', prefixIcon: Icon(Icons.title)),
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

              // Privacy
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

              // Itinerary selector
              const Text('Link an Itinerary', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              _loadingItineraries
                  ? const Center(child: CircularProgressIndicator())
                  : _itineraries.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(10)),
                          child: const Text('No itineraries found. Plan a trip first!',
                              style: TextStyle(color: Colors.orange)),
                        )
                      : DropdownButtonFormField<String>(
                          value: _selectedItineraryId,
                          decoration: const InputDecoration(labelText: 'Select itinerary', prefixIcon: Icon(Icons.map_outlined)),
                          items: _itineraries.map((it) => DropdownMenuItem(
                            value: it['_id'] as String,
                            child: Text(it['country'] ?? 'Trip', overflow: TextOverflow.ellipsis),
                          )).toList(),
                          onChanged: (v) => setState(() => _selectedItineraryId = v),
                          validator: (v) => v == null ? 'Please select an itinerary' : null,
                        ),
              const SizedBox(height: 16),

              // Tags
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
                      : const Icon(Icons.send_outlined),
                  label: Text(_saving ? 'Posting...' : 'Create Post'),
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
