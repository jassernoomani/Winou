import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../push.dart';

const _tokenKey = 'access_token';
const _storage = FlutterSecureStorage();

/// The signed-in state: null token = signed out. [loading] is true until the stored token is read.
/// [ban]: an admin suspended the account; the app shows why and nothing else until it's lifted.
class AuthState {
  const AuthState({this.token, this.loading = false, this.ban});

  final String? token;
  final bool loading;
  final Ban? ban;

  bool get signedIn => token != null;
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    _restore();
    return const AuthState(loading: true);
  }

  Future<void> _restore() async {
    // The splash stays long enough for its animation to play, not just flash
    final (token, _) = await (_storage.read(key: _tokenKey), Future.delayed(const Duration(milliseconds: 1200))).wait;
    state = AuthState(token: token);
    if (state.signedIn) ref.read(pushProvider).register(); // the token may have changed since
  }

  Future<void> login(String email, String password) async =>
      _save(await ref.read(apiProvider).login(email.trim(), password));

  Future<void> register(String email, String password, String displayName) async =>
      _save(await ref.read(apiProvider).register(email.trim(), password, displayName.trim()));

  /// The server refused a request, or a sign-in, because the account is banned.
  void banned(Ban ban) => state = AuthState(token: state.token, ban: ban);

  /// After a ban ends: true if the server takes requests again.
  Future<bool> checkBan() async {
    try {
      await ref.read(apiProvider).me();
    } on ApiException catch (e) {
      if (e.code == 'banned' || state.token == null) return false; // still banned, or banned at sign-in
      rethrow;
    }
    state = AuthState(token: state.token);
    return true;
  }

  /// [expired]: the server already rejected the session, so it can't be told about the logout.
  Future<void> logout({bool expired = false}) async {
    await ref.read(pushProvider).unregister(tellServer: !expired);
    await _storage.delete(key: _tokenKey);
    state = const AuthState();
  }

  Future<void> _save(String token) async {
    await _storage.write(key: _tokenKey, value: token);
    state = AuthState(token: token);
    ref.read(pushProvider).register();
  }
}

final authProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);

/// The API client. It reads the token on each request, so it never needs rebuilding.
final apiProvider = Provider<WinouApi>(
  (ref) => WinouApi(
    token: () => ref.read(authProvider).token,
    onUnauthorized: () => ref.read(authProvider.notifier).logout(expired: true), // expired or revoked token
    onBanned: (ban) => ref.read(authProvider.notifier).banned(ban),
  ),
);
