import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../push.dart';

const _tokenKey = 'access_token';
const _refreshKey = 'refresh_token';
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

  String? _refresh; // renews the access token; read from storage at start
  Future<bool>? _renewing;

  Future<void> _restore() async {
    // The splash stays long enough for its animation to play, not just flash
    final (token, refresh, _) = await (
      _storage.read(key: _tokenKey),
      _storage.read(key: _refreshKey),
      Future.delayed(const Duration(milliseconds: 1200)),
    ).wait;
    _refresh = refresh;
    state = AuthState(token: token);
    if (state.signedIn) ref.read(pushProvider).register(); // the token may have changed since
  }

  Future<void> login(String email, String password) async =>
      _save(await ref.read(apiProvider).login(email.trim(), password));

  Future<void> register(String email, String password, String displayName) async =>
      _save(await ref.read(apiProvider).register(email.trim(), password, displayName.trim()));

  /// New tokens after a password change: the other phones were signed out, not this one.
  Future<void> replaceTokens(SessionTokens tokens) => _save(tokens, registerPush: false);

  /// Renews the access token with the refresh token. Requests failing together share one renewal:
  /// a refresh token works only once.
  Future<bool> renew() => _renewing ??= _renew().whenComplete(() => _renewing = null);

  Future<bool> _renew() async {
    final refresh = _refresh;
    if (refresh == null) return false; // signed in before refresh tokens existed
    try {
      await _save(await ref.read(apiProvider).refreshSession(refresh), registerPush: false);
      return true;
    } on ApiException catch (e) {
      if (e.code == 'banned') banned(Ban.fromJson(e.detail!));
      return false;
    }
  }

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

  /// The server refused the session and it couldn't be renewed. A ban has its own screen.
  void sessionEnded() {
    if (state.ban == null && state.signedIn) logout(expired: true);
  }

  /// [expired]: the server already rejected the session, so it can't be told about the logout.
  Future<void> logout({bool expired = false}) async {
    await ref.read(pushProvider).unregister(tellServer: !expired);
    if (_refresh case final refresh? when !expired) {
      try {
        await ref.read(apiProvider).endSession(refresh);
      } catch (_) {} // signed out here anyway; the session expires on its own
    }
    _refresh = null;
    await (_storage.delete(key: _tokenKey), _storage.delete(key: _refreshKey)).wait;
    state = const AuthState();
  }

  Future<void> _save(SessionTokens tokens, {bool registerPush = true}) async {
    _refresh = tokens.refresh;
    await (
      _storage.write(key: _tokenKey, value: tokens.access),
      _storage.write(key: _refreshKey, value: tokens.refresh),
    ).wait;
    state = AuthState(token: tokens.access, ban: state.ban);
    if (registerPush) ref.read(pushProvider).register();
  }
}

final authProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);

/// The API client. It reads the token on each request, so it never needs rebuilding.
final apiProvider = Provider<WinouApi>(
  (ref) => WinouApi(
    token: () => ref.read(authProvider).token,
    renew: () => ref.read(authProvider.notifier).renew(),
    onUnauthorized: () => ref.read(authProvider.notifier).sessionEnded(), // signed out elsewhere, or too long ago
    onBanned: (ban) => ref.read(authProvider.notifier).banned(ban),
  ),
);
