import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth/auth_controller.dart';

/// Push notifications for new matches: while signed in, this phone's Firebase installation ID is
/// stored on the backend (as fcm_token), which pushes to it when someone may have seen the pet.
class PushNotifications {
  PushNotifications(this._ref) {
    // Created at app start: registration events are not replayed to late listeners
    _registered = _messaging.onRegistered.listen((id) {
      _installationId = id;
      if (_ref.read(authProvider).signedIn) _send(id);
    });
    _ref.onDispose(() => _registered.cancel());
  }

  final Ref _ref;
  late final StreamSubscription<String> _registered;
  String? _installationId;

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  /// Asks for permission (Android 13+) and registers this phone for the signed-in user.
  /// The app works without notifications, so failures are only logged.
  Future<void> register() async {
    try {
      final settings = await _messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      if (_installationId case final id?) await _send(id); // already registered this run
      await _messaging.register(); // new or changed registrations arrive through onRegistered
    } catch (e) {
      debugPrint('push registration failed: $e');
    }
  }

  /// Stops notifications for the user signing out. [tellServer] is false when the session already
  /// expired (the request would fail); unregistering stops them in any case.
  Future<void> unregister({required bool tellServer}) async {
    try {
      if (tellServer) await _ref.read(apiProvider).updateMe(fcmToken: null);
    } catch (e) {
      debugPrint('clearing the push token failed: $e');
    }
    try {
      await _messaging.unregister();
      _installationId = null;
    } catch (e) {
      debugPrint('push unregistration failed: $e');
    }
  }

  Future<void> _send(String id) async {
    try {
      await _ref.read(apiProvider).updateMe(fcmToken: id);
    } catch (e) {
      debugPrint('sending the push token failed: $e');
    }
  }
}

final pushProvider = Provider<PushNotifications>(PushNotifications.new);

/// The screen a notification opens.
String? routeOf(RemoteMessage message) => switch (message.data) {
  {'type': 'match', 'match_id': final String id} => '/matches/$id',
  {'type': 'message', 'conversation_id': final String id} => '/conversations/$id',
  {'type': 'confirmed' || 'found'} => '/conversations',
  {'type': 'help', 'sighting_id': final String id} => '/sightings/$id',
  {'type': 'association'} => '/association',
  _ => null,
};

/// Conversations on screen: their messages arrive there instead of as a banner.
final openConversations = <String>[];

/// Conversation ids of messages received while the app is open.
final incomingMessages = StreamController<String>.broadcast();
