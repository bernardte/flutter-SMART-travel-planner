// lib/screens/community/community_screen.dart

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

class _CommunityScreenState extends ConsumerState<CommunityScreen>
    with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late AnimationController _animationController;

  // Filter & sort state
  String _sortBy = 'latest';
  String _selectedCountry = '';
  final Set<String> _selectedTags = {};

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    Future.microtask(
      () => ref.read(communityProvider.notifier).fetchPublicPosts(),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  bool get _hasActiveFilters =>
      _sortBy != 'latest' ||
      _selectedCountry.isNotEmpty ||
      _selectedTags.isNotEmpty;

  List<String> _getCountries(List<TravelGuideModel> posts) {
    final list = posts
        .map((p) => p.country.trim())
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();
    list.sort();
    return list;
  }

  List<String> _getTags(List<TravelGuideModel> posts) {
    final list = posts
        .expand((p) => p.tags)
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList();
    list.sort();
    return list;
  }

  List<TravelGuideModel> _filtered(List<TravelGuideModel> posts) {
    var result = List<TravelGuideModel>.from(posts);

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result
          .where((p) =>
              p.title.toLowerCase().contains(q) ||
              p.country.toLowerCase().contains(q) ||
              p.tags.any((t) => t.toLowerCase().contains(q)) ||
              (p.author?.username.toLowerCase().contains(q) ?? false))
          .toList();
    }

    if (_selectedCountry.isNotEmpty) {
      result = result
          .where((p) =>
              p.country.toLowerCase() == _selectedCountry.toLowerCase())
          .toList();
    }

    if (_selectedTags.isNotEmpty) {
      result = result
          .where((p) => _selectedTags.any((tag) =>
              p.tags.map((t) => t.toLowerCase()).contains(tag.toLowerCase())))
          .toList();
    }

    switch (_sortBy) {
      case 'most_liked':
        result.sort((a, b) => b.likes.compareTo(a.likes));
        break;
      case 'trending':
        int score(TravelGuideModel g) => g.likes * 3 + g.saves * 2 + g.views;
        result.sort((a, b) => score(b).compareTo(score(a)));
        break;
      case 'latest':
      default:
        result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }

    return result;
  }

  void _clearAllFilters() {
    setState(() {
      _sortBy = 'latest';
      _selectedCountry = '';
      _selectedTags.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final community = ref.watch(communityProvider);
    final auth = ref.watch(authProvider);
    final posts = community.publicPosts;
    final filtered = _filtered(posts);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F9FF),
      appBar: _buildAppBar(posts),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(communityProvider.notifier).fetchPublicPosts(),
        color: const Color(0xFF3B82F6),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildSearchAndFilters(posts)),
            community.isLoading
                ? const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF3B82F6)),
                    ),
                  )
                : filtered.isEmpty
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
                            (context, index) {
                              final guide = filtered[index];
                              final isOwner =
                                  auth.user?.id == guide.author?.id;
                              return TweenAnimationBuilder(
                                tween: Tween<double>(begin: 0, end: 1),
                                duration: Duration(
                                    milliseconds: 300 + (index * 30)),
                                builder: (context, value, child) =>
                                    Opacity(
                                  opacity: value,
                                  child: Transform.translate(
                                    offset: Offset(0, 20 * (1 - value)),
                                    child: child,
                                  ),
                                ),
                                child: GuideCard(
                                  guide: guide,
                                  likedCount: guide.likes,
                                  isLiked: guide.isLiked,
                                  isSaved: guide.isSaved,
                                  isOwner: isOwner,
                                  onTap: () {
                                    final itinId =
                                        guide.itinerary?['_id'];
                                    if (itinId != null) {
                                      context.push(
                                          '/trip-plan/view/$itinId');
                                    }
                                  },
                                  onLike: auth.isAuthenticated
                                      ? () async => ref
                                          .read(communityProvider
                                              .notifier)
                                          .toggleLike(guide.id)
                                      : () => context.go('/auth'),
                                  onSave: auth.isAuthenticated
                                      ? () => ref
                                          .read(communityProvider
                                              .notifier)
                                          .toggleSave(guide.id)
                                      : () => context.go('/auth'),
                                  onDelete: isOwner
                                      ? () =>
                                          _confirmDelete(context, guide.id)
                                      : null,
                                ),
                              );
                            },
                            childCount: filtered.length,
                          ),
                        ),
                      ),
          ],
        ),
      ),
      floatingActionButton: (auth.isAuthenticated && posts.isNotEmpty)
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/post'),
              icon: const Icon(Icons.add, size: 20),
              label: const Text(
                'Share Guide',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              highlightElevation: 4,
              shape: const ContinuousRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(40)),
              ),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              extendedPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              extendedIconLabelSpacing: 12,
              clipBehavior: Clip.antiAlias,
            )
          : null,
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(List<TravelGuideModel> posts) {
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
            child:
                const Icon(Icons.public, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Text(
            'Community',
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
      actions: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(Icons.filter_alt_outlined,
                  color: Color(0xFF3B82F6)),
              onPressed: () => _showFilterDialog(posts),
              tooltip: 'Sort & Filter',
              splashRadius: 24,
            ),
            if (_hasActiveFilters)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
              color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Explore travel stories 🌍',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937)),
          ),
          const SizedBox(height: 6),
          Text(
            'Discover itineraries from fellow travelers, get inspired, and share your own adventures.',
            style:
                TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.4),
          ),
        ],
      ),
    );
  }

  // ── Search & Filters bar ──────────────────────────────────────────────────

  Widget _buildSearchAndFilters(List<TravelGuideModel> posts) {
    // Build list of currently active filter chips
    final activeChips = <({String label, VoidCallback onRemove})>[];

    if (_selectedCountry.isNotEmpty) {
      activeChips.add((
        label: '🌍 $_selectedCountry',
        onRemove: () => setState(() => _selectedCountry = ''),
      ));
    }
    for (final tag in _selectedTags) {
      final captured = tag;
      activeChips.add((
        label: '🏷 $captured',
        onRemove: () => setState(() => _selectedTags.remove(captured)),
      ));
    }
    if (_sortBy != 'latest') {
      const sortLabels = {
        'most_liked': '❤️ Most Liked',
        'trending': '🔥 Trending',
      };
      activeChips.add((
        label: sortLabels[_sortBy] ?? _sortBy,
        onRemove: () => setState(() => _sortBy = 'latest'),
      ));
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search field
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search destinations, guides, or travelers...',
              hintStyle: TextStyle(color: Colors.grey[400]),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: Color(0xFF3B82F6), size: 24),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      },
                      splashRadius: 20,
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFF0F6FF),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(40),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                  vertical: 16, horizontal: 16),
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),

          // Active filter badges — shown only when filters are applied
          if (activeChips.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  'Active:',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: activeChips
                          .map((c) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _ActiveFilterChip(
                                  label: c.label,
                                  onRemove: c.onRemove,
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ),
                if (activeChips.length > 1)
                  GestureDetector(
                    onTap: _clearAllFilters,
                    child: Text(
                      'Clear all',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.red[400],
                          fontWeight: FontWeight.w500),
                    ),
                  ),
              ],
            ),
          ],

          // Quick sort chips
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _QuickFilterChip(
                  icon: Icons.filter_list_rounded,
                  label: 'All Filters',
                  isActive: _hasActiveFilters,
                  onTap: () => _showFilterDialog(posts),
                ),
                const SizedBox(width: 8),
                _QuickFilterChip(
                  icon: Icons.access_time_rounded,
                  label: 'Latest',
                  isActive: _sortBy == 'latest' && !_hasActiveFilters,
                  activeColor: const Color(0xFF06B6D4),
                  onTap: () => setState(() {
                    _sortBy = 'latest';
                  }),
                ),
                const SizedBox(width: 8),
                _QuickFilterChip(
                  icon: Icons.local_fire_department_rounded,
                  label: 'Trending',
                  isActive: _sortBy == 'trending',
                  activeColor: const Color(0xFFF59E0B),
                  onTap: () => setState(() => _sortBy = 'trending'),
                ),
                const SizedBox(width: 8),
                _QuickFilterChip(
                  icon: Icons.favorite_rounded,
                  label: 'Most Liked',
                  isActive: _sortBy == 'most_liked',
                  activeColor: const Color(0xFFEF4444),
                  onTap: () => setState(() => _sortBy = 'most_liked'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    final hasFilters = _searchQuery.isNotEmpty || _hasActiveFilters;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasFilters ? Icons.travel_explore : Icons.map_outlined,
            size: 90,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 20),
          Text(
            hasFilters
                ? 'No guides match your filters'
                : 'No community guides yet\n✈️ Be the first to share your journey!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 28),
          if (hasFilters)
            ElevatedButton.icon(
              onPressed: () {
                _clearAllFilters();
                _searchCtrl.clear();
                setState(() => _searchQuery = '');
              },
              icon: const Icon(Icons.clear_all, size: 20),
              label: const Text('Clear all filters'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(40)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                elevation: 0,
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: () => context.push('/post'),
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Create a guide'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF3B82F6),
                side: const BorderSide(color: Color(0xFF3B82F6)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(40)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
              ),
            ),
        ],
      ),
    );
  }

  // ── Filter bottom sheet ───────────────────────────────────────────────────

  void _showFilterDialog(List<TravelGuideModel> posts) {
    String tempSort = _sortBy;
    String tempCountry = _selectedCountry;
    final tempTags = Set<String>.from(_selectedTags);

    final countries = _getCountries(posts);
    final tags = _getTags(posts);

    const sortOptions = [
      (
        value: 'latest',
        icon: Icons.access_time_rounded,
        label: 'Latest',
        subtitle: 'Newest guides first',
        color: Color(0xFF06B6D4),
      ),
      (
        value: 'most_liked',
        icon: Icons.favorite_rounded,
        label: 'Most Liked',
        subtitle: 'Highest like count first',
        color: Color(0xFFEF4444),
      ),
      (
        value: 'trending',
        icon: Icons.local_fire_department_rounded,
        label: 'Trending',
        subtitle: 'Likes × 3 + saves × 2 + views',
        color: Color(0xFFF59E0B),
      ),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final hasTemp = tempSort != 'latest' ||
              tempCountry.isNotEmpty ||
              tempTags.isNotEmpty;

          return DraggableScrollableSheet(
            initialChildSize: 0.75,
            minChildSize: 0.5,
            maxChildSize: 0.92,
            expand: false,
            builder: (ctx, scrollCtrl) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  // Fixed header
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Column(
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
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Sort & Filter',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E3A8A),
                              ),
                            ),
                            if (hasTemp)
                              TextButton(
                                onPressed: () => setSheet(() {
                                  tempSort = 'latest';
                                  tempCountry = '';
                                  tempTags.clear();
                                }),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red[400],
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('Reset All'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Divider(height: 1),
                      ],
                    ),
                  ),

                  // Scrollable content
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollCtrl,
                      padding:
                          const EdgeInsets.fromLTRB(24, 16, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Sort section ────────────────────────────
                          const _DialogSectionTitle(
                            title: 'Sort By',
                            icon: Icons.sort_rounded,
                          ),
                          const SizedBox(height: 12),
                          ...sortOptions.map((opt) {
                            final isSelected = tempSort == opt.value;
                            return GestureDetector(
                              onTap: () =>
                                  setSheet(() => tempSort = opt.value),
                              child: AnimatedContainer(
                                duration:
                                    const Duration(milliseconds: 180),
                                margin:
                                    const EdgeInsets.only(bottom: 10),
                                padding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? opt.color.withValues(alpha: 0.08)
                                      : Colors.grey[50],
                                  borderRadius:
                                      BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected
                                        ? opt.color
                                        : Colors.grey[200]!,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? opt.color
                                                .withValues(alpha: 0.15)
                                            : Colors.grey[100],
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: Icon(opt.icon,
                                          color: isSelected
                                              ? opt.color
                                              : Colors.grey[400],
                                          size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            opt.label,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                              color: isSelected
                                                  ? opt.color
                                                  : const Color(
                                                      0xFF1F2937),
                                            ),
                                          ),
                                          Text(
                                            opt.subtitle,
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey[500]),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      isSelected
                                          ? Icons.check_circle_rounded
                                          : Icons.radio_button_unchecked,
                                      color: isSelected
                                          ? opt.color
                                          : Colors.grey[300],
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),

                          // ── Country section ──────────────────────────
                          if (countries.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _DialogSectionTitle(
                              title: 'Country',
                              icon: Icons.public_rounded,
                              trailing: tempCountry.isNotEmpty
                                  ? _ClearButton(
                                      onTap: () => setSheet(
                                          () => tempCountry = ''))
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: countries.map((country) {
                                final isSelected =
                                    tempCountry == country;
                                return _FilterChipItem(
                                  label: country,
                                  emoji: '🌍',
                                  isSelected: isSelected,
                                  activeColor:
                                      const Color(0xFF3B82F6),
                                  onTap: () => setSheet(() {
                                    tempCountry =
                                        isSelected ? '' : country;
                                  }),
                                );
                              }).toList(),
                            ),
                          ],

                          // ── Tags section ─────────────────────────────
                          if (tags.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _DialogSectionTitle(
                              title: 'Tags',
                              icon: Icons.label_outline_rounded,
                              trailing: tempTags.isNotEmpty
                                  ? _ClearButton(
                                      onTap: () =>
                                          setSheet(() => tempTags.clear()))
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: tags.map((tag) {
                                final isSelected =
                                    tempTags.contains(tag);
                                return _FilterChipItem(
                                  label: tag,
                                  emoji: '🏷',
                                  isSelected: isSelected,
                                  activeColor:
                                      const Color(0xFF8B5CF6),
                                  onTap: () => setSheet(() {
                                    if (isSelected) {
                                      tempTags.remove(tag);
                                    } else {
                                      tempTags.add(tag);
                                    }
                                  }),
                                  showCheck: true,
                                );
                              }).toList(),
                            ),
                          ],

                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),

                  // Fixed Apply button
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      12,
                      24,
                      MediaQuery.of(ctx).viewInsets.bottom + 24,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _sortBy = tempSort;
                            _selectedCountry = tempCountry;
                            _selectedTags
                              ..clear()
                              ..addAll(tempTags);
                          });
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Apply Filters',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Delete confirmation ───────────────────────────────────────────────────

  Future<void> _confirmDelete(
      BuildContext context, String postId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove guide?'),
        content: const Text(
            'This will permanently delete your travel guide. Are you sure?'),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
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

// ── Reusable helper widgets ───────────────────────────────────────────────────

class _ActiveFilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _ActiveFilterChip(
      {required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF3B82F6))),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded,
                size: 14, color: Color(0xFF3B82F6)),
          ),
        ],
      ),
    );
  }
}

class _QuickFilterChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _QuickFilterChip({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.activeColor = const Color(0xFF3B82F6),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? activeColor : Colors.grey[100],
          borderRadius: BorderRadius.circular(40),
          border: Border.all(
            color: isActive ? activeColor : Colors.grey[200]!,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: isActive ? Colors.white : Colors.grey[600]),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChipItem extends StatelessWidget {
  final String label;
  final String emoji;
  final bool isSelected;
  final Color activeColor;
  final VoidCallback onTap;
  final bool showCheck;

  const _FilterChipItem({
    required this.label,
    required this.emoji,
    required this.isSelected,
    required this.activeColor,
    required this.onTap,
    this.showCheck = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.grey[100],
          borderRadius: BorderRadius.circular(40),
          border: Border.all(
            color: isSelected ? activeColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey[700],
              ),
            ),
            if (showCheck && isSelected) ...[
              const SizedBox(width: 4),
              const Icon(Icons.check_rounded,
                  size: 13, color: Colors.white),
            ],
          ],
        ),
      ),
    );
  }
}

class _DialogSectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? trailing;

  const _DialogSectionTitle({
    required this.title,
    required this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF3B82F6)),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A8A),
          ),
        ),
        if (trailing != null) ...[
          const Spacer(),
          trailing!,
        ],
      ],
    );
  }
}

class _ClearButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ClearButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        'Clear',
        style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
            fontWeight: FontWeight.w500),
      ),
    );
  }
}
