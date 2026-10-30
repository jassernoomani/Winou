import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'api/models.dart';
import 'auth/auth_controller.dart';
import 'auth/auth_screens.dart';
import 'auth/forgot_password_screen.dart';
import 'auth/suspended_screen.dart';
import 'auth/welcome_screen.dart';
import 'chat/chat_screen.dart';
import 'chat/conversations_screen.dart';
import 'home_shell.dart';
import 'map/map_screen.dart';
import 'me/account_screen.dart';
import 'me/admin_screen.dart';
import 'me/admin_user_screen.dart';
import 'me/association_screen.dart';
import 'me/match_detail_screen.dart';
import 'me/my_activity_screen.dart';
import 'me/settings_screen.dart';
import 'preferences.dart';
import 'reports/lost_feed_screen.dart';
import 'reports/lost_report_create_screen.dart';
import 'reports/lost_report_detail_screen.dart';
import 'sightings/sighting_create_screen.dart';
import 'sightings/sighting_detail_screen.dart';
import 'sightings/sighting_thanks_screen.dart';
import 'splash_screen.dart';
import 'widgets/location.dart';

const _publicPaths = {'/welcome', '/login', '/register', '/forgot-password'};

final routerProvider = Provider<GoRouter>((ref) {
  // Re-run the redirect whenever the user signs in or out, or finishes the welcome screens
  final authChanges = ValueNotifier(ref.read(authProvider));
  ref.listen(authProvider, (_, next) => authChanges.value = next);
  final welcomeChanges = ValueNotifier(ref.read(preferencesProvider).welcomeSeen);
  ref.listen(preferencesProvider, (_, next) => welcomeChanges.value = next.welcomeSeen);
  ref.onDispose(() {
    authChanges.dispose();
    welcomeChanges.dispose();
  });
  String? opened; // a shared link that opened the app: shown once signed in

  return GoRouter(
    refreshListenable: Listenable.merge([authChanges, welcomeChanges]),
    redirect: (context, state) {
      final auth = authChanges.value;
      final path = state.matchedLocation;
      final wanted = path.startsWith('/lost/') && path != '/lost/new' ? state.uri.toString() : null;
      if (auth.loading) {
        opened ??= wanted;
        return path == '/splash' ? null : '/splash';
      }
      if (auth.ban != null) return path == '/suspended' ? null : '/suspended';
      if (path == '/suspended') return auth.signedIn ? '/' : '/login';
      if (!auth.signedIn) {
        opened ??= wanted;
        if (!welcomeChanges.value) return path == '/welcome' ? null : '/welcome';
        return _publicPaths.contains(path) && path != '/welcome' ? null : '/login';
      }
      if (_publicPaths.contains(path) || path == '/splash') {
        final next = opened;
        opened = null;
        return next ?? '/';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const LoginScreen(register: true)),
      GoRoute(
        path: '/forgot-password',
        builder: (_, state) => ForgotPasswordScreen(email: state.extra as String?),
      ),
      GoRoute(path: '/suspended', builder: (_, _) => const SuspendedScreen()),
      // The four tabs; every other screen opens over them, full screen
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => HomeShell(shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/', builder: (_, _) => const LostFeedScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/map', builder: (_, _) => const MapScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/conversations', builder: (_, _) => const ConversationsScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/me', builder: (_, _) => const MyActivityScreen())],
          ),
        ],
      ),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(path: '/association', builder: (_, _) => const AssociationScreen()),
      GoRoute(path: '/account', builder: (_, _) => const AccountScreen()),
      GoRoute(
        path: '/admin',
        builder: (_, state) => AdminScreen(tab: state.uri.queryParameters['tab']), // from a notification
      ),
      GoRoute(
        path: '/admin/users/:id',
        builder: (_, state) => AdminUserScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(path: '/lost/new', builder: (_, _) => const LostReportCreateScreen()),
      GoRoute(
        path: '/lost/:id',
        builder: (_, state) =>
            LostReportDetailScreen(id: state.pathParameters['id']!, initial: state.extra as LostReport?),
      ),
      GoRoute(
        path: '/sightings/new',
        builder: (_, state) => SightingCreateScreen(about: state.extra as LostReport?), // "I saw this pet"
      ),
      GoRoute(
        path: '/sightings/:id',
        builder: (_, state) => SightingDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/sightings/:id/thanks',
        builder: (_, state) => SightingThanksScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/matches/:id',
        builder: (_, state) => MatchDetailScreen(id: state.pathParameters['id']!, match: state.extra as Match?),
      ),
      GoRoute(
        path: '/conversations/:id',
        builder: (_, state) => ChatScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/pick-location',
        builder: (_, state) => LocationPickerScreen(initial: state.extra as LatLng?),
      ),
    ],
  );
});
