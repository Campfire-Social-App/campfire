import 'package:campfire/api/api_exception.dart';
import 'package:campfire/core/secure_store.dart';
import 'package:campfire/models/user.dart';
import 'package:campfire/state/api.dart';
import 'package:campfire/state/settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Mirrors the `AuthStatus` union in `state/auth.ts`, as a sealed class so the
/// router's switch is checked.
sealed class AuthState {
  const AuthState();
}

/// Reading the stored session at boot. Distinct from "signed out" so the app
/// does not flash the login screen on the way to the chat.
class AuthRestoring extends AuthState {
  const AuthRestoring();
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);

  final User user;
}

class AuthNotifier extends Notifier<AuthState> {
  Future<void> _ready = Future<void>.value();

  /// Completes once the stored session has been restored or ruled out.
  Future<void> get ready => _ready;

  @override
  AuthState build() {
    _ready = restoreSession();
    return const AuthRestoring();
  }

  SessionStore get _store => ref.read(sessionStoreProvider);

  Future<void> login(String username, String password) async {
    final response = await ref.read(apiProvider).login(username, password);
    await _apply(response);
  }

  Future<void> register(String inviteCode, String username, String password) async {
    final response = await ref.read(apiProvider).register(inviteCode, username, password);
    await _apply(response);
  }

  Future<void> _apply(AuthResponse response) async {
    ref.read(tokenHolderProvider)
      ..accessToken = response.accessToken
      ..refreshToken = response.refreshToken;

    await _store.writeRefreshToken(response.refreshToken);
    await _store.writeUser(response.user);

    state = AuthAuthenticated(response.user);
  }

  /// Trades the stored refresh token for a fresh access token. The stored user
  /// paints the shell immediately; READY replaces it a moment later.
  Future<void> restoreSession() async {
    // The API client resolves its base URL from settings on every request.
    // Auth and settings are created together during boot, so a stored refresh
    // token must not race the asynchronous server URL read.
    await ref.read(settingsProvider.notifier).ready;
    final String? refreshToken;
    try {
      refreshToken = await _store.readRefreshToken();
    } on Object catch (error, stackTrace) {
      // Same reasoning as the settings load: an unreadable keystore means
      // "sign in again", never "hang on the splash screen".
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'campfire',
          context: ErrorDescription('reading the stored session'),
        ),
      );
      state = const AuthUnauthenticated();
      return;
    }

    if (refreshToken == null) {
      state = const AuthUnauthenticated();
      return;
    }

    final tokens = ref.read(tokenHolderProvider)..refreshToken = refreshToken;
    final user = await _store.readUser();


    try {
      final response = await ref.read(apiProvider).refresh(refreshToken);
      tokens.accessToken = response.accessToken;
      state = user == null ? const AuthUnauthenticated() : AuthAuthenticated(user);
    } on ApiException catch (error) {
      // A server that is merely unreachable must not cost the user their
      // session — only an actual rejection does. Otherwise opening the app on
      // a dead Wi-Fi would sign them out.
      if (error.isNetworkFailure) {
        state = user == null ? const AuthUnauthenticated() : AuthAuthenticated(user);
        return;
      }
      await _clear();
    }
  }

  /// Called by `ApiClient` when a refresh comes back rejected mid-session.
  Future<void> onSessionExpired() => _clear();

  Future<void> logout() async {
    // Best effort, and before the tokens are dropped — the server needs the
    // Bearer to revoke the session. A failure here changes nothing locally.
    try {
      await ref.read(apiProvider).logout();
    } on ApiException {
      // Tokens are cleared below regardless.
    }
    await _clear();
  }

  Future<void> _clear() async {
    ref.read(tokenHolderProvider).clear();
    await _store.clearSession();
    state = const AuthUnauthenticated();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
