// lib/widgets/card/guide_card.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/travel_guide_model.dart';

class GuideCard extends StatelessWidget {
  final TravelGuideModel guide;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final VoidCallback? onSave;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final bool showActions;
  final bool isOwner;

  const GuideCard({
    super.key,
    required this.guide,
    this.onTap,
    this.onLike,
    this.onSave,
    this.onDelete,
    this.onEdit,
    this.showActions = true,
    this.isOwner = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            AspectRatio(
              aspectRatio: 16 / 9,
              child: guide.thumbnailImage.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: guide.thumbnailImage,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: Colors.grey[200],
                        child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.image_not_supported,
                            color: Colors.grey),
                      ),
                    )
                  : Container(
                      color: Colors.grey[200],
                      child:
                          const Icon(Icons.travel_explore, color: Colors.grey),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Country badge + author
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          guide.country,
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Spacer(),
                      if (guide.author != null)
                        Text(
                          '@${guide.author!.username}',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[500]),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Title
                  Text(
                    guide.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Description
                  Text(
                    guide.description,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Tags
                  if (guide.tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: guide.tags
                          .take(3)
                          .map((tag) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.cyan[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '#$tag',
                                  style: TextStyle(
                                      fontSize: 10, color: Colors.cyan[700]),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                  // Actions
                  if (showActions) ...[
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Like
                        _ActionButton(
                          icon: guide.isLiked
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: guide.isLiked ? Colors.red : Colors.grey,
                          label: guide.likes.toString(),
                          onTap: onLike,
                        ),
                        const SizedBox(width: 12),
                        // Save
                        _ActionButton(
                          icon: guide.isSaved
                              ? Icons.bookmark
                              : Icons.bookmark_border,
                          color: guide.isSaved ? Colors.cyan : Colors.grey,
                          label: 'Save',
                          onTap: onSave,
                        ),
                        const Spacer(),
                        // Owner actions
                        if (isOwner && onEdit != null)
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: onEdit,
                            color: Colors.blue,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        if (isOwner && onDelete != null) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            onPressed: onDelete,
                            color: Colors.red,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
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
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }
}
