// lib/widgets/card/guide_card.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/travel_guide_model.dart';

class GuideCard extends StatelessWidget {
  final TravelGuideModel guide;
  final bool isLiked;
  final bool isSaved;
  final int likedCount;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final VoidCallback? onSave;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final bool showActions;
  final bool isOwner;

  // Follow/unfollow
  final bool isFollowing;
  final bool isFollowLoading;
  // null → hide button (owner / no author)
  // non-null → show button, calls this on tap
  final VoidCallback? onFollowToggle;

  const GuideCard({
    super.key,
    required this.guide,
    required this.likedCount,
    required this.isLiked,
    required this.isSaved,
    this.onTap,
    this.onLike,
    this.onSave,
    this.onDelete,
    this.onEdit,
    this.showActions = true,
    this.isOwner = false,
    this.isFollowing = false,
    this.isFollowLoading = false,
    this.onFollowToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Thumbnail ────────────────────────────────────────────
            AspectRatio(
              aspectRatio: 16 / 9,
              child: guide.thumbnailImage.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: guide.thumbnailImage,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: Colors.grey[100],
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: Colors.grey[100],
                        child: const Icon(
                            Icons.image_not_supported,
                            color: Colors.grey),
                      ),
                    )
                  : Container(
                      color: Colors.blue[50],
                      child: const Center(
                        child: Icon(Icons.travel_explore,
                            color: Colors.blue, size: 40),
                      ),
                    ),
            ),

            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Country + author + follow button ─────────────
                  Row(
                    children: [
                      // Country badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          guide.country,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (guide.author != null) ...[
                        Text(
                          '@${guide.author!.username}',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[600]),
                        ),
                        // Follow button — only shown to non-owners
                        if (onFollowToggle != null) ...[
                          const SizedBox(width: 8),
                          _FollowButton(
                            isFollowing: isFollowing,
                            isLoading: isFollowLoading,
                            onTap: onFollowToggle!,
                          ),
                        ],
                      ],
                    ],
                  ),

                  const SizedBox(height: 8),

                  // ── Title ────────────────────────────────────────
                  Text(
                    guide.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF1F2937),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 6),

                  // ── Description ──────────────────────────────────
                  Text(
                    guide.description,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // ── Tags ─────────────────────────────────────────
                  if (guide.tags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: guide.tags.take(3).map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '#$tag',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  // ── Action buttons ───────────────────────────────
                  if (showActions) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1, thickness: 0.5),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _ActionButton(
                          icon: isLiked
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: isLiked ? Colors.red : Colors.grey,
                          label: likedCount.toString(),
                          onTap: onLike,
                        ),
                        const SizedBox(width: 16),
                        _ActionButton(
                          icon: isSaved
                              ? Icons.bookmark
                              : Icons.bookmark_border,
                          color: isSaved
                              ? const Color(0xFF3B82F6)
                              : Colors.grey,
                          label: 'Save',
                          onTap: onSave,
                        ),
                        const Spacer(),
                        if (isOwner && onEdit != null)
                          _IconBtn(
                            icon: Icons.edit_outlined,
                            color: Colors.blue,
                            onTap: onEdit!,
                          ),
                        if (isOwner && onDelete != null) ...[
                          const SizedBox(width: 8),
                          _IconBtn(
                            icon: Icons.delete_outline,
                            color: Colors.red,
                            onTap: onDelete!,
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Follow button ─────────────────────────────────────────────────────────────
class _FollowButton extends StatelessWidget {
  final bool isFollowing;
  final bool isLoading;
  final VoidCallback onTap;

  const _FollowButton({
    required this.isFollowing,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
        decoration: BoxDecoration(
          color: isFollowing
              ? Colors.grey[100]
              : const Color(0xFF3B82F6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isFollowing
                ? Colors.grey[300]!
                : const Color(0xFF3B82F6),
            width: 1,
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: isFollowing
                      ? Colors.grey[500]
                      : Colors.white,
                ),
              )
            : Text(
                isFollowing ? 'Following' : 'Follow',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isFollowing
                      ? Colors.grey[600]
                      : Colors.white,
                ),
              ),
      ),
    );
  }
}

// ── Action button (like / save) ───────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(fontSize: 14, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Icon-only button (edit / delete) ─────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _IconBtn({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }
}
