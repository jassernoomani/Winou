import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'uploads.dart';

/// Whether Winou can be reached: the phone has a network, and the last request got an answer.
class Connection {
  const Connection({this.online = true, this.serverReached = true});

  final bool online; // the phone has Wi-Fi or mobile data
  final bool serverReached; // the last request got an answer (false: the server didn't respond)

  bool get ok => online && serverReached;
}

class ConnectionController extends Notifier<Connection> {
  StreamSubscription<List<ConnectivityResult>>? _changes;

  @override
  Connection build() {
    try {
      final connectivity = Connectivity();
      _changes = connectivity.onConnectivityChanged.listen(_network);
      connectivity.checkConnectivity().then(_network, onError: (_) {});
    } catch (_) {
      // No plugin (tests): assume online
    }
    ref.onDispose(() => _changes?.cancel());
    return const Connection();
  }

  void _network(List<ConnectivityResult> results) {
    final online = results.any((r) => r != ConnectivityResult.none);
    if (online == state.online) return;
    // Back online: the server gets another chance, and photos waiting to upload go now
    state = Connection(online: online, serverReached: online || state.serverReached);
    if (online) ref.read(uploadQueueProvider.notifier).send();
  }

  /// From the API client after each request: whether the server answered.
  void serverAnswered(bool answered) {
    if (answered == state.serverReached) return;
    state = Connection(online: state.online, serverReached: answered);
    if (answered) ref.read(uploadQueueProvider.notifier).send();
  }
}

final connectionProvider = NotifierProvider<ConnectionController, Connection>(ConnectionController.new);
