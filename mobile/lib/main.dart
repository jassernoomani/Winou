import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show LicenseEntryWithLineBreaks, LicenseRegistry;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/providers.dart';
import 'auth/auth_controller.dart';
import 'l10n/app_localizations.dart';
import 'home_shell.dart' show tabRoots;
import 'preferences.dart';
import 'push.dart';
import 'router.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/server_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // config from android/app/google-services.json
  await (loadServerAddress(), loadPreferences(), initDates()).wait; // the server and the theme and language chosen in the app
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(['Nunito'], await rootBundle.loadString('assets/fonts/OFL.txt'));
    yield LicenseEntryWithLineBreaks(['Tajawal'], await rootBundle.loadString('assets/fonts/OFL-Tajawal.txt'));
  });
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
  String? _pendingRoute; // tapped before the user was signed in

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

  /// A notification was tapped: show its screen once the user is signed in.
  void _open(RemoteMessage message) {
    _pendingRoute = routeOf(message);
    _openPending();
  }

  void _openPending() {
    final route = _pendingRoute;
    final auth = ref.read(authProvider);
    if (route == null || auth.loading || !auth.signedIn) return;
    _pendingRoute = null;
    _go(route);
  }

  void _go(String route) {
    final router = ref.read(routerProvider);
    if (router.state.uri.path == '/splash') {
      // Starting up: wait until the router has moved on to the home screen
      WidgetsBinding.instance.addPostFrameCallback((_) => _go(route));
      WidgetsBinding.instance.scheduleFrame();
      return;
    }
    // Already showing it (the app was in the background on that screen): just come back to it
    if (router.state.uri.path == route) return; // state: the top screen, pushed ones included
    tabRoots.contains(route) ? router.go(route) : router.push(route); // a tab is switched to, not stacked
  }

  /// While the app is open, Android shows no notification: show a snack bar instead, or nothing
  /// when the conversation is already on screen.
  void _showInApp(RemoteMessage message) {
    ref
      ..invalidate(myMatchesProvider)
      ..invalidate(conversationsProvider);
    final data = message.data;
    final conversationId = data['conversation_id'] as String?;
    if (conversationId != null) {
      incomingMessages.add(conversationId);
      if (openConversations.contains(conversationId)) return;
    }
    final context = _messenger.currentContext;
    final route = routeOf(message);
    if (context == null || route == null) return;
    final l10n = context.l10n;
    final name = data['pet_name'] as String? ?? '';
    final text = switch (data['type']) {
      'match' => l10n.matchNotification(name),
      'message' => l10n.messageNotification(data['sender_name'] as String? ?? ''),
      'confirmed' => l10n.confirmedNotification(name),
      'found' => l10n.foundNotification(name),
      'help' => l10n.helpNotification,
      'association' => l10n.associationNotification,
      _ => null,
    };
    if (text == null) return;
    _messenger.currentState?.showSnackBar(
      SnackBar(
        content: Text(text),
        action: SnackBarAction(label: l10n.view, onPressed: () => _go(route)),
        duration: const Duration(seconds: 8),
        persist: false, // with an action it would otherwise stay until dismissed
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (_, _) => _openPending());
    final prefs = ref.watch(preferencesProvider);
    return MaterialApp.router(
      title: 'Winou',
      routerConfig: ref.watch(routerProvider),
      scaffoldMessengerKey: _messenger,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: winouTheme(Brightness.light),
      darkTheme: winouTheme(Brightness.dark),
      themeMode: prefs.themeMode,
      locale: prefs.locale,
    );
  }
}
