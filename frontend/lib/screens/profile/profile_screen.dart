// lib/screens/profile/profile_screen.dart
// Replaces frontend/src/pages/profile/ProfilePage.tsx

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/user_repository.dart';
import '../../models/user_model.dart';
import '../../models/travel_guide_model.dart';
import '../../core/utils/snackbar.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final String username;
  const ProfileScreen({super.key, required this.username});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  UserModel? _profileUser;
  List<TravelGuideModel> _publishedGuides = [];
  Map<String, dynamic> _stats = {};
  bool _loading = true;
  bool _isFollowing = false;
  bool _followLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(userRepositoryProvider);
      final user = await repo.getUserProfile(widget.username);
      final stats = await repo.getUserProfileStats(widget.username);
      final guides = await repo.getUserPublishTravelGuide(user.id);
      final currentUser = ref.read(authProvider).user;

      setState(() {
        _profileUser = user;
        _stats = stats;
        _publishedGuides = guides
            .map((g) => TravelGuideModel.fromJson(g as Map<String, dynamic>))
            .toList();
        _isFollowing = currentUser != null && user.followers.contains(currentUser.id);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) AppSnackbar.error(context, 'Failed to load profile: $e');
    }
  }

  Future<void> _toggleFollow() async {
    final currentUser = ref.read(authProvider).user;
    if (currentUser == null) { context.go('/auth'); return; }

    setState(() => _followLoading = true);
    try {
      final repo = ref.read(userRepositoryProvider);
      await repo.followUnfollowUser(_profileUser!.id);
      setState(() {
        _isFollowing = !_isFollowing;
        _profileUser = UserModel(
          id: _profileUser!.id,
          email: _profileUser!.email,
          username: _profileUser!.username,
          name: _profileUser!.name,
          profilePicture: _profileUser!.profilePicture,
          bio: _profileUser!.bio,
          followers: _isFollowing
              ? [..._profileUser!.followers, currentUser.id]
              : _profileUser!.followers.where((id) => id != currentUser.id).toList(),
          following: _profileUser!.following,
        );
      });
    } catch (e) {
      AppSnackbar.error(context, 'Failed: $e');
    } finally {
      if (mounted) setState(() => _followLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final user = _profileUser;
    if (user == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('User not found')));
    }

    final currentUser = ref.watch(authProvider).user;
    final isOwnProfile = currentUser?.username == widget.username;

    return Scaffold(
      appBar: AppBar(
        title: Text('@${user.username}'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        actions: [
          if (isOwnProfile)
            IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _showEditSheet(context, currentUser!)),
          if (isOwnProfile)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) context.go('/home');
              },
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // Profile header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue[50]!, Colors.white],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundImage: user.profilePicture != null
                          ? CachedNetworkImageProvider(user.profilePicture!)
                          : NetworkImage(
                              'https://ui-avatars.com/api/?name=${user.name}&background=3b82f6&color=fff&size=128',
                            ) as ImageProvider,
                    ),
                    const SizedBox(height: 12),
                    Text(user.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Text('@${user.username}', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                    if (user.bio != null && user.bio!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(user.bio!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    ],
                    const SizedBox(height: 16),
                    // Stats row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _ProfileStat(value: '${user.followers.length}', label: 'Followers'),
                        _ProfileStat(value: '${user.following.length}', label: 'Following'),
                        _ProfileStat(value: '${_stats['totalTrips'] ?? _publishedGuides.length}', label: 'Guides'),
                      ],
                    ),
                    if (!isOwnProfile) ...[
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _followLoading ? null : _toggleFollow,
                        icon: _followLoading
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Icon(_isFollowing ? Icons.person_remove_outlined : Icons.person_add_outlined, size: 18),
                        label: Text(_isFollowing ? 'Unfollow' : 'Follow'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isFollowing ? Colors.grey[200] : null,
                          foregroundColor: _isFollowing ? Colors.black87 : null,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Published guides
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Published Guides (${_publishedGuides.length})',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    if (_publishedGuides.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text('No published guides yet', style: TextStyle(color: Colors.grey[400])),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _publishedGuides.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final guide = _publishedGuides[i];
                          return Card(
                            clipBehavior: Clip.antiAlias,
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(12),
                              leading: guide.thumbnailImage.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: CachedNetworkImage(
                                        imageUrl: guide.thumbnailImage,
                                        width: 56,
                                        height: 56,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Container(
                                      width: 56, height: 56,
                                      decoration: BoxDecoration(color: Colors.blue[100], borderRadius: BorderRadius.circular(8)),
                                      child: Icon(Icons.travel_explore, color: Colors.blue[400]),
                                    ),
                              title: Text(guide.title,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(guide.country, style: TextStyle(color: Colors.blue[600], fontSize: 12)),
                                  Row(children: [
                                    Icon(Icons.favorite_border, size: 12, color: Colors.grey[400]),
                                    const SizedBox(width: 2),
                                    Text('${guide.likes}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                                  ]),
                                ],
                              ),
                              onTap: () {
                                final itinId = guide.itinerary?['_id'];
                                if (itinId != null) context.go('/trip-plan/view/$itinId');
                              },
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditSheet(BuildContext context, UserModel user) {
    final usernameCtrl = TextEditingController(text: user.username);
    final bioCtrl = TextEditingController(text: user.bio ?? '');
    File? newPicture;
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Edit Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Center(
                child: GestureDetector(
                  onTap: () async {
                    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
                    if (picked != null) setModal(() => newPicture = File(picked.path));
                  },
                  child: CircleAvatar(
                    radius: 36,
                    backgroundImage: newPicture != null
                        ? FileImage(newPicture!) as ImageProvider
                        : (user.profilePicture != null ? CachedNetworkImageProvider(user.profilePicture!) : null),
                    child: newPicture == null && user.profilePicture == null
                        ? const Icon(Icons.person, size: 36)
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Center(child: Text('Tap to change photo', style: TextStyle(fontSize: 11, color: Colors.grey))),
              const SizedBox(height: 12),
              TextField(controller: usernameCtrl, decoration: const InputDecoration(labelText: 'Username')),
              const SizedBox(height: 12),
              TextField(controller: bioCtrl, decoration: const InputDecoration(labelText: 'Bio'), maxLines: 3),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: saving ? null : () async {
                    setModal(() => saving = true);
                    try {
                      final repo = ref.read(userRepositoryProvider);
                      final updated = await repo.updateUserProfile(
                        username: usernameCtrl.text.trim(),
                        bio: bioCtrl.text.trim(),
                        profilePicture: newPicture,
                      );
                      ref.read(authProvider.notifier).updateUser(updated);
                      if (ctx.mounted) Navigator.pop(ctx);
                      AppSnackbar.success(context, 'Profile updated!');
                      _load();
                    } catch (e) {
                      AppSnackbar.error(context, 'Failed: $e');
                    } finally {
                      setModal(() => saving = false);
                    }
                  },
                  child: saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String value, label;
  const _ProfileStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
    ]);
  }
}
