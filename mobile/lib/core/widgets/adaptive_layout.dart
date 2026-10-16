import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../l10n/l10n.dart';
import 'brand_logo.dart';

/// Window widths at which the layout changes (Material 3 window size classes).
abstract final class Breakpoints {
  /// Expanded: a navigation rail replaces the bottom navigation bar.
  static const double wide = 840;

  /// Large: the rail shows its labels beside the icons.
  static const double extended = 1200;
}

/// Content widths that stay comfortable to read on wide windows.
abstract final class ReadableWidths {
  /// Detail, profile and settings pages.
  static const double page = 840;

  /// Single-column forms (sign-in, password).
  static const double form = 480;

  /// The reader's text column.
  static const double reader = 800;
}

/// Whether the window is wide enough for the desktop layout.
bool isWideLayout(BuildContext context) => MediaQuery.sizeOf(context).width >= Breakpoints.wide;

/// One of the three top-level destinations.
class AppDestination {
  final String path;
  final IconData icon;
  final IconData selectedIcon;
  final String Function(AppLocalizations l) label;

  const AppDestination(this.path, this.icon, this.selectedIcon, this.label);
}

final appDestinations = <AppDestination>[
  AppDestination('/', Icons.home_outlined, Icons.home, (l) => l.navHome),
  AppDestination('/bookshelf', Icons.book_outlined, Icons.book, (l) => l.navBookshelf),
  AppDestination('/profile', Icons.person_outline, Icons.person, (l) => l.navProfile),
];

void _goToDestination(BuildContext context, int index, int selectedIndex) {
  if (index != selectedIndex) context.go(appDestinations[index].path);
}

/// Bottom navigation shared by the three top-level tabs; hidden on wide
/// windows, where [AppNavShell] shows a navigation rail instead.
class AppBottomNav extends StatelessWidget {
  final int selectedIndex;

  const AppBottomNav({super.key, required this.selectedIndex});

  @override
  Widget build(BuildContext context) {
    if (isWideLayout(context)) return const SizedBox.shrink();
    final l = context.l10n;
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) => _goToDestination(context, index, selectedIndex),
      destinations: [
        for (final d in appDestinations)
          NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: d.label(l)),
      ],
    );
  }
}

/// Wraps a top-level tab page: on wide windows a navigation rail (extended
/// with labels on large ones) sits left of the page; on narrow ones the page
/// shows [AppBottomNav] itself and this adds nothing.
class AppNavShell extends StatelessWidget {
  final int selectedIndex;
  final Widget child;

  const AppNavShell({super.key, required this.selectedIndex, required this.child});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < Breakpoints.wide) return child;
    final extended = width >= Breakpoints.extended;
    final l = context.l10n;
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SafeArea(
            right: false,
            child: NavigationRail(
              key: const ValueKey('app-navigation-rail'),
              extended: extended,
              minExtendedWidth: 200,
              labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) => _goToDestination(context, index, selectedIndex),
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: extended ? const BrandLogo.horizontal(height: 30) : const BrandLogo.mark(size: 36),
              ),
              destinations: [
                for (final d in appDestinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label(l)),
                  ),
              ],
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Builds content with the extra horizontal [inset] that keeps it at most
/// [maxWidth] wide and centred, while the scroll view built around it still
/// spans the whole width (so the wheel and scrollbar work everywhere).
class ReadableInset extends StatelessWidget {
  final double maxWidth;
  final Widget Function(BuildContext context, double inset) builder;

  const ReadableInset({super.key, this.maxWidth = ReadableWidths.page, required this.builder});

  /// The inset keeping [maxWidth] centred in [available] width.
  static double insetFor(double available, double maxWidth) =>
      available.isFinite ? math.max(0, (available - maxWidth) / 2) : 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => builder(context, insetFor(constraints.maxWidth, maxWidth)),
    );
  }
}
