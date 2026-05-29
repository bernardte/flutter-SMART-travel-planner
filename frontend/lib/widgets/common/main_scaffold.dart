// lib/widgets/common/main_scaffold.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';

class MainScaffold extends ConsumerWidget {
  final Widget child;
  final bool showBottomNav;

  const MainScaffold({
    super.key,
    required this.child,
    this.showBottomNav = true,
  });

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/dashboard')) return 1;
    if (location.startsWith('/community-guide')) return 2;
    if (location.startsWith('/favourite-post')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final idx = _currentIndex(context);

    void onTap(int i) {
      switch (i) {
        case 0:
          context.go('/home');
          break;
        case 1:
          context.go(authState.isAuthenticated ? '/dashboard' : '/auth');
          break;
        case 2:
          context.go('/community-guide');
          break;
        case 3:
          context.go(authState.isAuthenticated ? '/favourite-post' : '/auth');
          break;
      }
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: showBottomNav
          ? _FloatingNavBar(
              selectedIndex: idx,
              isAuthenticated: authState.isAuthenticated,
              onTap: onTap,
            )
          : null,
    );
  }
}

// ── Floating nav bar container ────────────────────────────────────────────────

class _FloatingNavBar extends StatelessWidget {
  final int selectedIndex;
  final bool isAuthenticated;
  final void Function(int) onTap;

  const _FloatingNavBar({
    required this.selectedIndex,
    required this.isAuthenticated,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const items = [
      _NavItem(
        index: 0,
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        label: 'Home',
        requiresAuth: false,
      ),
      _NavItem(
        index: 1,
        icon: Icons.map_outlined,
        activeIcon: Icons.map_rounded,
        label: 'My Trips',
        requiresAuth: true,
      ),
      _NavItem(
        index: 2,
        icon: Icons.explore_outlined,
        activeIcon: Icons.explore_rounded,
        label: 'Community',
        requiresAuth: false,
      ),
      _NavItem(
        index: 3,
        icon: Icons.bookmark_outline,
        activeIcon: Icons.bookmark_rounded,
        label: 'Saved',
        requiresAuth: true,
      ),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x143B82F6),
            blurRadius: 24,
            offset: Offset(0, -4),
          ),
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, -1),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items.map((item) {
              final isSelected = item.index == selectedIndex;
              final locked = item.requiresAuth && !isAuthenticated;
              return _NavButton(
                item: item,
                isSelected: isSelected,
                isLocked: locked,
                onTap: () => onTap(item.index),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ── Single nav button ─────────────────────────────────────────────────────────

class _NavButton extends StatelessWidget {
  final _NavItem item;
  final bool isSelected;
  final bool isLocked;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.isSelected,
    required this.isLocked,
    required this.onTap,
  });

  static const _activeGradient = LinearGradient(
    colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          gradient: isSelected ? _activeGradient : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(40),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon with optional lock badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    isSelected ? item.activeIcon : item.icon,
                    key: ValueKey(isSelected),
                    size: 22,
                    color: isSelected ? Colors.white : Colors.grey[500],
                  ),
                ),
                if (isLocked)
                  Positioned(
                    right: -5,
                    top: -5,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.orange[400],
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.lock,
                        size: 6,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),

            // Label — only shown when active
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              child: isSelected
                  ? Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Text(
                        item.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Data class ────────────────────────────────────────────────────────────────

class _NavItem {
  final int index;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool requiresAuth;

  const _NavItem({
    required this.index,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.requiresAuth,
  });
}
