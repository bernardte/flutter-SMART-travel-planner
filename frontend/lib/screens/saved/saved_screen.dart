// lib/screens/saved/saved_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../repositories/favourite_repository.dart';
import '../../providers/community_provider.dart';
import '../../models/travel_guide_model.dart';
import '../../widgets/card/guide_card.dart';

class SavedScreen extends ConsumerStatefulWidget {
  const SavedScreen({super.key});

  @override
  ConsumerState<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends ConsumerState<SavedScreen> {
  List<TravelGuideModel> _saved = [];
  bool _initialLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(favouriteRepositoryProvider);
      final items = await repo.getAllFavourites();
      setState(() {
        _saved = items;
        _initialLoading = false;
      });
    } catch (_) {
      setState(() => _initialLoading = false);
    }
  }

  void _updateGuide(String id, TravelGuideModel Function(TravelGuideModel) updater) {
    setState(() {
      _saved = _saved.map((g) => g.id == id ? updater(g) : g).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F9FF),
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _load,
        color: const Color(0xFF3B82F6),
        child: _initialLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
              )
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader()),
                  _saved.isEmpty
                      ? SliverFillRemaining(child: _buildEmptyState())
                      : SliverPadding(
                          padding: const EdgeInsets.all(16),
                          sliver: SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 340,
                              childAspectRatio: 0.83,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 20,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, i) {
                                final guide = _saved[i];
                                return TweenAnimationBuilder(
                                  tween: Tween<double>(begin: 0, end: 1),
                                  duration:
                                      Duration(milliseconds: 300 + (i * 30)),
                                  builder: (context, value, child) => Opacity(
                                    opacity: value,
                                    child: Transform.translate(
                                      offset: Offset(0, 20 * (1 - value)),
                                      child: child,
                                    ),
                                  ),
                                  child: GuideCard(
                                    guide: guide,
                                    isLiked: guide.isLiked,
                                    isSaved: guide.isSaved,
                                    likedCount: guide.likes,
                                    onTap: () {
                                      final itinId = guide.itinerary?['_id'];
                                      if (itinId != null) {
                                        context.go('/trip-plan/view/$itinId');
                                      }
                                    },
                                    onLike: () {
                                      // Optimistic update so heart toggles instantly
                                      _updateGuide(
                                        guide.id,
                                        (g) => g.copyWith(
                                          isLiked: !g.isLiked,
                                          likes: g.isLiked
                                              ? g.likes - 1
                                              : g.likes + 1,
                                        ),
                                      );
                                      ref
                                          .read(communityProvider.notifier)
                                          .toggleLike(guide.id);
                                    },
                                    onSave: () async {
                                      await ref
                                          .read(communityProvider.notifier)
                                          .toggleSave(guide.id);
                                      setState(() => _saved
                                          .removeWhere((g) => g.id == guide.id));
                                    },
                                  ),
                                );
                              },
                              childCount: _saved.length,
                            ),
                          ),
                        ),
                ],
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
            child: const Icon(Icons.bookmark, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Text(
            'Saved Guides',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 22,
              color: Color(0xFF1E3A8A),
            ),
          ),
        ],
      ),
      centerTitle: false,
      backgroundColor: Colors.white,
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: Colors.grey[100]),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your travel wishlist 🔖',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _saved.isEmpty
                ? 'Save guides from the community to plan your next trip.'
                : '${_saved.length} guide${_saved.length == 1 ? '' : 's'} saved — ready for your next adventure.',
            style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bookmark_border, size: 90, color: Colors.grey[300]),
          const SizedBox(height: 20),
          Text(
            'No saved guides yet',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Browse the community and tap 🔖 to save guides you love.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[400]),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: () => context.go('/community-guide'),
            icon: const Icon(Icons.explore_outlined, size: 18),
            label: const Text('Browse Community'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(40),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}
