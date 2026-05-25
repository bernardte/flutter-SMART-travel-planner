// lib/screens/trip_plan/view_trip_plan_screen.dart
// Replaces frontend/src/pages/TripPlan/viewTripPlanPage.tsx

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart'; // for Clipboard
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
      setState(() {
        _tripPlan = plan;
        _comments = comments;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) AppSnackbar.error(context, 'Failed to load: $e');
    }
  }

  Future<void> _submitComment() async {
    if (_commentCtrl.text.trim().isEmpty) return;
    setState(() => _submittingComment = true);
    try {
      final repo = ref.read(tripPlanRepositoryProvider);
      final comment = await repo.createComment(widget.tripPlanId, _commentCtrl.text.trim());
      setState(() { _comments.add(comment); _commentCtrl.clear(); });
    } catch (e) {
      AppSnackbar.error(context, 'Failed to post comment');
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
      AppSnackbar.error(context, 'Failed to delete comment');
    }
  }

  Future<void> _saveEditComment(String commentId) async {
    if (_editCtrl.text.trim().isEmpty) return;
    try {
      final repo = ref.read(tripPlanRepositoryProvider);
      final updated = await repo.updateComment(widget.tripPlanId, commentId, _editCtrl.text.trim());
      setState(() {
        _comments = _comments.map((c) => c.id == commentId ? updated : c).toList();
        _editingCommentId = null;
      });
    } catch (_) {
      AppSnackbar.error(context, 'Failed to update comment');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final plan = _tripPlan;
    if (plan == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Guide not found')),
      );
    }

    final auth = ref.watch(authProvider);
    final user = auth.user;
    final authorId = plan['author']?['_id'] ?? plan['authorId']?['_id'];
    final isOwner = user?.id == authorId;
    final thumbnailUrl = plan['thumbnailImage'] as String?;

    return Scaffold(
      appBar: AppBar(
        title: Text(plan['title'] ?? 'Travel Guide', overflow: TextOverflow.ellipsis),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
                Clipboard.setData(ClipboardData(text: 'Check out this travel guide: ${plan['title']}'));
                AppSnackbar.success(context, 'Link copied to clipboard!');
              },
          ),
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.go('/edit-travel-guide/${widget.tripPlanId}'),
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
                  // Thumbnail
                  if (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: CachedNetworkImage(
                        imageUrl: thumbnailUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: Colors.grey[200]),
                        errorWidget: (_, __, ___) => Container(color: Colors.grey[200]),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title + country badge
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(plan['title'] ?? '',
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(plan['country'] ?? '',
                                  style: TextStyle(fontSize: 12, color: Colors.blue[700], fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Author row
                        if (plan['author'] != null || plan['authorId'] != null) ...[
                          GestureDetector(
                            onTap: () {
                              final username = (plan['author'] ?? plan['authorId'])['username'];
                              if (username != null) context.go('/profile/$username');
                            },
                            child: Row(children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundImage: NetworkImage(
                                  (plan['author'] ?? plan['authorId'])['profilePicture'] ??
                                      'https://ui-avatars.com/api/?name=user&background=8b5cf6&color=fff',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '@${(plan['author'] ?? plan['authorId'])['username'] ?? ''}',
                                style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: plan['privacy'] == 'private' ? Colors.orange[50] : Colors.green[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  plan['privacy'] ?? 'public',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: plan['privacy'] == 'private' ? Colors.orange[700] : Colors.green[700],
                                  ),
                                ),
                              ),
                            ]),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Description
                        Text(plan['description'] ?? '', style: TextStyle(fontSize: 15, color: Colors.grey[700], height: 1.5)),

                        // Tags
                        if ((plan['tags'] as List?)?.isNotEmpty ?? false) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 6,
                            children: (plan['tags'] as List).map((tag) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.cyan[50], borderRadius: BorderRadius.circular(20)),
                              child: Text('#$tag', style: TextStyle(fontSize: 12, color: Colors.cyan[700])),
                            )).toList(),
                          ),
                        ],

                        // Stats row
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _StatChip(icon: Icons.favorite_border, value: '${plan['likes'] ?? 0}', label: 'Likes',
                              onTap: auth.isAuthenticated
                                  ? () { ref.read(communityProvider.notifier).toggleLike(widget.tripPlanId); }
                                  : null),
                            const SizedBox(width: 12),
                            _StatChip(icon: Icons.visibility_outlined, value: '${plan['views'] ?? 0}', label: 'Views'),
                            const SizedBox(width: 12),
                            _StatChip(icon: Icons.chat_bubble_outline, value: '${_comments.length}', label: 'Comments'),
                          ],
                        ),

                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 8),

                        // Comments section
                        Text('Comments (${_comments.length})',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),

                        if (_comments.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text('No comments yet. Be the first!',
                                  style: TextStyle(color: Colors.grey[400])),
                            ),
                          )
                        else
                          ...(_comments.map((c) => _CommentTile(
                            comment: c,
                            isOwner: user?.id == c.user.id,
                            isEditing: _editingCommentId == c.id,
                            editCtrl: _editCtrl,
                            onEdit: () {
                              _editCtrl.text = c.content;
                              setState(() => _editingCommentId = c.id);
                            },
                            onDelete: () => _deleteComment(c.id!),
                            onSaveEdit: () => _saveEditComment(c.id!),
                            onCancelEdit: () => setState(() => _editingCommentId = null),
                          ))),

                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Comment input bar (pinned to bottom)
          if (auth.isAuthenticated)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, -2))],
              ),
              child: SafeArea(
                top: false,
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _commentCtrl,
                      decoration: const InputDecoration(hintText: 'Write a comment...', isDense: true, contentPadding: EdgeInsets.all(10)),
                      maxLines: null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _submittingComment ? null : _submitComment,
                    icon: _submittingComment
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send_rounded, color: Color(0xFF3B82F6)),
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

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final VoidCallback? onTap;

  const _StatChip({required this.icon, required this.value, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text('$value $label', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        ]),
      ),
    );
  }
}

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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundImage: NetworkImage(
              comment.user.profilePicture ??
                  'https://ui-avatars.com/api/?name=${comment.user.username}&background=8b5cf6&color=fff',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('@${comment.user.username}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const Spacer(),
                  if (isOwner) ...[
                    GestureDetector(onTap: onEdit, child: Icon(Icons.edit_outlined, size: 16, color: Colors.blue[400])),
                    const SizedBox(width: 8),
                    GestureDetector(onTap: onDelete, child: Icon(Icons.delete_outline, size: 16, color: Colors.red[400])),
                  ],
                ]),
                if (isEditing) ...[
                  const SizedBox(height: 4),
                  TextField(
                    controller: editCtrl,
                    decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                    autofocus: true,
                  ),
                  const SizedBox(height: 6),
                  Row(children: [
                    TextButton(onPressed: onSaveEdit, child: const Text('Save')),
                    TextButton(onPressed: onCancelEdit, child: const Text('Cancel')),
                  ]),
                ] else ...[
                  const SizedBox(height: 4),
                  Text(comment.content, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
