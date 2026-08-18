import 'dart:async';

import 'package:campfire/api/api_exception.dart';
import 'package:campfire/api/client.dart';
import 'package:campfire/api/token_holder.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_adapter.dart';

void main() {
  late TokenHolder tokens;
  late int sessionsExpired;

  /// Builds a client whose network is [handle]. The refresh call gets its own
  /// adapter so the test can see the two apart.
  ({ApiClient client, FakeAdapter api, FakeAdapter refresh}) build(
    FutureOr<(int, Object?)> Function(RequestOptions) handle, {
    FutureOr<(int, Object?)> Function(RequestOptions)? refreshHandle,
  }) {
    final api = FakeAdapter(handle);
    final refresh = FakeAdapter(
      refreshHandle ?? (_) => (200, {'access_token': 'novo', 'token_type': 'bearer'}),
    );
    final dio = Dio()..httpClientAdapter = api;
    final refreshDio = Dio()..httpClientAdapter = refresh;

    return (
      client: ApiClient(
        tokens: tokens,
        serverUrl: () => 'https://campfire.exemplo.com',
        onSessionExpired: () async => sessionsExpired++,
        dio: dio,
        refreshDio: refreshDio,
      ),
      api: api,
      refresh: refresh,
    );
  }

  setUp(() {
    tokens = TokenHolder(accessToken: 'velho', refreshToken: 'refresh-abc');
    sessionsExpired = 0;
  });

  group('requests', () {
    test('sends the Bearer token and the configured base URL', () async {
      final env = build((_) => (200, {'name': 'Campfire'}));

      await env.client.request<Map<String, dynamic>>(
        '/api/server',
        decode: (json) => json as Map<String, dynamic>,
      );

      final sent = env.api.requests.single;
      expect(sent.headers['Authorization'], 'Bearer velho');
      expect(sent.uri.toString(), 'https://campfire.exemplo.com/api/server');
    });

    test('leaves the Bearer off an anonymous request', () async {
      final env = build((_) => (200, {'ok': true}));

      await env.client.request<void>('/api/auth/login', method: 'POST', anonymous: true);

      expect(env.api.requests.single.headers.containsKey('Authorization'), isFalse);
    });

    test('follows the server URL when it changes, without being rebuilt', () async {
      var server = 'https://um.exemplo.com';
      final api = FakeAdapter((_) => (200, <String, dynamic>{}));
      final client = ApiClient(
        tokens: tokens,
        serverUrl: () => server,
        onSessionExpired: () async {},
        dio: Dio()..httpClientAdapter = api,
        refreshDio: Dio()..httpClientAdapter = FakeAdapter((_) => (200, null)),
      );

      await client.request<void>('/api/server');
      server = 'https://dois.exemplo.com';
      await client.request<void>('/api/server');

      expect(api.requests.first.uri.host, 'um.exemplo.com');
      expect(api.requests.last.uri.host, 'dois.exemplo.com');
    });

    test('refuses to fire with no server configured', () async {
      final client = ApiClient(
        tokens: tokens,
        serverUrl: () => null,
        onSessionExpired: () async {},
        dio: Dio()..httpClientAdapter = FakeAdapter((_) => (200, null)),
      );

      await expectLater(
        client.request<void>('/api/server'),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('No server'))),
      );
    });
  });

  group('errors', () {
    test("surfaces FastAPI's `detail` rather than the status line", () async {
      final env = build((_) => (401, {'detail': 'Invalid username or password'}));

      await expectLater(
        env.client.request<void>('/api/auth/login', method: 'POST', anonymous: true),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'status', 401)
              .having((e) => e.message, 'message', 'Invalid username or password'),
        ),
      );
    });

    test('reports a transport failure as status 0', () async {
      final api = FakeAdapter((_) => throw DioException.connectionError(
            requestOptions: RequestOptions(),
            reason: 'sem rede',
          ));
      final client = ApiClient(
        tokens: tokens,
        serverUrl: () => 'https://campfire.exemplo.com',
        onSessionExpired: () async {},
        dio: Dio()..httpClientAdapter = api,
      );

      await expectLater(
        client.request<void>('/api/server'),
        throwsA(isA<ApiException>().having((e) => e.isNetworkFailure, 'network', isTrue)),
      );
    });
  });

  group('token refresh', () {
    test('refreshes once on a 401 and replays the request with the new token', () async {
      var served = 0;
      final env = build((request) {
        served++;
        // First attempt carries the stale token; the replay carries the new one.
        return request.headers['Authorization'] == 'Bearer novo'
            ? (200, {'name': 'Campfire'})
            : (401, {'detail': 'Token expired'});
      });

      final body = await env.client.request<Map<String, dynamic>>(
        '/api/server',
        decode: (json) => json as Map<String, dynamic>,
      );

      expect(body['name'], 'Campfire');
      expect(served, 2, reason: 'original + replay');
      expect(env.refresh.requests, hasLength(1));
      expect(tokens.accessToken, 'novo');
    });

    test('five parallel 401s trigger exactly one refresh', () async {
      // The bug this guards against: N concurrent requests each starting their
      // own refresh. The server rotates the refresh token, so all but one of
      // those would come back holding a token that is already dead — and the
      // user gets logged out mid-session for no reason.
      final refreshStarted = Completer<void>();
      final refreshMayFinish = Completer<void>();

      final env = build(
        (request) => request.headers['Authorization'] == 'Bearer novo'
            ? (200, {'ok': true})
            : (401, {'detail': 'Token expired'}),
        refreshHandle: (_) async {
          if (!refreshStarted.isCompleted) refreshStarted.complete();
          // Held open so all five 401s are in flight before any of them can
          // see a refreshed token — the actual race.
          await refreshMayFinish.future;
          return (200, {'access_token': 'novo', 'token_type': 'bearer'});
        },
      );

      final inFlight = List.generate(
        5,
        (i) => env.client.request<Map<String, dynamic>>(
          '/api/channels/$i/messages',
          decode: (json) => json as Map<String, dynamic>,
        ),
      );

      await refreshStarted.future;
      refreshMayFinish.complete();
      await Future.wait(inFlight);

      expect(env.refresh.requests, hasLength(1), reason: 'one refresh for five 401s');
      expect(env.api.requests, hasLength(10), reason: '5 original + 5 replayed');
      expect(tokens.accessToken, 'novo');
    });

    test('a later expiry starts a fresh refresh rather than reusing the old one', () async {
      var acceptedToken = 'novo';
      var issued = 0;
      final env = build(
        (request) => request.headers['Authorization'] == 'Bearer $acceptedToken'
            ? (200, {'ok': true})
            : (401, {'detail': 'Token expired'}),
        refreshHandle: (_) {
          issued++;
          return (200, {'access_token': acceptedToken, 'token_type': 'bearer'});
        },
      );

      await env.client.request<void>('/api/server');
      acceptedToken = 'terceiro';
      await env.client.request<void>('/api/server');

      expect(issued, 2);
    });

    test('drops the session when the refresh itself is rejected', () async {
      final env = build(
        (_) => (401, {'detail': 'Token expired'}),
        refreshHandle: (_) => (401, {'detail': 'Session expired'}),
      );

      await expectLater(
        env.client.request<void>('/api/server'),
        // The caller sees the original 401, not the refresh's.
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
      );
      expect(sessionsExpired, 1);
      expect(env.api.requests, hasLength(1), reason: 'no replay after a dead session');
    });

    test('does not try to refresh with no refresh token', () async {
      tokens.refreshToken = null;
      final env = build((_) => (401, {'detail': 'Not authenticated'}));

      await expectLater(env.client.request<void>('/api/server'), throwsA(isA<ApiException>()));

      expect(env.refresh.requests, isEmpty);
      expect(sessionsExpired, 0);
    });

    test('gives up after one replay instead of looping on a persistent 401', () async {
      final env = build((_) => (401, {'detail': 'Token expired'}));

      await expectLater(env.client.request<void>('/api/server'), throwsA(isA<ApiException>()));

      expect(env.api.requests, hasLength(2), reason: 'original + one replay, then stop');
      expect(env.refresh.requests, hasLength(1));
    });

    test('never refreshes an anonymous request', () async {
      final env = build((_) => (401, {'detail': 'Invalid username or password'}));

      await expectLater(
        env.client.request<void>('/api/auth/login', method: 'POST', anonymous: true),
        throwsA(isA<ApiException>()),
      );

      expect(env.refresh.requests, isEmpty);
    });
  });

  group('resolveAssetUrl', () {
    test('joins a server-relative path onto the configured server', () {
      final env = build((_) => (200, null));
      expect(
        env.client.resolveAssetUrl('/api/uploads/abc'),
        'https://campfire.exemplo.com/api/uploads/abc',
      );
    });

    test('leaves an absolute URL alone', () {
      final env = build((_) => (200, null));
      expect(env.client.resolveAssetUrl('https://cdn.exemplo.com/a.png'),
          'https://cdn.exemplo.com/a.png');
    });
  });
}
