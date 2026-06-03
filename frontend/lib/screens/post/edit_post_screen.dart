// lib/screens/post/edit_post_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/travel_guide_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/community_provider.dart';
import '../../repositories/community_repository.dart';
import '../../core/utils/snackbar.dart';

class EditPostScreen extends ConsumerStatefulWidget {
  final TravelGuideModel guide;
  const EditPostScreen({super.key, required this.guide});

  @override
  ConsumerState<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends ConsumerState<EditPostScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _countryCtrl;
  final TextEditingController _tagCtrl = TextEditingController();

  File? _newImage;
  late String _privacy;
  late List<String> _tags;
  List<Map<String, dynamic>> _itineraries = [];
  String? _selectedItineraryId;
  bool _loadingItineraries = true;
  bool _saving = false;
  int _uploadProgress = 0;

  static const _blue = Color(0xFF3B82F6);
  static const _navy = Color(0xFF1E3A8A);
  static const _bg = Color(0xFFF4F9FF);
  static const _fieldFill = Color(0xFFF0F6FF);

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.guide.title);
    _descCtrl = TextEditingController(text: widget.guide.description);
    _countryCtrl = TextEditingController(text: widget.guide.country);
    _privacy = widget.guide.privacy;
    _tags = List<String>.from(widget.guide.tags);
    _selectedItineraryId = widget.guide.itinerary?['_id'] as String?;
    _loadItineraries();
  }

  Future<void> _loadItineraries() async {
    final user = ref.read(authProvider).user;
    if (user == null) {
      setState(() => _loadingItineraries = false);
      return;
    }
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

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _countryCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) setState(() => _newImage = File(picked.path));
  }

  void _addTag() {
    final tag = _tagCtrl.text.trim().replaceAll('#', '');
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagCtrl.clear();
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(communityRepositoryProvider);
      final updated = await repo.editPost(
        postId: widget.guide.id,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        country: _countryCtrl.text.trim(),
        privacy: _privacy,
        tags: _tags,
        itineraryId: _selectedItineraryId,
        image: _newImage,
        onProgress: (p) => setState(() => _uploadProgress = p),
      );
      ref.read(communityProvider.notifier).updatePost(updated);
      if (!mounted) return;
      AppSnackbar.success(context, 'Post updated!');
      context.pop();
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.error(context, 'Failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCoverImagePicker(),
              const SizedBox(height: 16),
              _buildDetailsCard(),
              const SizedBox(height: 16),
              _buildPrivacyCard(),
              const SizedBox(height: 16),
              _buildItineraryCard(),
              const SizedBox(height: 16),
              _buildTagsCard(),
              const SizedBox(height: 24),
              if (_saving && _uploadProgress > 0) ...[
                _buildUploadProgress(),
                const SizedBox(height: 16),
              ],
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.edit_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Text(
            'Edit Post',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: _navy,
            ),
          ),
        ],
      ),
      centerTitle: false,
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close_rounded, color: Color(0xFF6B7280)),
        onPressed: () => context.pop(),
        splashRadius: 24,
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: Colors.grey[100]),
      ),
    );
  }

  Widget _buildCoverImagePicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withValues(alpha: 0.10),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _newImage != null
                  ? Image.file(_newImage!, fit: BoxFit.cover)
                  : (widget.guide.thumbnailImage.isNotEmpty
                      ? Image.network(widget.guide.thumbnailImage,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholderCover())
                      : _placeholderCover()),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.45),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 14,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_rounded, size: 14, color: _blue),
                      SizedBox(width: 4),
                      Text(
                        'Change',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _blue),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholderCover() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _blue.withValues(alpha: 0.25), width: 2),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.add_photo_alternate_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(height: 12),
          const Text('Change Cover Image',
              style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 15, color: _navy)),
          const SizedBox(height: 4),
          Text('Tap to upload from gallery',
              style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildDetailsCard() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
              icon: Icons.article_outlined, label: 'Post Details'),
          const SizedBox(height: 16),
          _StyledField(
            controller: _titleCtrl,
            hint: 'Give your guide a title',
            icon: Icons.title_rounded,
            validator: (v) =>
                v == null || v.isEmpty ? 'Title is required' : null,
          ),
          const SizedBox(height: 12),
          _StyledField(
            controller: _descCtrl,
            hint: 'Describe your travel experience...',
            icon: Icons.notes_rounded,
            maxLines: 4,
            validator: (v) =>
                v == null || v.isEmpty ? 'Description is required' : null,
          ),
          const SizedBox(height: 12),
          _StyledField(
            controller: _countryCtrl,
            hint: 'Country (e.g. Japan)',
            icon: Icons.public_rounded,
            validator: (v) =>
                v == null || v.isEmpty ? 'Country is required' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyCard() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
              icon: Icons.shield_outlined, label: 'Visibility'),
          const SizedBox(height: 14),
          Row(
            children: [
              _PrivacyOption(
                value: 'public',
                groupValue: _privacy,
                icon: Icons.public_rounded,
                label: 'Public',
                subtitle: 'Visible to everyone',
                activeColor: _blue,
                onTap: () => setState(() => _privacy = 'public'),
              ),
              const SizedBox(width: 10),
              _PrivacyOption(
                value: 'private',
                groupValue: _privacy,
                icon: Icons.lock_outline_rounded,
                label: 'Private',
                subtitle: 'Only visible to you',
                activeColor: const Color(0xFF8B5CF6),
                onTap: () => setState(() => _privacy = 'private'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItineraryCard() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
              icon: Icons.map_outlined, label: 'Linked Itinerary'),
          const SizedBox(height: 4),
          Text(
            'Change the itinerary linked to this post.',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          const SizedBox(height: 14),
          _loadingItineraries
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: CircularProgressIndicator(
                        color: _blue, strokeWidth: 2),
                  ),
                )
              : _itineraries.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: Colors.orange[200]!, width: 1),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded,
                              color: Colors.orange[700], size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'No itineraries found. Plan a trip first!',
                              style: TextStyle(
                                  color: Colors.orange[800], fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    )
                  : DropdownButtonFormField<String>(
                      initialValue: _selectedItineraryId,
                      decoration: InputDecoration(
                        hintText: 'Select an itinerary',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        prefixIcon: const Icon(Icons.route_rounded,
                            color: _blue, size: 20),
                        filled: true,
                        fillColor: _fieldFill,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: _blue, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 16),
                      ),
                      dropdownColor: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      items: _itineraries
                          .map((it) => DropdownMenuItem(
                                value: it['_id'] as String,
                                child: Text(
                                  it['country'] ?? 'Trip',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _selectedItineraryId = v),
                    ),
        ],
      ),
    );
  }

  Widget _buildTagsCard() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
              icon: Icons.label_outline_rounded, label: 'Tags'),
          const SizedBox(height: 4),
          Text('Help others discover your guide.',
              style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tagCtrl,
                  decoration: InputDecoration(
                    hintText: 'Add a tag...',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    prefixText: '# ',
                    prefixStyle: const TextStyle(
                        color: _blue, fontWeight: FontWeight.w600),
                    filled: true,
                    fillColor: _fieldFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(40),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(40),
                      borderSide:
                          const BorderSide(color: _blue, width: 1.5),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                  ),
                  onSubmitted: (_) => _addTag(),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _addTag,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_rounded,
                      color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
          if (_tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tags
                  .map((tag) => AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: _blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(40),
                          border: Border.all(
                              color: _blue.withValues(alpha: 0.3), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('#$tag',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _blue)),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _tags.remove(tag)),
                              child: const Icon(Icons.close_rounded,
                                  size: 14, color: _blue),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUploadProgress() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: _blue),
              ),
              const SizedBox(width: 10),
              Text('Uploading... $_uploadProgress%',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: _navy)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: LinearProgressIndicator(
              value: _uploadProgress / 100,
              minHeight: 6,
              backgroundColor: _blue.withValues(alpha: 0.12),
              valueColor: const AlwaysStoppedAnimation<Color>(_blue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _saving ? null : _submit,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: _saving ? 0 : 2,
          shadowColor: _blue.withValues(alpha: 0.4),
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.grey[200],
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: _saving
                ? null
                : const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
                  ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            alignment: Alignment.center,
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: _blue),
                  )
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_rounded,
                          size: 18, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Save Changes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.3,
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

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF3B82F6)),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A8A),
          ),
        ),
      ],
    );
  }
}

class _StyledField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final int maxLines;
  final String? Function(String?)? validator;

  const _StyledField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
        prefixIcon: Icon(icon, color: const Color(0xFF3B82F6), size: 20),
        filled: true,
        fillColor: const Color(0xFFF0F6FF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      ),
    );
  }
}

class _PrivacyOption extends StatelessWidget {
  final String value;
  final String groupValue;
  final IconData icon;
  final String label;
  final String subtitle;
  final Color activeColor;
  final VoidCallback onTap;

  const _PrivacyOption({
    required this.value,
    required this.groupValue,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor.withValues(alpha: 0.08)
                : Colors.grey[50],
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? activeColor : Colors.grey[200]!,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isSelected
                      ? activeColor.withValues(alpha: 0.15)
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon,
                    size: 18,
                    color: isSelected ? activeColor : Colors.grey[400]),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: isSelected
                      ? activeColor
                      : const Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
              const SizedBox(height: 6),
              Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 16,
                color: isSelected ? activeColor : Colors.grey[300],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
