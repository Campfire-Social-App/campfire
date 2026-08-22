import 'dart:async';

import 'package:campfire/models/events.dart';
import 'package:campfire/ws/gateway.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_socket.dart';

void main() {
  late List<FakeSocket> opened;
  late List<Uri> urls;
  late int authRejections;

  GatewayClient build({
    String? server = 'https://campfire.exemplo.com',
    String? token = 'abc',
    bool handshakeFails = false,
  }) {
    opened = [];
    urls = [];
    authRejections = 0;

    return GatewayClient(
      serverUrl: () => server,
      accessToken: () => token,
      onAuthRejected: () async => authRejections++,
      connector: (url) {
        urls.add(url);
        final socket = FakeSocket();
        opened.add(socket);
        if (handshakeFails) {
          // What a server that is down looks like: the connection never comes
          // up and the channel closes abnormally.
          socket.readyFails = true;
          scheduleMicrotask(() => socket.closeWith(1006));
        }
        return socket;
      },
    );
  }

  test('opens wss with the access token, rewriting the scheme', () async {
    final client = build()..connect();
    addTearDown(client.dispose);

    expect(urls.single.scheme, 'wss');
    expect(urls.single.host, 'campfire.exemplo.com');
    expect(urls.single.path, '/gateway');
    expect(urls.single.queryParameters['token'], 'abc');
  });

  test('keeps plain http as ws, for a server on the LAN', () async {
    final client = build(server: 'http://192.168.0.10:8000')..connect();
    addTearDown(client.dispose);

    expect(urls.single.scheme, 'ws');
    expect(urls.single.port, 8000);
  });

  test('does not open a socket with no session', () {
    final client = build(token: null)..connect();
    addTearDown(client.dispose);

    expect(opened, isEmpty);
  });

  test('decodes frames onto the event stream', () async {
    final client = build();
    addTearDown(client.dispose);

    final events = <GatewayEvent>[];
    client.events.listen(events.add);
    client.connect();
    await Future<void>.delayed(Duration.zero);

    opened.single.deliver({
      'op': 'CHANNEL_DELETE',
      'data': {'id': 'c1'},
    });
    await Future<void>.delayed(Duration.zero);

    expect(events.single, const GatewayEvent.channelDelete(ChannelDeleteData(id: 'c1')));
  });

  test('a malformed frame does not take the connection down', () async {
    final client = build();
    addTearDown(client.dispose);

    final events = <GatewayEvent>[];
    client.events.listen(events.add);
    client.connect();
    await Future<void>.delayed(Duration.zero);

    final socket = opened.single
      // Not JSON at all.
      ..deliver('{{{')
      // A known op whose payload no longer matches the model.
      ..deliver({'op': 'CHANNEL_DELETE', 'data': <String, dynamic>{}});
    await Future<void>.delayed(Duration.zero);

    socket.deliver({
      'op': 'CHANNEL_DELETE',
      'data': {'id': 'c1'},
    });
    await Future<void>.delayed(Duration.zero);

    expect(events, hasLength(1), reason: 'only the good frame got through');
    expect(client.status, GatewayStatus.connected);
  });

  test('heartbeats on the interval the server expects', () {
    fakeAsync((async) {
      final client = build()..connect();
      async
        ..flushMicrotasks()
        ..elapse(const Duration(seconds: 95));

      expect(opened.single.sent.where((f) => f.contains('HEARTBEAT')), hasLength(3));
      client.disconnect();
    });
  });

  test('reconnects on its own after the link drops', () {
    fakeAsync((async) {
      final client = build()..connect();
      async.flushMicrotasks();

      // Wi-Fi goes away mid-session.
      opened.single.closeWith(1006);
      async
        ..flushMicrotasks()
        ..elapse(const Duration(seconds: 1));

      expect(opened, hasLength(2));
      client.disconnect();
    });
  });

  test('a connection that established resets the backoff', () {
    fakeAsync((async) {
      final client = build()..connect();
      async.flushMicrotasks();

      // Each drop follows a successful handshake, so each retry is the first
      // one again — a flapping link should not be punished into a 30s wait.
      for (var attempt = 0; attempt < 3; attempt++) {
        opened.last.closeWith(1006);
        async
          ..flushMicrotasks()
          ..elapse(const Duration(seconds: 1));
        expect(opened, hasLength(attempt + 2));
      }

      client.disconnect();
    });
  });

  test('backs off exponentially while the server stays down', () {
    fakeAsync((async) {
      final client = build(handshakeFails: true)..connect();
      async.flushMicrotasks();
      expect(opened, hasLength(1));

      // No handshake ever succeeds, so nothing resets the counter: the gaps
      // between attempts double — 1s, 2s, 4s.
      async.elapse(const Duration(milliseconds: 900));
      expect(opened, hasLength(1), reason: 'first retry waits 1s');
      async.elapse(const Duration(milliseconds: 200));
      expect(opened, hasLength(2));

      async.elapse(const Duration(milliseconds: 1800));
      expect(opened, hasLength(2), reason: 'second retry waits 2s');
      async.elapse(const Duration(milliseconds: 200));
      expect(opened, hasLength(3));

      async.elapse(const Duration(milliseconds: 3800));
      expect(opened, hasLength(3), reason: 'third retry waits 4s');
      async.elapse(const Duration(milliseconds: 200));
      expect(opened, hasLength(4));

      client.disconnect();
    });
  });

  test('the backoff is capped, so a long outage still recovers quickly', () {
    fakeAsync((async) {
      final client = build(handshakeFails: true)..connect();
      // Ten minutes off the air.
      async
        ..flushMicrotasks()
        ..elapse(const Duration(minutes: 10));
      final afterOutage = opened.length;

      // Never stops trying, and never waits longer than the 30s ceiling.
      expect(afterOutage, greaterThan(10));
      async.elapse(const Duration(seconds: 31));
      expect(opened.length, greaterThan(afterOutage));

      client.disconnect();
    });
  });

  test('refreshes the session before retrying a 1008 rejection', () {
    fakeAsync((async) {
      final client = build()..connect();
      async.flushMicrotasks();

      // Policy violation: the token the socket was opened with had gone stale.
      opened.single.closeWith(1008);
      async
        ..flushMicrotasks()
        ..elapse(const Duration(seconds: 2));

      expect(authRejections, 1, reason: 'refresh before the retry, not after');
      expect(opened, hasLength(2));
      client.disconnect();
    });
  });

  test('a manual disconnect stays disconnected', () {
    fakeAsync((async) {
      final client = build()..connect();
      async.flushMicrotasks();

      client.disconnect();
      async.elapse(const Duration(seconds: 60));

      expect(opened, hasLength(1), reason: 'no reconnect after an intentional close');
      expect(client.status, GatewayStatus.disconnected);
    });
  });

  test('a heartbeat firing into a closed socket is a no-op', () {
    fakeAsync((async) {
      final client = build()..connect();
      async.flushMicrotasks();

      opened.single.closeWith(1006);
      // Would throw a StateError if the client wrote to the dead sink.
      async
        ..flushMicrotasks()
        ..elapse(const Duration(seconds: 60));
      client.disconnect();
    });
  });
}
