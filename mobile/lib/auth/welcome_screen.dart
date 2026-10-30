import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../preferences.dart';
import '../theme.dart';
import '../widgets/animations.dart';
import '../widgets/common.dart';

/// First launch: what Winou does in three pages, then the two permissions it asks for, each with
/// the reason first. Android shows its own prompt only when the user taps "Allow".
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final _pages = PageController();
  int _page = 0;

  static const _count = 4;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() => _page == _count - 1
      ? ref
            .read(preferencesProvider.notifier)
            .welcomeDone() // the router moves on to sign-in
      : _pages.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final last = _page == _count - 1;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: Brand.gradient),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: AnimatedOpacity(
                  opacity: last ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: TextButton(
                    onPressed: last ? null : () => _pages.jumpToPage(_count - 1),
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    child: Text(l10n.skip),
                  ),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pages,
                  onPageChanged: (page) => setState(() => _page = page),
                  children: [
                    _Intro(icon: LucideIcons.search, title: l10n.welcomeLostTitle, body: l10n.welcomeLostBody),
                    _Intro(icon: LucideIcons.camera, title: l10n.welcomeSawTitle, body: l10n.welcomeSawBody),
                    _Intro(icon: LucideIcons.pawPrint, title: l10n.welcomeStraysTitle, body: l10n.welcomeStraysBody),
                    const _Permissions(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: Column(
                  spacing: 20,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: 6,
                      children: [
                        for (var i = 0; i < _count; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: i == _page ? 22 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: i == _page ? 1 : 0.45),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Brand.ink),
                        onPressed: _next,
                        child: Text(last ? l10n.getStarted : l10n.next),
                      ),
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
}

class _Intro extends StatelessWidget {
  const _Intro({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FadeSlideIn(
            scale: 0.7,
            offset: Offset.zero,
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.16)),
              child: Icon(icon, size: 72, color: Colors.white),
            ),
          ),
          const SizedBox(height: 32),
          FadeSlideIn(
            index: 1,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: text.headlineMedium?.copyWith(color: Colors.white),
            ),
          ),
          const SizedBox(height: 12),
          FadeSlideIn(
            index: 2,
            child: Text(
              body,
              textAlign: TextAlign.center,
              style: text.bodyLarge?.copyWith(color: Colors.white.withValues(alpha: 0.88), height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

/// Why each permission helps, and a button that asks for it. Both can be left for later.
class _Permissions extends StatefulWidget {
  const _Permissions();

  @override
  State<_Permissions> createState() => _PermissionsState();
}

class _PermissionsState extends State<_Permissions> {
  bool? _notifications; // null: not asked yet
  bool? _location;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final (settings, location) = await (
        FirebaseMessaging.instance.getNotificationSettings(),
        Geolocator.checkPermission(),
      ).wait;
      if (!mounted) return;
      setState(() {
        _notifications = _granted(settings.authorizationStatus);
        _location = _locationGranted(location);
      });
    } catch (_) {
      // Unknown: both buttons stay
    }
  }

  static bool? _granted(AuthorizationStatus status) => switch (status) {
    AuthorizationStatus.authorized || AuthorizationStatus.provisional => true,
    AuthorizationStatus.denied || AuthorizationStatus.deniedPermanently => false,
    AuthorizationStatus.notDetermined => null,
  };

  static bool? _locationGranted(LocationPermission permission) => switch (permission) {
    LocationPermission.always || LocationPermission.whileInUse => true,
    LocationPermission.denied => null, // may still be asked
    _ => false,
  };

  Future<void> _askNotifications() async {
    final settings = await FirebaseMessaging.instance.requestPermission();
    if (mounted) setState(() => _notifications = _granted(settings.authorizationStatus) ?? false);
  }

  Future<void> _askLocation() async {
    final permission = await Geolocator.requestPermission();
    if (mounted) setState(() => _location = _locationGranted(permission) ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        spacing: 14,
        children: [
          FadeSlideIn(
            child: Text(
              l10n.welcomePermissionsTitle,
              textAlign: TextAlign.center,
              style: text.headlineMedium?.copyWith(color: Colors.white),
            ),
          ),
          FadeSlideIn(
            index: 1,
            child: Text(
              l10n.welcomePermissionsBody,
              textAlign: TextAlign.center,
              style: text.bodyLarge?.copyWith(color: Colors.white.withValues(alpha: 0.88)),
            ),
          ),
          const SizedBox(height: 4),
          FadeSlideIn(
            index: 2,
            child: _PermissionCard(
              icon: LucideIcons.bellRing,
              title: l10n.permissionNotificationsTitle,
              body: l10n.permissionNotificationsBody,
              granted: _notifications,
              onAllow: _askNotifications,
            ),
          ),
          FadeSlideIn(
            index: 3,
            child: _PermissionCard(
              icon: LucideIcons.mapPin,
              title: l10n.permissionLocationTitle,
              body: l10n.permissionLocationBody,
              granted: _location,
              onAllow: _askLocation,
            ),
          ),
          Text(
            l10n.permissionsLater,
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.granted,
    required this.onAllow,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool? granted; // null: not asked yet
  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 14,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(shape: BoxShape.circle, color: tokens.tonal),
              child: Icon(icon, color: tokens.accent),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  Text(body, style: TextStyle(color: tokens.muted, height: 1.35)),
                  const SizedBox(height: 4),
                  switch (granted) {
                    true => StatusPill(l10n.allowed, tone: Tone.found, icon: LucideIcons.check),
                    false => StatusPill(l10n.notAllowed, tone: Tone.neutral, icon: LucideIcons.x),
                    null => FilledButton.tonal(onPressed: onAllow, child: Text(l10n.allow)),
                  },
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
