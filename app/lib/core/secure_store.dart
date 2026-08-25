import 'dart:convert';

import 'package:campfire/models/user.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The three things that have to survive the app being killed: which server we
/// talk to, the long-lived refresh token, and enough of the signed-in user to
/// paint the shell before READY lands.
///
/// The Tauri client keeps these in an app-local JSON file; on mobile they go to
/// the Keychain / EncryptedSharedPreferences instead, which is what the refresh
/// token (30 days, full session) actually warrants.
abstract interface class SecureStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterSecureStore implements SecureStore {
  const FlutterSecureStore(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Test double, and the fallback on platforms where no keystore is wired up.
class InMemorySecureStore implements SecureStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}

/// Typed view over [SecureStore] — the rest of the app never types a raw key.
class SessionStore {
  const SessionStore(this._store);

  static const _serverUrlKey = 'campfire.server_url';
  static const _refreshTokenKey = 'campfire.refresh_token';
  static const _userKey = 'campfire.user';
  static const _noiseSuppressionKey = 'campfire.noise_suppression';

  final SecureStore _store;

  Future<String?> readServerUrl() => _store.read(_serverUrlKey);

  /// Stores the URL already normalised — see `normalizeServerUrl`, which is the
  /// only thing that should be producing values for this key.
  Future<void> writeServerUrl(String url) => _store.write(_serverUrlKey, url);

  Future<void> clearServerUrl() => _store.delete(_serverUrlKey);

  Future<bool> readNoiseSuppressionEnabled() async =>
      (await _store.read(_noiseSuppressionKey)) != 'false';

  Future<void> writeNoiseSuppressionEnabled({required bool enabled}) =>
      _store.write(_noiseSuppressionKey, '$enabled');

  Future<String?> readRefreshToken() => _store.read(_refreshTokenKey);

  Future<void> writeRefreshToken(String token) => _store.write(_refreshTokenKey, token);

  Future<User?> readUser() async {
    final raw = await _store.read(_userKey);
    if (raw == null) return null;
    try {
      return User.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      // A payload written by an older build that no longer parses is not worth
      // failing the launch over — the READY frame replaces it in a moment.
      await _store.delete(_userKey);
      return null;
    }
  }

  Future<void> writeUser(User user) => _store.write(_userKey, jsonEncode(user.toJson()));

  /// Signing out drops the session but keeps [readServerUrl] — the next login
  /// should land on the same server, not back at the connect screen.
  Future<void> clearSession() async {
    await _store.delete(_refreshTokenKey);
    await _store.delete(_userKey);
  }
}

/// Overridden in tests with an [InMemorySecureStore].
// Android's defaults in flutter_secure_storage 11 already encrypt with AES-GCM
// under an RSA-wrapped Keystore key, so only the iOS side needs saying: the
// refresh token has to be readable by the background gateway reconnect after a
// reboot, which `first_unlock` allows and the stricter `passcode` levels do not.
final secureStoreProvider = Provider<SecureStore>(
  (ref) => const FlutterSecureStore(
    FlutterSecureStorage(
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    ),
  ),
);

final sessionStoreProvider = Provider<SessionStore>(
  (ref) => SessionStore(ref.watch(secureStoreProvider)),
);
