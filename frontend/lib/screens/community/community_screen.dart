// lib/screens/community/community_screen.dart
// Replaces frontend/src/pages/community/CommunityPage.tsx

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/community_provider.dart';
import '../../models/travel_guide_model.dart';
import '../../widgets/card/guide_card.dart';

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(communityProvider.notifier).fetchPublicPosts());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<TravelGuideModel> _filtered(List<TravelGuideModel> posts) {
    if (_searchQuery.isEmpty) return posts;
    final q = _searchQuery.toLowerCase();
    return posts.where((p) =>
        p.title.toLowerCase().contains(q) ||
        p.country.toLowerCase().contains(q) ||
        p.tags.any((t) => t.toLowerCase().contains(q)) ||
        (p.author?.username.toLowerCase().contains(q) ?? false)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final community = ref.watch(communityProvider);
    final auth = ref.watch(authProvider);
    final filtered = _filtered(community.publicPosts);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Guides'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search guides, countries, tags...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(communityProvider.notifier).fetchPublicPosts(),
        child: community.isLoading
            ? const Center(child: CircularProgressIndicator())
            : filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.explore_off_outlined, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No guides match "$_searchQuery"'
                              : 'No community guides yet',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final guide = filtered[i];
                      final isOwner = auth.user?.id == guide.author?.id;
                      return GuideCard(
                        guide: guide,
                        isOwner: isOwner,
                        onTap: () {
                          final itinId = guide.itinerary?['_id'];
                          if (itinId != null) context.go('/trip-plan/view/$itinId');
                        },
                        onLike: auth.isAuthenticated
                            ? () => ref.read(communityProvider.notifier).toggleLike(guide.id)
                            : () => context.go('/auth'),
                        onSave: auth.isAuthenticated
                            ? () => ref.read(communityProvider.notifier).toggleSave(guide.id)
                            : () => context.go('/auth'),
                        onDelete: isOwner
                            ? () => _confirmDelete(context, guide.id)
                            : null,
                      );
                    },
                  ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, String postId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this guide?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(communityProvider.notifier).deletePost(postId);
    }
  }
}
