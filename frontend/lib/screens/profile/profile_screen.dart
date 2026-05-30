// lib/screens/profile/profile_screen.dart

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
  bool _loading = true;
  bool _isFollowing = false;
  bool _followLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final repo = ref.read(userRepositoryProvider);
      final user = await repo.getUserProfile(widget.username);
      final guides = await repo.getUserPublishTravelGuide(user.id);
      print("your guide: $guides");
      final currentUser = ref.read(authProvider).user;
      if (!mounted) return;
      setState(() {
        _profileUser = user;
        _publishedGuides = guides
            .whereType<Map>()
            .map((g) => TravelGuideModel.fromJson(Map<String, dynamic>.from(g)))
            .toList();
        _isFollowing =
            currentUser != null && user.followers.contains(currentUser.id);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppSnackbar.error(context, 'Failed to load profile: $e');
    }
  }

  Future<void> _toggleFollow() async {
    final user = _profileUser;
    if (user == null) return;
    final currentUser = ref.read(authProvider).user;
    if (currentUser == null) {
      context.go('/auth');
      return;
    }
    setState(() => _followLoading = true);
    try {
      await ref.read(userRepositoryProvider).followUnfollowUser(user.id);
      if (!mounted) return;
      setState(() {
        _isFollowing = !_isFollowing;
        _profileUser = UserModel(
          id: user.id,
          email: user.email,
          username: user.username,
          name: user.name,
          profilePicture: user.profilePicture,
          bio: user.bio,
          followers: _isFollowing
              ? [...user.followers, currentUser.id]
              : user.followers.where((id) => id != currentUser.id).toList(),
          following: user.following,
        );
      });
    } catch (e) {
      if (mounted) AppSnackbar.error(context, 'Failed: $e');
    } finally {
      if (mounted) setState(() => _followLoading = false);
    }
  }

  int get _totalLikes =>
      _publishedGuides.fold(0, (sum, g) => sum + g.likes);

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    final user = _profileUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/home'),
          ),
        ),
        body: const Center(child: Text('User not found')),
      );
    }

    final currentUser = ref.watch(authProvider).user;
    final isOwnProfile = currentUser?.username == widget.username;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F9FF),
      body: RefreshIndicator(
        onRefresh: _load,
        color: const Color(0xFF3B82F6),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: const Color(0xFF1D4ED8),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go('/home'),
              ),
              title: Text(
                '@${user.username}',
                style: const TextStyle(
                    color: Colors.white, fontSize: 16),
              ),
              actions: [
                if (isOwnProfile) ...[
                  IconButton(
                    icon: const Icon(Icons.edit_outlined,
                        color: Colors.white),
                    tooltip: 'Edit profile',
                    onPressed: () =>
                        _showEditSheet(context, currentUser!),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout,
                        color: Colors.white),
                    tooltip: 'Logout',
                    onPressed: () async {
                      await ref.read(authProvider.notifier).logout();
                      if (context.mounted) context.go('/home');
                    },
                  ),
                ],
              ],
            ),

            SliverToBoxAdapter(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 120,
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF1D4ED8),
                          Color(0xFF0891B2),
                        ],
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: -30,
                          right: -30,
                          child: Container(
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white
                                  .withValues(alpha: 0.07),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: -20,
                          left: -20,
                          child: Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white
                                  .withValues(alpha: 0.05),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 80, 16, 16),
                    child: _ProfileCard(
                      user: user,
                      isOwnProfile: isOwnProfile,
                      isFollowing: _isFollowing,
                      followLoading: _followLoading,
                      guidesCount: _publishedGuides.length,
                      totalLikes: _totalLikes,
                      onFollow: _toggleFollow,
                    ),
                  ),
                ],
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 18,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Published Guides (${_publishedGuides.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            _publishedGuides.isEmpty
                ? SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyGuides(isOwnProfile: isOwnProfile),
                  )
                : SliverPadding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final guide = _publishedGuides[i];
                          return Padding(
                            padding:
                                const EdgeInsets.only(bottom: 12),
                            child: _GuideCard(
                              guide: guide,
                              onTap: () {
                                final itinId =
                                    guide.itinerary?['_id'];
                                if (itinId != null) {
                                  context.push(
                                      '/trip-plan/view/$itinId');
                                }
                              },
                            ),
                          );
                        },
                        childCount: _publishedGuides.length,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  void _showEditSheet(BuildContext context, UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // FIX: use a proper ConsumerStatefulWidget instead of StatefulBuilder.
      // StatefulBuilder has no real mounted check — ctx.mounted reflects the
      // route context, not the builder's state, so setState() (setModal) can
      // fire after the sheet is disposed, causing the
      // '_dependents.isEmpty' assertion crash.
      // A real StatefulWidget has a correct mounted lifecycle that becomes
      // false the moment the widget is removed from the tree.
      builder: (ctx) => _EditProfileSheet(
        user: user,
        onSaved: () {
          if (mounted) {
            AppSnackbar.success(context, 'Profile updated!');
            _load();
          }
        },
        onError: (e) {
          if (mounted) AppSnackbar.error(context, 'Failed: $e');
        },
      ),
    );
  }
}

// ── Profile card (avatar + info + stats + follow button) ─────────────────────

class _ProfileCard extends StatelessWidget {
  final UserModel user;
  final bool isOwnProfile;
  final bool isFollowing;
  final bool followLoading;
  final int guidesCount;
  final int totalLikes;
  final VoidCallback onFollow;

  const _ProfileCard({
    required this.user,
    required this.isOwnProfile,
    required this.isFollowing,
    required this.followLoading,
    required this.guidesCount,
    required this.totalLikes,
    required this.onFollow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.blue[100],
                backgroundImage: user.profilePicture != null
                    ? CachedNetworkImageProvider(user.profilePicture!)
                    : NetworkImage(
                            'https://ui-avatars.com/api/?name=${Uri.encodeComponent(user.name)}&background=3b82f6&color=fff&size=128')
                        as ImageProvider,
              ),
              if (user.isVerified)
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.verified_rounded,
                        size: 22, color: Color(0xFF3B82F6)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          Text(
            user.name,
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 3),

          Text('@${user.username}',
              style: TextStyle(color: Colors.grey[500], fontSize: 14)),

          if (user.bio != null && user.bio!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              user.bio!,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: Colors.grey[600], fontSize: 13, height: 1.5),
            ),
          ],

          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),

          IntrinsicHeight(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatItem(
                    value: '${user.followers.length}',
                    label: 'Followers'),
                const _VerticalDivider(),
                _StatItem(
                    value: '${user.following.length}',
                    label: 'Following'),
                const _VerticalDivider(),
                _StatItem(
                    value: '$guidesCount', label: 'Guides'),
                const _VerticalDivider(),
                _StatItem(
                    value: '$totalLikes',
                    label: 'Likes',
                    color: const Color(0xFFEF4444)),
              ],
            ),
          ),

          if (!isOwnProfile) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                child: ElevatedButton.icon(
                  onPressed: followLoading ? null : onFollow,
                  icon: followLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Icon(
                          isFollowing
                              ? Icons.person_remove_outlined
                              : Icons.person_add_outlined,
                          size: 18),
                  label: Text(isFollowing ? 'Unfollow' : 'Follow'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isFollowing
                        ? Colors.grey[200]
                        : const Color(0xFF3B82F6),
                    foregroundColor: isFollowing
                        ? Colors.black87
                        : Colors.white,
                    padding:
                        const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: isFollowing ? 0 : 2,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Guide card ────────────────────────────────────────────────────────────────

class _GuideCard extends StatelessWidget {
  final TravelGuideModel guide;
  final VoidCallback onTap;
  const _GuideCard({required this.guide, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(16)),
              child: SizedBox(
                width: 90,
                height: 90,
                child: guide.thumbnailImage.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: guide.thumbnailImage,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            _GuidePlaceholder(),
                      )
                    : _GuidePlaceholder(),
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      guide.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        guide.country,
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _MiniStat(
                            icon: Icons.favorite,
                            color: const Color(0xFFEF4444),
                            value: guide.likes),
                        const SizedBox(width: 12),
                        _MiniStat(
                            icon: Icons.bookmark,
                            color: const Color(0xFF3B82F6),
                            value: guide.saves),
                        const SizedBox(width: 12),
                        _MiniStat(
                            icon: Icons.visibility,
                            color: Colors.grey,
                            value: guide.views),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.chevron_right,
                  color: Colors.grey, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Small reusable widgets ────────────────────────────────────────────────────

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final Color? color;
  const _StatItem(
      {required this.value, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color ?? const Color(0xFF1E3A8A),
          ),
        ),
        const SizedBox(height: 2),
        Text(label,
            style:
                TextStyle(fontSize: 11, color: Colors.grey[500])),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: Colors.grey[200],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int value;
  const _MiniStat(
      {required this.icon, required this.color, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text('$value',
            style:
                TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }
}

class _GuidePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.blue[50],
      child: Icon(Icons.travel_explore,
          color: Colors.blue[200], size: 32),
    );
  }
}

class _EmptyGuides extends StatelessWidget {
  final bool isOwnProfile;
  const _EmptyGuides({required this.isOwnProfile});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.map_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            isOwnProfile
                ? "You haven't published any guides yet"
                : 'No published guides yet',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey[500]),
          ),
          if (isOwnProfile) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => context.go('/dashboard'),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Create your first guide'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(40)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Edit profile bottom sheet (proper StatefulWidget — avoids StatefulBuilder
//    mounted race condition that causes '_dependents.isEmpty' crash) ──────────

class _EditProfileSheet extends ConsumerStatefulWidget {
  final UserModel user;
  final VoidCallback onSaved;
  final void Function(dynamic) onError;

  const _EditProfileSheet({
    required this.user,
    required this.onSaved,
    required this.onError,
  });

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _bioCtrl;
  File? _newPicture;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user.name);
    _usernameCtrl = TextEditingController(text: widget.user.username);
    _bioCtrl = TextEditingController(text: widget.user.bio ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      final updated = await ref
          .read(userRepositoryProvider)
          .updateUserProfile(
            username: _usernameCtrl.text.trim(),
            bio: _bioCtrl.text.trim(),
            profilePicture: _newPicture,
          );
      ref.read(authProvider.notifier).updateUser(updated);
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      widget.onError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Edit Profile',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            Center(
              child: GestureDetector(
                onTap: () async {
                  final picked = await ImagePicker()
                      .pickImage(source: ImageSource.gallery);
                  if (picked != null && mounted) {
                    setState(() => _newPicture = File(picked.path));
                  }
                },
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: Colors.blue[100],
                      backgroundImage: _newPicture != null
                          ? FileImage(_newPicture!) as ImageProvider
                          : (widget.user.profilePicture != null
                              ? CachedNetworkImageProvider(
                                  widget.user.profilePicture!)
                              : null),
                      child: _newPicture == null &&
                              widget.user.profilePicture == null
                          ? const Icon(Icons.person,
                              size: 44, color: Colors.white)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: Color(0xFF3B82F6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt,
                            size: 15, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Center(
              child: Text('Tap to change photo',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Display Name',
                prefixIcon: Icon(Icons.badge_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _usernameCtrl,
              decoration: const InputDecoration(
                labelText: 'Username',
                prefixIcon: Icon(Icons.alternate_email),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bioCtrl,
              decoration: const InputDecoration(
                labelText: 'Bio',
                prefixIcon: Icon(Icons.edit_note_outlined),
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              maxLength: 160,
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Save Changes',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
