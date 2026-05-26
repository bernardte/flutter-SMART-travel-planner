// lib/screens/saved/saved_screen.dart
// Replaces frontend/src/pages/saved/SavedPostPage.tsx

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../repositories/favourite_repository.dart';
import '../../providers/community_provider.dart';
import '../../models/travel_guide_model.dart';
import '../../widgets/card/guide_card.dart';
import '../../core/utils/snackbar.dart';

class SavedScreen extends ConsumerStatefulWidget {
  const SavedScreen({super.key});

  @override
  ConsumerState<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends ConsumerState<SavedScreen> {
  List<TravelGuideModel> _saved = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(favouriteRepositoryProvider);
      final items = await repo.getAllFavourites();
      setState(() { _saved = items; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved Guides')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _saved.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bookmark_border, size: 72, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        const Text('No saved guides yet',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 6),
                        Text('Browse the community and save guides you love',
                            style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () => context.go('/community-guide'),
                          icon: const Icon(Icons.explore_outlined, size: 18),
                          label: const Text('Browse Community'),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _saved.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final guide = _saved[i];
                      return GuideCard(
                        guide: guide,
                        onTap: () {
                          final itinId = guide.itinerary?['_id'];
                          if (itinId != null) context.go('/trip-plan/view/$itinId');
                        },
                        onLike: () => ref.read(communityProvider.notifier).toggleLike(guide.id),
                        onSave: () async {
                          await ref.read(communityProvider.notifier).toggleSave(guide.id);
                          // Remove from saved list since it was unsaved
                          setState(() => _saved.removeWhere((g) => g.id == guide.id));
                        },
                      );
                    },
                  ),
      ),
    );
  }
}
