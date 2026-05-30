// lib/screens/trip_plan/view_trip_plan_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/trip_plan_repository.dart';
import '../../models/comment_model.dart';
import '../../core/utils/snackbar.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _kBlue     = Color(0xFF3B82F6);
const _kCyan     = Color(0xFF06B6D4);
const _kDark     = Color(0xFF1F2937);
const _kDarkBlue = Color(0xFF1E3A8A);
const _kBg       = Color(0xFFF4F9FF);
const _kInputFill   = Color(0xFFF0F9FF);
const _kInputBorder = Color(0xFFBAE6FD);

const _categories = [
  (value: 'attraction', label: 'Attraction', icon: Icons.museum_outlined,    color: Color(0xFF3B82F6)),
  (value: 'restaurant', label: 'Restaurant', icon: Icons.restaurant_outlined, color: Color(0xFFEF4444)),
  (value: 'cafe',       label: 'Café',       icon: Icons.coffee_outlined,     color: Color(0xFF92400E)),
  (value: 'viewpoint',  label: 'Viewpoint',  icon: Icons.landscape_outlined,  color: Color(0xFF10B981)),
  (value: 'other',      label: 'Other',      icon: Icons.place_outlined,      color: Color(0xFF6B7280)),
];

// ─────────────────────────────────────────────────────────────────────────────

class ViewTripPlanScreen extends ConsumerStatefulWidget {
  final String tripPlanId;
  const ViewTripPlanScreen({super.key, required this.tripPlanId});

  @override
  ConsumerState<ViewTripPlanScreen> createState() =>
      _ViewTripPlanScreenState();
}

class _ViewTripPlanScreenState extends ConsumerState<ViewTripPlanScreen> {
  Map<String, dynamic>? _tripPlan;
  List<CommentModel> _comments = [];
  bool _loading = true;
  bool _submittingComment = false;
  final _commentCtrl = TextEditingController();
  String? _editingCommentId;
  final _editCtrl = TextEditingController();
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
    if (raw is List) return raw.whereType<Map<String, dynamic>>().toList();
    return [];
  }

  Future<void> _submitComment() async {
    if (_commentCtrl.text.trim().isEmpty) return;
    setState(() => _submittingComment = true);
    try {
      final comment = await ref
          .read(tripPlanRepositoryProvider)
          .createComment(widget.tripPlanId, _commentCtrl.text.trim());
      if (!mounted) return;
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

  Future<void> _confirmAndDelete(String commentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete comment?'),
        content: const Text('This comment will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                TextButton.styleFrom(foregroundColor: Colors.red[600]),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) _deleteComment(commentId);
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      await ref
          .read(tripPlanRepositoryProvider)
          .deleteComment(widget.tripPlanId, commentId);
      if (!mounted) return;
      setState(() {
        _comments.removeWhere((c) => c.id == commentId);
        if (_editingCommentId == commentId) _editingCommentId = null;
      });
    } catch (_) {
      if (mounted) AppSnackbar.error(context, 'Failed to delete comment');
    }
  }

  Future<void> _saveEditComment(String commentId) async {
    if (_editCtrl.text.trim().isEmpty) return;
    try {
      final updated = await ref
          .read(tripPlanRepositoryProvider)
          .updateComment(
              widget.tripPlanId, commentId, _editCtrl.text.trim());
      if (!mounted) return;
      setState(() {
        _comments =
            _comments.map((c) => c.id == commentId ? updated : c).toList();
        _editingCommentId = null;
      });
    } catch (_) {
      if (mounted)
        AppSnackbar.error(context, 'Failed to update comment');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: _kBg,
        body: Center(child: CircularProgressIndicator(color: _kBlue)),
      );
    }

    final plan = _tripPlan;
    if (plan == null) {
      return Scaffold(
        backgroundColor: _kBg,
        appBar: _buildAppBar(context, 'Guide not found', false, null),
        body: const Center(child: Text('Guide not found')),
      );
    }

    final auth = ref.watch(authProvider);
    final user = auth.user;
    final sections = _getSections(plan);
    final authorName = plan['authorName'] as String? ?? '';
    final authorAvatar = plan['authorAvatar'] as String? ?? '';
    final authorIntro = plan['authorIntro'] as String? ?? '';
    final isOwner = user?.id == plan['userId']?.toString();

    return Scaffold(
      backgroundColor: _kBg,
      appBar: _buildAppBar(
        context,
        plan['title'] as String? ?? 'Travel Guide',
        isOwner,
        () => context.go('/edit-travel-guide/${widget.tripPlanId}'),
      ),
      body: Column(
        children: [
          // ── Scrollable content ────────────────────────────────────────
          Expanded(
            child: CustomScrollView(
              slivers: [
                // ── Hero header ─────────────────────────────────────────
                SliverToBoxAdapter(
                  child: _HeroHeader(
                    plan: plan,
                    authorName: authorName,
                    authorAvatar: authorAvatar,
                    authorIntro: authorIntro,
                    commentCount: _comments.length,
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 20)),

                // ── Itinerary sections ──────────────────────────────────
                if (sections.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _SectionHeader(
                          icon: Icons.route_rounded, label: 'Itinerary'),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 10)),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: Duration(
                              milliseconds:
                                  250 + (i * 40).clamp(0, 400)),
                          builder: (_, v, child) => Opacity(
                            opacity: v,
                            child: Transform.translate(
                              offset: Offset(0, 16 * (1 - v)),
                              child: child,
                            ),
                          ),
                          child: _SectionTile(
                            index: i,
                            section: sections[i],
                            isExpanded: _expandedSections.contains(i),
                            onToggle: () => setState(() {
                              if (_expandedSections.contains(i)) {
                                _expandedSections.remove(i);
                              } else {
                                _expandedSections.add(i);
                              }
                            }),
                          ),
                        ),
                        childCount: sections.length,
                      ),
                    ),
                  ),
                ],

                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                // ── Comments ────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _SectionHeader(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'Comments (${_comments.length})',
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 10)),

                if (_comments.isEmpty)
                  SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          children: [
                            Icon(Icons.chat_bubble_outline,
                                size: 40, color: Colors.grey[300]),
                            const SizedBox(height: 8),
                            Text(
                              'No comments yet. Be the first!',
                              style: TextStyle(
                                  color: Colors.grey[400], fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) {
                          final c = _comments[i];
                          return _CommentTile(
                            comment: c,
                            isOwner: user?.id == c.user.id,
                            isEditing: _editingCommentId == c.id,
                            editCtrl: _editCtrl,
                            onEdit: () {
                              _editCtrl.text = c.content;
                              setState(
                                  () => _editingCommentId = c.id);
                            },
                            onDelete: () {
                              if (c.id != null) _confirmAndDelete(c.id!);
                            },
                            onSaveEdit: () {
                              if (c.id != null) _saveEditComment(c.id!);
                            },
                            onCancelEdit: () =>
                                setState(() => _editingCommentId = null),
                          );
                        },
                        childCount: _comments.length,
                      ),
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          ),

          // ── Comment input bar ─────────────────────────────────────────
          _CommentInputBar(
            auth: auth,
            controller: _commentCtrl,
            submitting: _submittingComment,
            onSubmit: _submitComment,
            onLoginTap: () => context.go('/auth'),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    String title,
    bool isOwner,
    VoidCallback? onEdit,
  ) {
    return AppBar(
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: _kBlue),
        onPressed: () => context.canPop()
            ? context.pop()
            : context.go('/community-guide'),
      ),
      title: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_kBlue, _kCyan]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.auto_awesome_rounded,
              color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: _kDarkBlue,
            ),
          ),
        ),
      ]),
      centerTitle: false,
      backgroundColor: Colors.white,
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.share_outlined, color: _kBlue),
          tooltip: 'Share',
          onPressed: () {
            Clipboard.setData(
                ClipboardData(text: 'Travel Guide: $title'));
            AppSnackbar.success(context, 'Link copied!');
          },
        ),
        if (isOwner && onEdit != null)
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: _kBlue),
            tooltip: 'Edit guide',
            onPressed: onEdit,
          ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: Colors.grey[100]),
      ),
    );
  }
}

// ── Section header (left bar style) ──────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 4,
        height: 20,
        decoration: BoxDecoration(
          color: _kBlue,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 10),
      Icon(icon, size: 16, color: _kBlue),
      const SizedBox(width: 6),
      Text(
        label,
        style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: _kDarkBlue),
      ),
    ]);
  }
}

// ── Hero header ───────────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  final Map<String, dynamic> plan;
  final String authorName, authorAvatar, authorIntro;
  final int commentCount;

  const _HeroHeader({
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
    final status = plan['publishStatus'] as String? ?? 'public';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
              color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Country chip
        if (country.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_kBlue, _kCyan]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              country.toUpperCase(),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8),
            ),
          ),
          const SizedBox(height: 10),
        ],

        // Title
        Text(
          title,
          style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _kDark,
              height: 1.25,
              letterSpacing: -0.3),
        ),
        const SizedBox(height: 14),

        // Author row
        if (authorName.isNotEmpty) ...[
          Row(children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: _kBlue.withValues(alpha: 0.15),
              backgroundImage: authorAvatar.isNotEmpty
                  ? NetworkImage(authorAvatar)
                  : null,
              child: authorAvatar.isEmpty
                  ? Text(
                      authorName.isNotEmpty
                          ? authorName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _kBlue,
                          fontSize: 16))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                  '@$authorName',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: _kDark),
                ),
                if (authorIntro.isNotEmpty)
                  Text(
                    authorIntro,
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey[500]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
        ],

        const Divider(height: 1, color: Color(0xFFF3F4F6)),
        const SizedBox(height: 12),

        // Stats row
        Row(children: [
          _StatChip(
              icon: Icons.chat_bubble_outline_rounded,
              label: '$commentCount comment${commentCount == 1 ? '' : 's'}'),
          const SizedBox(width: 12),
          _StatChip(
              icon: Icons.public_rounded,
              label: status == 'public' ? 'Public' : 'Private'),
        ]),
      ]),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _kBlue.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: _kBlue),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                color: _kBlue,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ── Section tile ──────────────────────────────────────────────────────────────

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

  List<dynamic> _asList(dynamic val) => val is List ? val : [];

  String _routeLabel(dynamic r) =>
      r is Map ? r['name']?.toString() ?? '' : r.toString();

  String _itemLabel(dynamic item) =>
      item is Map ? item['text']?.toString() ?? '' : item.toString();

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

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded ? _kBlue : const Color(0xFFE5E7EB),
          width: isExpanded ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isExpanded ? 0.07 : 0.03),
            blurRadius: isExpanded ? 14 : 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        // ── Header ────────────────────────────────────────────────
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            child: Row(children: [
              Container(
                width: 38,
                height: 38,
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
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  isTips
                      ? Icons.lightbulb_rounded
                      : Icons.calendar_today_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: _kDark),
                    ),
                    if (!isTips && places.isNotEmpty)
                      Text(
                        '${places.length} place${places.length == 1 ? '' : 's'} · ${route.length} stop${route.length == 1 ? '' : 's'}',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[500]),
                      ),
                  ],
                ),
              ),
              AnimatedRotation(
                turns: isExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: isExpanded ? _kBlue : Colors.grey[400],
                ),
              ),
            ]),
          ),
        ),

        // ── Expanded body ──────────────────────────────────────────
        if (isExpanded) ...[
          Container(height: 1, color: _kBlue.withValues(alpha: 0.12)),
          Container(
            color: const Color(0xFFF8FAFF),
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Content (tips) or notes (day)
                if (content.isNotEmpty) ...[
                  Text(content,
                      style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          height: 1.55)),
                  const SizedBox(height: 12),
                ],
                if (notes.isNotEmpty) ...[
                  _BodyLabel(
                      icon: Icons.notes_rounded, label: 'Notes'),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE4F0FF)),
                    ),
                    child: Text(notes,
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                            height: 1.5)),
                  ),
                  const SizedBox(height: 14),
                ],

                // Places
                if (places.isNotEmpty) ...[
                  _BodyLabel(
                      icon: Icons.place_rounded,
                      label: 'Places (${places.length})'),
                  const SizedBox(height: 8),
                  ...places.map((p) => _PlaceRow(place: p)),
                ],

                // Route
                if (route.isNotEmpty) ...[
                  if (places.isNotEmpty) const SizedBox(height: 10),
                  _BodyLabel(
                      icon: Icons.alt_route_rounded,
                      label: 'Route (${route.length} stops)'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE4F0FF)),
                    ),
                    child: Column(
                      children:
                          route.asMap().entries.map((e) {
                        final isLast = e.key == route.length - 1;
                        return Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Column(children: [
                              Container(
                                width: 26,
                                height: 26,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [_kBlue, _kCyan],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
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
                              if (!isLast)
                                Container(
                                  width: 2,
                                  height: 20,
                                  margin: const EdgeInsets.symmetric(
                                      vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _kBlue.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                ),
                            ]),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                    top: 4,
                                    bottom: isLast ? 0 : 16),
                                child: Text(_routeLabel(e.value),
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[700])),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],

                // List items
                if (listItems.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _BodyLabel(
                      icon: Icons.checklist_rounded,
                      label: 'Checklist (${listItems.length})'),
                  const SizedBox(height: 8),
                  ...listItems.map((item) {
                    final isChecklist =
                        (item is Map ? item['type'] : null) ==
                            'checklist';
                    final checked =
                        item is Map ? (item['checked'] as bool? ?? false) : false;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(children: [
                        if (isChecklist)
                          Icon(
                            checked
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 18,
                            color: checked
                                ? _kBlue
                                : Colors.grey[350],
                          )
                        else
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                  colors: [_kBlue, _kCyan]),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _itemLabel(item),
                            style: TextStyle(
                              fontSize: 13,
                              color: checked
                                  ? Colors.grey[400]
                                  : Colors.grey[700],
                              decoration: checked
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                      ]),
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ]),
    );
  }
}

// ── Section body label ────────────────────────────────────────────────────────

class _BodyLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _BodyLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          gradient:
              const LinearGradient(colors: [_kBlue, _kCyan]),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(icon, size: 12, color: Colors.white),
      ),
      const SizedBox(width: 7),
      Text(label,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _kDarkBlue)),
    ]);
  }
}

// ── Place row ─────────────────────────────────────────────────────────────────

class _PlaceRow extends StatelessWidget {
  final dynamic place;
  const _PlaceRow({required this.place});

  @override
  Widget build(BuildContext context) {
    final name = place is Map
        ? (place['name'] ?? place['placeName'] ?? 'Unknown')
            .toString()
        : place.toString();
    final address =
        place is Map ? (place['address'] ?? '').toString() : '';
    final description =
        place is Map ? (place['description'] ?? '').toString() : '';
    final imageUrl = place is Map
        ? (place['photoUrl'] ?? place['image'] ?? '').toString()
        : '';
    final category =
        place is Map ? (place['category'] ?? 'other').toString() : 'other';
    final catMeta = _categories.firstWhere(
      (c) => c.value == category,
      orElse: () => _categories.last,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4F0FF)),
        boxShadow: [
          BoxShadow(
            color: _kBlue.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Category left bar
          Container(
            width: 4,
            decoration: BoxDecoration(
              color: catMeta.color,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                bottomLeft: Radius.circular(14),
              ),
            ),
          ),
          // Thumbnail
          if (imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.zero,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                width: 64,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _PlaceholderThumb(),
              ),
            ),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(catMeta.icon, size: 13, color: catMeta.color),
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: catMeta.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(catMeta.label,
                          style: TextStyle(
                              fontSize: 10,
                              color: catMeta.color,
                              fontWeight: FontWeight.w600)),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: _kDark),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(description,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[500]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ] else if (address.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(address,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[500]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _PlaceholderThumb extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 64,
        color: const Color(0xFFEFF6FF),
        child: const Icon(Icons.place_outlined, color: _kBlue, size: 22),
      );
}

// ── Comment input bar ─────────────────────────────────────────────────────────

class _CommentInputBar extends StatelessWidget {
  final dynamic auth;
  final TextEditingController controller;
  final bool submitting;
  final VoidCallback onSubmit;
  final VoidCallback onLoginTap;

  const _CommentInputBar({
    required this.auth,
    required this.controller,
    required this.submitting,
    required this.onSubmit,
    required this.onLoginTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE5E7EB))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: auth.isAuthenticated
              ? Row(children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      maxLines: null,
                      style: const TextStyle(fontSize: 14, color: _kDark),
                      decoration: InputDecoration(
                        hintText: 'Write a comment...',
                        hintStyle: TextStyle(
                            color: Colors.grey[400], fontSize: 13),
                        filled: true,
                        fillColor: _kInputFill,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide:
                              const BorderSide(color: _kInputBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide:
                              const BorderSide(color: _kInputBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(
                              color: _kBlue, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: submitting ? null : onSubmit,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: submitting
                            ? null
                            : const LinearGradient(
                                colors: [_kBlue, _kCyan]),
                        color: submitting ? Colors.grey[200] : null,
                        shape: BoxShape.circle,
                      ),
                      child: submitting
                          ? const Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: _kBlue),
                              ),
                            )
                          : const Icon(Icons.send_rounded,
                              color: Colors.white, size: 18),
                    ),
                  ),
                ])
              : SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onLoginTap,
                    icon: const Icon(Icons.login_rounded, size: 18),
                    label: const Text('Login to leave a comment'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kBlue,
                      side: const BorderSide(color: _kBlue),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

// ── Comment tile ──────────────────────────────────────────────────────────────

class _CommentTile extends StatelessWidget {
  final CommentModel comment;
  final bool isOwner, isEditing;
  final TextEditingController editCtrl;
  final VoidCallback onEdit, onDelete, onSaveEdit, onCancelEdit;

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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Avatar
        CircleAvatar(
          radius: 18,
          backgroundColor: _kBlue.withValues(alpha: 0.15),
          backgroundImage:
              (comment.user.profilePicture?.isNotEmpty ?? false)
                  ? NetworkImage(comment.user.profilePicture!)
                  : null,
          child: (comment.user.profilePicture?.isEmpty ?? true)
              ? Text(
                  comment.user.username.isNotEmpty
                      ? comment.user.username[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _kBlue))
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
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: _kDark)),
                const Spacer(),
                if (isOwner) ...[
                  GestureDetector(
                    onTap: onEdit,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: _kBlue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Icon(Icons.edit_outlined,
                          size: 13, color: _kBlue),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: onDelete,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Icon(Icons.delete_outline,
                          size: 13, color: Color(0xFFDC2626)),
                    ),
                  ),
                ],
              ]),
              const SizedBox(height: 4),
              if (isEditing) ...[
                TextField(
                  controller: editCtrl,
                  autofocus: true,
                  style: const TextStyle(fontSize: 13, color: _kDark),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: _kInputFill,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: _kInputBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: _kBlue, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(children: [
                  TextButton(
                    onPressed: onSaveEdit,
                    style: TextButton.styleFrom(
                      foregroundColor: _kBlue,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Save',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: onCancelEdit,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Cancel'),
                  ),
                ]),
              ] else ...[
                Text(comment.content,
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        height: 1.4)),
              ],
            ],
          ),
        ),
      ]),
    );
  }
}
