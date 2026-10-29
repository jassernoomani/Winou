import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/providers.dart';
import 'auth/auth_controller.dart';
import 'l10n/app_localizations.dart';
import 'push.dart';
import 'router.dart';
import 'widgets/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // config from android/app/google-services.json
  runApp(const ProviderScope(child: WinouApp()));
}

class WinouApp extends ConsumerStatefulWidget {
  const WinouApp({super.key});

  @override
  ConsumerState<WinouApp> createState() => _WinouAppState();
}

class _WinouAppState extends ConsumerState<WinouApp> {
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  final _subscriptions = <StreamSubscription<RemoteMessage>>[];
  String? _pendingMatch; // tapped before the user was signed in

  @override
  void initState() {
    super.initState();
    ref.read(pushProvider); // starts listening for this phone's registration
    _subscriptions
      ..add(FirebaseMessaging.onMessage.listen(_showInApp))
      ..add(FirebaseMessaging.onMessageOpenedApp.listen(_open));
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) _open(message);
    });
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  /// A notification was tapped: show its match once the user is signed in.
  void _open(RemoteMessage message) {
    _pendingMatch = matchIdOf(message);
    _openPending();
  }

  void _openPending() {
    final id = _pendingMatch;
    final auth = ref.read(authProvider);
    if (id == null || auth.loading || !auth.signedIn) return;
    _pendingMatch = null;
    _openMatch(id);
  }

  void _openMatch(String id) {
    ref.invalidate(myMatchesProvider);
    final router = ref.read(routerProvider);
    if (router.routerDelegate.currentConfiguration.uri.path == '/splash') {
      // Starting up: wait until the router has moved on to the home screen
      WidgetsBinding.instance.addPostFrameCallback((_) => _openMatch(id));
      WidgetsBinding.instance.scheduleFrame();
      return;
    }
    router.push('/matches/$id');
  }

  /// While the app is open, Android shows no notification: show a snack bar instead.
  void _showInApp(RemoteMessage message) {
    final id = matchIdOf(message);
    final context = _messenger.currentContext;
    if (id == null || context == null) return;
    ref.invalidate(myMatchesProvider);
    final l10n = context.l10n;
    _messenger.currentState?.showSnackBar(
      SnackBar(
        content: Text(l10n.matchNotification(message.data['pet_name'] as String? ?? '')),
        action: SnackBarAction(label: l10n.view, onPressed: () => _openMatch(id)),
        duration: const Duration(seconds: 8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (_, _) => _openPending());
    const seed = Color(0xFF2E7D6B);
    return MaterialApp.router(
      title: 'Winou',
      routerConfig: ref.watch(routerProvider),
      scaffoldMessengerKey: _messenger,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(colorSchemeSeed: seed, useMaterial3: true),
      darkTheme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.dark, useMaterial3: true),
    );
  }
}
