import 'package:campfire/api/api_exception.dart';
import 'package:campfire/api/client.dart';
import 'package:campfire/core/secure_store.dart';
import 'package:campfire/models/user.dart';
import 'package:campfire/state/api.dart';
import 'package:campfire/state/auth.dart';
import 'package:campfire/state/settings.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/fake_adapter.dart';

/// A store whose reads blow up, standing in for a keystore that will not open.
class _BrokenStore implements SecureStore {
  @override
  Future<String?> read(String key) async => throw StateError('keystore unavailable');

  @override
  Future<void> write(String key, String value) async {}

  @override
  Future<void> delete(String key) async {}
}

/// What `/api/auth/login` answers on success.
(int, Object?) _authResponse(RequestOptions request) => (200, {
      'access_token': 'access-abc',
      'refresh_token': 'refresh-abc',
      'token_type': 'bearer',
      'user': {
        'id': 'u1',
        'username': 'marcio',
        'is_admin': false,
        'created_at': '2026-07-01T12:00:00Z',
      },
    });

void main() {
  late InMemorySecureStore store;
  late FakeAdapter adapter;

  ProviderContainer containerWith({
    SecureStore? secureStore,
    (int, Object?) Function(RequestOptions)? handle,
  }) {
    adapter = FakeAdapter(handle ?? (_) => (200, <String, dynamic>{}));

    final container = ProviderContainer(
      overrides: [
        secureStoreProvider.overrideWithValue(secureStore ?? store),
        apiClientProvider.overrideWith(
          (ref) => ApiClient(
            tokens: ref.watch(tokenHolderProvider),
            serverUrl: () => ref.read(settingsProvider).serverUrl,
            onSessionExpired: () => ref.read(authProvider.notifier).onSessionExpired(),
            dio: Dio()..httpClientAdapter = adapter,
            refreshDio: Dio()..httpClientAdapter = adapter,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() => store = InMemorySecureStore());

  group('settings', () {
    test('starts unloaded so the router does not flash the connect screen', () {
      final container = containerWith();
      expect(container.read(settingsProvider).loaded, isFalse);
    });

    test('reports the stored server once the keystore answers', () async {
      await SessionStore(store).writeServerUrl('https://campfire.exemplo.com');
      final container = containerWith();

      await container.read(settingsProvider.notifier).ready;

      final settings = container.read(settingsProvider);
      expect(settings.loaded, isTrue);
      expect(settings.serverUrl, 'https://campfire.exemplo.com');
    });

    test('normalises on the way in', () async {
      final container = containerWith();
      await container.read(settingsProvider.notifier).setServerUrl('  dominio.com/  ');

      expect(container.read(settingsProvider).serverUrl, 'https://dominio.com');
      expect(await SessionStore(store).readServerUrl(), 'https://dominio.com');
    });

    test('finishes loading even when the keystore will not open', () async {
      // The failure mode this guards against is the worst kind: `loaded` never
      // flipping leaves the app on the splash screen with no way out.
      final container = containerWith(secureStore: _BrokenStore());

      await container.read(settingsProvider.notifier).ready;

      expect(container.read(settingsProvider).loaded, isTrue);
      expect(container.read(settingsProvider).serverUrl, isNull);
    });
  });

  group('session restore', () {
    test('lands signed out on a clean install', () async {
      final container = containerWith();

      await container.read(authProvider.notifier).ready;

      expect(container.read(authProvider), isA<AuthUnauthenticated>());
    });

    test('restores without a login screen when a session is stored', () async {
      final session = SessionStore(store);
      await session.writeServerUrl('https://campfire.exemplo.com');
      await session.writeRefreshToken('refresh-abc');
      await session.writeUser(const User(id: 'u1', username: 'marcio', isAdmin: true));

      final container = containerWith(
        handle: (_) => (200, {'access_token': 'novo', 'token_type': 'bearer'}),
      );
      await container.read(settingsProvider.notifier).ready;
      await container.read(authProvider.notifier).restoreSession();

      expect(container.read(authProvider), isA<AuthAuthenticated>());
      expect((container.read(authProvider) as AuthAuthenticated).user.username, 'marcio');
      expect(container.read(tokenHolderProvider).accessToken, 'novo');
    });

    test('keeps the session when the server is merely unreachable', () async {
      // Opening the app on dead Wi-Fi must not cost the user their session.
      final session = SessionStore(store);
      await session.writeServerUrl('https://campfire.exemplo.com');
      await session.writeRefreshToken('refresh-abc');
      await session.writeUser(const User(id: 'u1', username: 'marcio', isAdmin: false));

      final container = containerWith(
        handle: (_) => throw DioException.connectionError(
          requestOptions: RequestOptions(),
          reason: 'offline',
        ),
      );
      await container.read(settingsProvider.notifier).ready;
      await container.read(authProvider.notifier).restoreSession();

      expect(container.read(authProvider), isA<AuthAuthenticated>());
      expect(await session.readRefreshToken(), 'refresh-abc');
    });

    test('drops the session when the server actually rejects the refresh', () async {
      final session = SessionStore(store);
      await session.writeServerUrl('https://campfire.exemplo.com');
      await session.writeRefreshToken('refresh-morto');
      await session.writeUser(const User(id: 'u1', username: 'marcio', isAdmin: false));

      final container = containerWith(handle: (_) => (401, {'detail': 'Session expired'}));
      await container.read(settingsProvider.notifier).ready;
      await container.read(authProvider.notifier).restoreSession();

      expect(container.read(authProvider), isA<AuthUnauthenticated>());
      expect(await session.readRefreshToken(), isNull);
      // Signing out keeps the server, so the next login lands on it.
      expect(await session.readServerUrl(), 'https://campfire.exemplo.com');
    });

    test('signing out clears the session but not the server', () async {
      final container = containerWith(handle: _authResponse);
      await container.read(settingsProvider.notifier).setServerUrl('campfire.exemplo.com');
      await container.read(authProvider.notifier).login('marcio', 'senha');

      expect(container.read(authProvider), isA<AuthAuthenticated>());

      await container.read(authProvider.notifier).logout();

      expect(container.read(authProvider), isA<AuthUnauthenticated>());
      expect(container.read(tokenHolderProvider).accessToken, isNull);
      expect(container.read(settingsProvider).serverUrl, 'https://campfire.exemplo.com');
    });
  });

  test("a rejected login surfaces the server's reason", () async {
    final container = containerWith(
      handle: (_) => (401, {'detail': 'Invalid username or password'}),
    );
    await container.read(settingsProvider.notifier).setServerUrl('campfire.exemplo.com');

    await expectLater(
      container.read(authProvider.notifier).login('marcio', 'errada'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.message, 'message', 'Invalid username or password'),
      ),
    );
    expect(container.read(authProvider), isA<AuthUnauthenticated>());
  });
}
