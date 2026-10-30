import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/providers.dart';
import '../auth/auth_controller.dart';
import '../preferences.dart';
import 'alert_area_screen.dart' show alertAreaSummary;
import '../widgets/animations.dart';
import '../widgets/common.dart';
import '../widgets/server_settings.dart';

/// Everything that isn't the user's activity: account, association, admin, theme, language,
/// permissions, server, about, sign out.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final me = ref.watch(meProvider).value;
    final prefs = ref.watch(preferencesProvider);
    final waiting = me?.isAdmin ?? false ? ref.watch(adminSummaryProvider).value?.total ?? 0 : 0;
    Widget section(int index, String title, List<Widget> tiles) => FadeSlideIn(
      index: index,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
              child: Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: context.tokens.muted)),
            ),
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final (i, tile) in tiles.indexed) ...[if (i > 0) const Divider(height: 1), tile],
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          section(0, l10n.account, [
            ListTile(
              leading: const Icon(LucideIcons.bellRing),
              title: Text(l10n.alertsNearMe),
              subtitle: Text(alertAreaSummary(context, ref.watch(alertAreaProvider).value)),
              trailing: const ForwardIcon(),
              onTap: () => context.push('/alerts'),
            ),
            ListTile(
              leading: const Icon(LucideIcons.circleUser),
              title: Text(me?.displayName ?? l10n.account),
              subtitle: me == null ? null : Text(me.email),
              trailing: const ForwardIcon(),
              onTap: () => context.push('/account'),
            ),
            ListTile(
              leading: const Icon(LucideIcons.heartHandshake),
              title: Text(me?.associationName ?? l10n.becomeAssociation),
              trailing: const ForwardIcon(),
              onTap: () => context.push('/association'),
            ),
            if (me?.isAdmin ?? false)
              ListTile(
                leading: const Icon(LucideIcons.shieldCheck),
                title: Text(l10n.admin),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 8,
                  children: [
                    if (waiting > 0) Badge.count(count: waiting),
                    const ForwardIcon(),
                  ],
                ),
                onTap: () => context.push('/admin').then((_) => ref.invalidate(adminSummaryProvider)),
              ),
          ]),
          section(1, l10n.appearance, [
            Padding(
              padding: const EdgeInsets.all(16),
              child: SegmentedButton<ThemeMode>(
                segments: [
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: const Icon(LucideIcons.smartphone),
                    label: Text(l10n.themeSystem),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: const Icon(LucideIcons.sun),
                    label: Text(l10n.themeLight),
                  ),
                  ButtonSegment(value: ThemeMode.dark, icon: const Icon(LucideIcons.moon), label: Text(l10n.themeDark)),
                ],
                selected: {prefs.themeMode},
                showSelectedIcon: false,
                onSelectionChanged: (mode) => ref.read(preferencesProvider.notifier).setThemeMode(mode.first),
              ),
            ),
          ]),
          section(2, l10n.language, [
            RadioGroup<String?>(
              groupValue: prefs.language,
              onChanged: (language) => ref.read(preferencesProvider.notifier).setLanguage(language),
              child: Column(
                children: [
                  for (final (code, name) in [
                    (null, l10n.languageSystem),
                    ('en', 'English'),
                    ('fr', 'Français'),
                    ('ar', 'العربية'),
                  ])
                    RadioListTile<String?>(value: code, title: Text(name)),
                ],
              ),
            ),
          ]),
          section(3, l10n.thisPhone, [
            ListTile(
              leading: const Icon(LucideIcons.bellRing),
              title: Text(l10n.permissions),
              subtitle: Text(l10n.permissionsHelp),
              trailing: const Icon(LucideIcons.externalLink),
              onTap: Geolocator.openAppSettings,
            ),
            ListTile(
              leading: const Icon(LucideIcons.server),
              title: Text(l10n.serverAddress),
              trailing: const ForwardIcon(),
              onTap: () => editServerAddress(context),
            ),
            ListTile(
              leading: const Icon(LucideIcons.info),
              title: Text(l10n.about),
              trailing: const ForwardIcon(),
              onTap: () => showAboutDialog(
                context: context,
                applicationName: 'Winou',
                applicationIcon: const AppLogo(size: 48),
                applicationLegalese: l10n.tagline,
              ),
            ),
          ]),
          FadeSlideIn(
            index: 4,
            child: OutlinedButton.icon(
              onPressed: () => ref.read(authProvider.notifier).logout(),
              icon: const Icon(LucideIcons.logOut),
              label: Text(l10n.signOut),
            ),
          ),
        ],
      ),
    );
  }
}
