// lib/widgets/common/main_scaffold.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';

const _kBlue = Color(0xFF3B82F6);
const _kCyan = Color(0xFF06B6D4);

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
      decoration: BoxDecoration(
        // Subtle blue-tinted white — matches _kPageBg family
        color: const Color(0xFFF8FBFF),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: _kBlue.withValues(alpha: 0.14),
            blurRadius: 32,
            spreadRadius: 0,
            offset: const Offset(0, -6),
          ),
          BoxShadow(
            color: _kCyan.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, -2),
          ),
          const BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, -1),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top gradient accent line — mirrors CTA banner & buttons
          Container(
            height: 2.5,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_kBlue, _kCyan],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
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
        ],
      ),
    );
  }
}

// ── Single nav button ─────────────────────────────────────────────────────────
class _NavButton extends StatefulWidget {
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

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 160),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _press, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  static const _activeGradient = LinearGradient(
    colors: [_kBlue, _kCyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _press.forward(),
      onTapCancel: () => _press.reverse(),
      onTap: () {
        _press.reverse();
        widget.onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: widget.isSelected ? 18 : 14,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            gradient: widget.isSelected ? _activeGradient : null,
            color: widget.isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(40),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: _kBlue.withValues(alpha: 0.38),
                      blurRadius: 18,
                      spreadRadius: 0,
                      offset: const Offset(0, 5),
                    ),
                    BoxShadow(
                      color: _kCyan.withValues(alpha: 0.22),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
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
                    transitionBuilder: (child, animation) => ScaleTransition(
                      scale: animation,
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                    child: Icon(
                      widget.isSelected
                          ? widget.item.activeIcon
                          : widget.item.icon,
                      key: ValueKey(widget.isSelected),
                      size: 22,
                      color:
                          widget.isSelected ? Colors.white : Colors.grey[400],
                    ),
                  ),
                  if (widget.isLocked)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFB923C), Color(0xFFF59E0B)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: Colors.white, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withValues(alpha: 0.45),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.lock,
                          size: 7,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),

              // Label — slides in when active
              AnimatedSize(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                child: widget.isSelected
                    ? Padding(
                        padding: const EdgeInsets.only(left: 7),
                        child: Text(
                          widget.item.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
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
