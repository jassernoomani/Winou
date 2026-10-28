import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/api_client.dart';

const _tokenKey = 'access_token';
const _storage = FlutterSecureStorage();

/// The signed-in state: null token = signed out. [loading] is true until the stored token is read.
class AuthState {
  const AuthState({this.token, this.loading = false});

  final String? token;
  final bool loading;

  bool get signedIn => token != null;
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    _restore();
    return const AuthState(loading: true);
  }

  Future<void> _restore() async {
    state = AuthState(token: await _storage.read(key: _tokenKey));
  }

  Future<void> login(String email, String password) async =>
      _save(await ref.read(apiProvider).login(email.trim(), password));

  Future<void> register(String email, String password, String displayName) async =>
      _save(await ref.read(apiProvider).register(email.trim(), password, displayName.trim()));

  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    state = const AuthState();
  }

  Future<void> _save(String token) async {
    await _storage.write(key: _tokenKey, value: token);
    state = AuthState(token: token);
  }
}

final authProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);

/// The API client. It reads the token on each request, so it never needs rebuilding.
final apiProvider = Provider<WinouApi>(
  (ref) => WinouApi(
    token: () => ref.read(authProvider).token,
    onUnauthorized: () => ref.read(authProvider.notifier).logout(), // expired or revoked token
  ),
);
