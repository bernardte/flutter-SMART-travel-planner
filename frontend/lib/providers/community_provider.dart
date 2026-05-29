// lib/providers/community_provider.dart
// Replaces frontend/src/stores/useCommunityTravelGuideStore.ts

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/travel_guide_model.dart';
import '../repositories/community_repository.dart';

class CommunityState {
  final List<TravelGuideModel> publicPosts;
  final List<TravelGuideModel> recommendedGuides;
  final List<TravelGuideModel> followersGuides;
  final bool isLoading;
  final String? error;

  const CommunityState({
    this.publicPosts = const [],
    this.recommendedGuides = const [],
    this.followersGuides = const [],
    this.isLoading = false,
    this.error,
  });

  CommunityState copyWith({
    List<TravelGuideModel>? publicPosts,
    List<TravelGuideModel>? recommendedGuides,
    List<TravelGuideModel>? followersGuides,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      CommunityState(
        publicPosts: publicPosts ?? this.publicPosts,
        recommendedGuides: recommendedGuides ?? this.recommendedGuides,
        followersGuides: followersGuides ?? this.followersGuides,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : error ?? this.error,
      );
}

class CommunityNotifier extends StateNotifier<CommunityState> {
  final CommunityRepository _repo;
  CommunityNotifier(this._repo) : super(const CommunityState());

  Future<void> fetchPublicPosts() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final posts = await _repo.getAllPublicPosts();
      print("Posts: $posts");
      state = state.copyWith(publicPosts: posts, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> fetchRecommendedGuides() async {
    try {
      final guides = await _repo.getRecommendedGuides();
      state = state.copyWith(recommendedGuides: guides);
    } catch (_) {}
  }

  Future<void> fetchFollowersGuides() async {
    try {
      final guides = await _repo.getFollowersGuides();
      state = state.copyWith(followersGuides: guides);
    } catch (_) {}
  }

  Future<void> toggleLike(String postId) async {
    try {
      final data = await _repo.likeUnlikePost(postId);
      _updateGuideInLists(postId, (g) => g.copyWith(
            likes: data['likes'],
            isLiked: data['isLiked'],
          ));
    } catch (_) {}
  }

  Future<void> toggleSave(String postId) async {
    try {
      final data = await _repo.savePost(postId);
      _updateGuideInLists(postId, (g) => g.copyWith(
            saves: data['saves'],
            isSaved: data['isSaved'],
          ));
    } catch (_) {}
  }

  Future<bool> deletePost(String postId) async {
    try {
      await _repo.deletePost(postId);
      state = state.copyWith(
        publicPosts: state.publicPosts.where((g) => g.id != postId).toList(),
        followersGuides:
            state.followersGuides.where((g) => g.id != postId).toList(),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  void addPost(TravelGuideModel guide) {
    state = state.copyWith(
      followersGuides: [guide, ...state.followersGuides],
    );
  }

  void updatePost(TravelGuideModel updated) {
    _updateGuideInLists(updated.id, (_) => updated);
  }

  void _updateGuideInLists(
    String id, TravelGuideModel Function(TravelGuideModel) updater) {
    TravelGuideModel update(TravelGuideModel g) =>  // remove the ? here
        g.id == id ? updater(g) : g;

    state = state.copyWith(
      publicPosts: state.publicPosts.map(update).toList(),
      followersGuides: state.followersGuides.map(update).toList(),
      recommendedGuides: state.recommendedGuides.map(update).toList(),
    );
  }
}

final communityProvider =
    StateNotifierProvider<CommunityNotifier, CommunityState>((ref) {
  return CommunityNotifier(ref.read(communityRepositoryProvider));
});
