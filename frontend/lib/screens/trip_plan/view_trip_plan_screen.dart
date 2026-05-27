// lib/screens/trip_plan/view_trip_plan_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/auth_provider.dart';
import '../../providers/community_provider.dart';
import '../../repositories/trip_plan_repository.dart';
import '../../models/comment_model.dart';
import '../../core/utils/snackbar.dart';

class ViewTripPlanScreen extends ConsumerStatefulWidget {
  final String tripPlanId;
  const ViewTripPlanScreen({super.key, required this.tripPlanId});

  @override
  ConsumerState<ViewTripPlanScreen> createState() => _ViewTripPlanScreenState();
}

class _ViewTripPlanScreenState extends ConsumerState<ViewTripPlanScreen> {
  Map<String, dynamic>? _tripPlan;
  List<CommentModel> _comments = [];
  bool _loading = true;
  bool _submittingComment = false;
  final _commentCtrl = TextEditingController();
  String? _editingCommentId;
  final _editCtrl = TextEditingController();

  // Track which sections are expanded
  final Set<int> _expandedSections = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _editCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(tripPlanRepositoryProvider);
      final plan = await repo.getTripPlan(widget.tripPlanId);
      final comments = await repo.getComments(widget.tripPlanId);

      // Expand first section by default
      if (mounted) {
        setState(() {
          _tripPlan = plan;
          _comments = comments;
          _loading = false;
          final sections = _getSections(plan);
          if (sections.isNotEmpty) _expandedSections.add(0);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        AppSnackbar.error(context, 'Failed to load: $e');
      }
    }
  }

  List<Map<String, dynamic>> _getSections(Map<String, dynamic> plan) {
    final raw = plan['sections'];
    if (raw is List) {
      return raw
          .whereType<Map<String, dynamic>>()
          .toList();
    }
    return [];
  }

  Future<void> _submitComment() async {
    if (_commentCtrl.text.trim().isEmpty) return;
    setState(() => _submittingComment = true);
    try {
      final repo = ref.read(tripPlanRepositoryProvider);
      final comment = await repo.createComment(
          widget.tripPlanId, _commentCtrl.text.trim());
      setState(() {
        _comments.add(comment);
        _commentCtrl.clear();
      });
    } catch (_) {
      if (mounted) AppSnackbar.error(context, 'Failed to post comment');
    } finally {
      if (mounted) setState(() => _submittingComment = false);
    }
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      final repo = ref.read(tripPlanRepositoryProvider);
      await repo.deleteComment(widget.tripPlanId, commentId);
      setState(() => _comments.removeWhere((c) => c.id == commentId));
    } catch (_) {
      if (mounted) AppSnackbar.error(context, 'Failed to delete comment');
    }
  }

  Future<void> _saveEditComment(String commentId) async {
    if (_editCtrl.text.trim().isEmpty) return;
    try {
      final repo = ref.read(tripPlanRepositoryProvider);
      final updated = await repo.updateComment(
          widget.tripPlanId, commentId, _editCtrl.text.trim());
      setState(() {
        _comments =
            _comments.map((c) => c.id == commentId ? updated : c).toList();
        _editingCommentId = null;
      });
    } catch (_) {
      if (mounted) AppSnackbar.error(context, 'Failed to update comment');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final plan = _tripPlan;
    if (plan == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Guide not found')),
      );
    }

    final auth = ref.watch(authProvider);
    final user = auth.user;
    final sections = _getSections(plan);

    // Author — guide stores denormalised fields directly
    final authorName = plan['authorName'] as String? ?? '';
    final authorAvatar = plan['authorAvatar'] as String? ?? '';
    final authorIntro = plan['authorIntro'] as String? ?? '';
    final isOwner = user?.id == plan['userId']?.toString();

    return Scaffold(
      appBar: AppBar(
        title: Text(plan['title'] ?? 'Travel Guide',
            overflow: TextOverflow.ellipsis),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              Clipboard.setData(
                  ClipboardData(text: 'Travel Guide: ${plan['title']}'));
              AppSnackbar.success(context, 'Link copied!');
            },
          ),
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () =>
                  context.go('/edit-travel-guide/${widget.tripPlanId}'),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header card ──────────────────────────────────────────
                  _HeaderCard(
                    plan: plan,
                    authorName: authorName,
                    authorAvatar: authorAvatar,
                    authorIntro: authorIntro,
                    commentCount: _comments.length,
                  ),

                  // ── Sections (days + tips) ───────────────────────────────
                  if (sections.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Text('Itinerary',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    ...sections.asMap().entries.map((e) => _SectionTile(
                          index: e.key,
                          section: e.value,
                          isExpanded: _expandedSections.contains(e.key),
                          onToggle: () => setState(() {
                            if (_expandedSections.contains(e.key)) {
                              _expandedSections.remove(e.key);
                            } else {
                              _expandedSections.add(e.key);
                            }
                          }),
                        )),
                  ],

                  // ── Comments ─────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Text('Comments (${_comments.length})',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  if (_comments.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text('No comments yet. Be the first!',
                            style: TextStyle(color: Colors.grey[400])),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: _comments
                            .map((c) => _CommentTile(
                                  comment: c,
                                  isOwner: user?.id == c.user.id,
                                  isEditing: _editingCommentId == c.id,
                                  editCtrl: _editCtrl,
                                  onEdit: () {
                                    _editCtrl.text = c.content;
                                    setState(
                                        () => _editingCommentId = c.id);
                                  },
                                  onDelete: () => _deleteComment(c.id!),
                                  onSaveEdit: () =>
                                      _saveEditComment(c.id!),
                                  onCancelEdit: () => setState(
                                      () => _editingCommentId = null),
                                ))
                            .toList(),
                      ),
                    ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),

          // ── Comment input ────────────────────────────────────────────────
          if (auth.isAuthenticated)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border:
                    Border(top: BorderSide(color: Colors.grey[200]!)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, -2))
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _commentCtrl,
                      decoration: const InputDecoration(
                          hintText: 'Write a comment...',
                          isDense: true,
                          contentPadding: EdgeInsets.all(10)),
                      maxLines: null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _submittingComment ? null : _submitComment,
                    icon: _submittingComment
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send_rounded,
                            color: Color(0xFF3B82F6)),
                  ),
                ]),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.grey[50],
              child: SafeArea(
                top: false,
                child: TextButton.icon(
                  onPressed: () => context.go('/auth'),
                  icon: const Icon(Icons.login),
                  label: const Text('Login to comment'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Header card ────────────────────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final String authorName;
  final String authorAvatar;
  final String authorIntro;
  final int commentCount;

  const _HeaderCard({
    required this.plan,
    required this.authorName,
    required this.authorAvatar,
    required this.authorIntro,
    required this.commentCount,
  });

  @override
  Widget build(BuildContext context) {
    final country = plan['country'] as String? ?? '';
    final title = plan['title'] as String? ?? '';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Country badge
        if (country.isNotEmpty)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(country.toUpperCase(),
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue[700],
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5)),
          ),
        const SizedBox(height: 8),

        // Title
        Text(title,
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, height: 1.3)),
        const SizedBox(height: 12),

        // Author row
        if (authorName.isNotEmpty)
          Row(children: [
            CircleAvatar(
              radius: 20,
              backgroundImage: authorAvatar.isNotEmpty
                  ? NetworkImage(authorAvatar)
                  : null,
              backgroundColor: Colors.blue[100],
              child: authorAvatar.isEmpty
                  ? Text(authorName[0].toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold))
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('@$authorName',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    if (authorIntro.isNotEmpty)
                      Text(authorIntro,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[500]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                  ]),
            ),
          ]),

        const SizedBox(height: 12),

        // Stats
        Row(children: [
          _Chip(icon: Icons.chat_bubble_outline,
              label: '$commentCount comments'),
          const SizedBox(width: 12),
          _Chip(icon: Icons.public,
              label: plan['publishStatus'] ?? 'private'),
        ]),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Chip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 14, color: Colors.grey[500]),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ]);
}

// ── Section tile (day or tips) ──────────────────────────────────────────────

class _SectionTile extends StatelessWidget {
  final int index;
  final Map<String, dynamic> section;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _SectionTile({
    required this.index,
    required this.section,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final type = section['type'] as String? ?? 'day';
    final title = section['title'] as String? ?? 'Section ${index + 1}';
    final content = section['content'] as String? ?? '';
    final notes = section['notes'] as String? ?? '';
    final places = _asList(section['places']);
    final route = _asList(section['route']);
    final listItems = _asList(section['listItems']);

    final isTips = type == 'tips';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Column(children: [
        // Header row
        InkWell(
          onTap: onToggle,
          borderRadius:
              BorderRadius.vertical(top: const Radius.circular(12),
                  bottom: isExpanded ? Radius.zero : const Radius.circular(12)),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  size: 18,
                  color: isTips ? Colors.amber[700] : Colors.blue[700],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15))),
              Icon(
                isExpanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                color: Colors.grey[400],
              ),
            ]),
          ),
        ),

        // Expanded body
        if (isExpanded)
          Padding(
            padding:
                const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  // Tips content or day notes
                  if (content.isNotEmpty) ...[
                    Text(content,
                        style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                            height: 1.5)),
                    const SizedBox(height: 10),
                  ],
                  if (notes.isNotEmpty) ...[
                    Text('Notes',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Colors.grey[700])),
                    const SizedBox(height: 4),
                    Text(notes,
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                            height: 1.5)),
                    const SizedBox(height: 10),
                  ],

                  // Places
                  if (places.isNotEmpty) ...[
                    Text('Places',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    ...places.map((p) => _PlaceRow(place: p)),
                  ],

                  // Route
                  if (route.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Route',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    ...route.asMap().entries.map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: Colors.blue[600],
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text('${e.key + 1}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _routeLabel(e.value),
                                style: TextStyle(
                                    fontSize: 13, color: Colors.grey[700]),
                              ),
                            ),
                          ]),
                        )),
                  ],

                  // List items (for tips sections)
                  if (listItems.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...listItems.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('• ',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold)),
                                Expanded(
                                    child: Text(_itemLabel(item),
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[700]))),
                              ]),
                        )),
                  ],
                ]),
          ),
      ]),
    );
  }

  List<dynamic> _asList(dynamic val) {
    if (val is List) return val;
    return [];
  }

  String _routeLabel(dynamic r) {
    if (r is Map) return r['name']?.toString() ?? r.toString();
    return r.toString();
  }

  String _itemLabel(dynamic item) {
    if (item is Map) return item['text']?.toString() ?? item.toString();
    return item.toString();
  }
}

// ── Place row ──────────────────────────────────────────────────────────────

class _PlaceRow extends StatelessWidget {
  final dynamic place;
  const _PlaceRow({required this.place});

  @override
  Widget build(BuildContext context) {
    final name = place is Map
        ? (place['name'] ?? place['placeName'] ?? 'Unknown place').toString()
        : place.toString();
    final address =
        place is Map ? (place['address'] ?? '').toString() : '';
    final imageUrl =
        place is Map ? (place['photoUrl'] ?? place['image'] ?? '').toString() : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: imageUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => _PlaceholderBox(),
                )
              : _PlaceholderBox(),
        ),
        const SizedBox(width: 10),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              if (address.isNotEmpty)
                Text(address,
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
            ])),
      ]),
    );
  }
}

class _PlaceholderBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8)),
        child: Icon(Icons.place_outlined, color: Colors.grey[400], size: 22),
      );
}

// ── Comment tile ───────────────────────────────────────────────────────────

class _CommentTile extends StatelessWidget {
  final CommentModel comment;
  final bool isOwner;
  final bool isEditing;
  final TextEditingController editCtrl;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSaveEdit;
  final VoidCallback onCancelEdit;

  const _CommentTile({
    required this.comment,
    required this.isOwner,
    required this.isEditing,
    required this.editCtrl,
    required this.onEdit,
    required this.onDelete,
    required this.onSaveEdit,
    required this.onCancelEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(
          radius: 16,
          backgroundImage: (comment.user.profilePicture?.isNotEmpty ?? false)
              ? NetworkImage(comment.user.profilePicture!)
              : null,
          backgroundColor: Colors.blue[100],
          child: (comment.user.profilePicture?.isEmpty ?? true)
              ? Text(comment.user.username[0].toUpperCase(),
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold))
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Row(children: [
                Text('@${comment.user.username}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                const Spacer(),
                if (isOwner) ...[
                  GestureDetector(
                      onTap: onEdit,
                      child: Icon(Icons.edit_outlined,
                          size: 16, color: Colors.blue[400])),
                  const SizedBox(width: 8),
                  GestureDetector(
                      onTap: onDelete,
                      child: Icon(Icons.delete_outline,
                          size: 16, color: Colors.red[400])),
                ],
              ]),
              if (isEditing) ...[
                const SizedBox(height: 4),
                TextField(
                  controller: editCtrl,
                  decoration: const InputDecoration(
                      isDense: true, border: OutlineInputBorder()),
                  autofocus: true,
                ),
                const SizedBox(height: 6),
                Row(children: [
                  TextButton(onPressed: onSaveEdit, child: const Text('Save')),
                  TextButton(
                      onPressed: onCancelEdit, child: const Text('Cancel')),
                ]),
              ] else ...[
                const SizedBox(height: 4),
                Text(comment.content,
                    style: TextStyle(fontSize: 13, color: Colors.grey[700])),
              ],
            ])),
      ]),
    );
  }
}
