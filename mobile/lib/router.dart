import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'api/models.dart';
import 'auth/auth_controller.dart';
import 'auth/auth_screens.dart';
import 'auth/forgot_password_screen.dart';
import 'auth/suspended_screen.dart';
import 'chat/chat_screen.dart';
import 'chat/conversations_screen.dart';
import 'map/map_screen.dart';
import 'me/account_screen.dart';
import 'me/admin_screen.dart';
import 'me/admin_user_screen.dart';
import 'me/association_screen.dart';
import 'me/match_detail_screen.dart';
import 'me/my_activity_screen.dart';
import 'reports/lost_feed_screen.dart';
import 'reports/lost_report_create_screen.dart';
import 'reports/lost_report_detail_screen.dart';
import 'sightings/sighting_create_screen.dart';
import 'sightings/sighting_detail_screen.dart';
import 'sightings/sighting_thanks_screen.dart';
import 'splash_screen.dart';
import 'widgets/location.dart';

const _publicPaths = {'/login', '/register', '/forgot-password'};

final routerProvider = Provider<GoRouter>((ref) {
  // Re-run the redirect whenever the user signs in or out
  final authChanges = ValueNotifier(ref.read(authProvider));
  ref.listen(authProvider, (_, next) => authChanges.value = next);
  ref.onDispose(authChanges.dispose);

  return GoRouter(
    refreshListenable: authChanges,
    redirect: (context, state) {
      final auth = authChanges.value;
      final path = state.matchedLocation;
      if (auth.loading) return path == '/splash' ? null : '/splash';
      if (auth.ban != null) return path == '/suspended' ? null : '/suspended';
      if (path == '/suspended') return auth.signedIn ? '/' : '/login';
      if (!auth.signedIn) return _publicPaths.contains(path) ? null : '/login';
      if (_publicPaths.contains(path) || path == '/splash') return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const LoginScreen(register: true)),
      GoRoute(
        path: '/forgot-password',
        builder: (_, state) => ForgotPasswordScreen(email: state.extra as String?),
      ),
      GoRoute(path: '/suspended', builder: (_, _) => const SuspendedScreen()),
      GoRoute(path: '/', builder: (_, _) => const LostFeedScreen()),
      GoRoute(path: '/map', builder: (_, _) => const MapScreen()),
      GoRoute(path: '/me', builder: (_, _) => const MyActivityScreen()),
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
      GoRoute(path: '/sightings/new', builder: (_, _) => const SightingCreateScreen()),
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
      GoRoute(path: '/conversations', builder: (_, _) => const ConversationsScreen()),
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
