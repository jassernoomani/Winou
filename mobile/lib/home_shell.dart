import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'api/providers.dart';
import 'theme.dart';
import 'widgets/common.dart';

/// The four tabs, each keeping its place: lost pets, the map, messages, and the user's own things.
const tabRoots = ['/', '/map', '/conversations', '/me'];

class HomeShell extends StatelessWidget {
  const HomeShell(this.shell, {super.key});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: shell,
    bottomNavigationBar: AppNavigationBar(
      index: shell.currentIndex,
      // Tapping the current tab again goes back to its first screen
      onSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
    ),
  );
}

/// The bar itself, with unread messages and, for admins, what waits for them.
class AppNavigationBar extends ConsumerWidget {
  const AppNavigationBar({super.key, required this.index, required this.onSelected});

  final int index;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final unread = ref.watch(conversationsProvider).value?.fold<int>(0, (sum, c) => sum + c.unread) ?? 0;
    final isAdmin = ref.watch(meProvider).value?.isAdmin ?? false;
    final waiting = isAdmin ? ref.watch(adminSummaryProvider).value?.total ?? 0 : 0;
    Widget badged(IconData icon, int count) =>
        Badge.count(count: count, isLabelVisible: count > 0, backgroundColor: Brand.coral, child: Icon(icon));
    return NavigationBar(
      selectedIndex: index,
      onDestinationSelected: onSelected,
      destinations: [
        NavigationDestination(icon: const Icon(LucideIcons.house), label: l10n.tabHome),
        NavigationDestination(icon: const Icon(LucideIcons.map), label: l10n.map),
        NavigationDestination(icon: badged(LucideIcons.messageCircle, unread), label: l10n.messages),
        NavigationDestination(
          icon: Badge(isLabelVisible: waiting > 0, backgroundColor: Brand.coral, child: const Icon(LucideIcons.user)),
          label: l10n.tabMe,
        ),
      ],
    );
  }
}
