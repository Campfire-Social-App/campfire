import 'package:campfire/api/client.dart';
import 'package:campfire/core/secure_store.dart';
import 'package:campfire/livekit/voice.dart';
import 'package:campfire/models/user.dart';
import 'package:campfire/state/api.dart';
import 'package:campfire/state/auth.dart';
import 'package:campfire/state/calls.dart';
import 'package:campfire/state/gateway.dart';
import 'package:campfire/state/voice.dart';
import 'package:campfire/ws/gateway.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/fake_adapter.dart';
import '../ws/fake_socket.dart';

const _me = User(id: 'u1', username: 'marcio', isAdmin: false);
const _dm = 'dm-1';

Map<String, dynamic> _callFrame(String action, {String channelId = _dm}) => {
      'op': 'DM_CALL',
      'data': {
        'action': action,
        'channel_id': channelId,
        'from': {'id': 'u2', 'username': 'ana'},
      },
    };

void main() {
  late FakeSocket socket;
  late FakeAdapter adapter;
  late _FakeSession session;

  ProviderContainer containerWith() {
    socket = FakeSocket();
    adapter = FakeAdapter((_) => (200, <String, dynamic>{}));

    final container = ProviderContainer(
      overrides: [
        secureStoreProvider.overrideWithValue(InMemorySecureStore()),
        apiClientProvider.overrideWith(
          (ref) => ApiClient(
            tokens: ref.watch(tokenHolderProvider),
            serverUrl: () => 'https://campfire.exemplo.com',
            onSessionExpired: () async {},
            dio: Dio()..httpClientAdapter = adapter,
            refreshDio: Dio()..httpClientAdapter = adapter,
          ),
        ),
        authProvider.overrideWith(_SignedIn.new),
        gatewayProvider.overrideWith(
          (ref) => GatewayClient(
            serverUrl: () => 'https://campfire.exemplo.com',
            accessToken: () => 'token',
            onAuthRejected: () async {},
            connector: (_) => socket,
          ),
        ),
        // The room is LiveKit's business and needs a media stack; what matters
        // here is that the signalling asks for it at the right moments.
        voiceSessionProvider.overrideWith((ref) => session = _FakeSession(ref)),
      ],
    );
    addTearDown(container.dispose);

    container
      ..listen(callsProvider, (_, _) {})
      // Read eagerly so `session` points at *this* container's fake before a
      // test reaches for it.
      ..read(voiceSessionProvider)
      ..read(gatewayProvider).connect();
    return container;
  }

  Future<void> settle() async {
    for (var i = 0; i < 4; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  CallsState stateOf(ProviderContainer c) => c.read(callsProvider);
  CallsNotifier notifierOf(ProviderContainer c) => c.read(callsProvider.notifier);

  group('the ring', () {
    test('ringing puts the caller on screen', () async {
      final container = containerWith();
      await settle();

      socket.deliver(_callFrame('ringing'));
      await settle();

      expect(stateOf(container).incoming?.from.username, 'ana');
      expect(stateOf(container).incoming?.channelId, _dm);
    });

    test('cancelled clears the ring and says who called', () async {
      final container = containerWith();
      await settle();

      socket.deliver(_callFrame('ringing'));
      await settle();
      socket.deliver(_callFrame('cancelled'));
      await settle();

      expect(stateOf(container).incoming, isNull);
      expect(stateOf(container).notice?.message, 'Missed call from ana.');
    });

    test('a cancel for a different call leaves this one ringing', () async {
      final container = containerWith();
      await settle();

      socket.deliver(_callFrame('ringing'));
      await settle();
      socket.deliver(_callFrame('cancelled', channelId: 'dm-outro'));
      await settle();

      expect(stateOf(container).incoming?.channelId, _dm);
    });

    test('accepted only stops us waiting — they are joining the room', () async {
      final container = containerWith();
      await settle();
      await notifierOf(container).start(_dm);

      socket.deliver(_callFrame('accepted'));
      await settle();

      expect(stateOf(container).outgoing, isNull);
      expect(session.left, 0, reason: 'we stay in the room they are joining');
    });

    test('declined ends the call on this side too', () async {
      final container = containerWith();
      await settle();
      await notifierOf(container).start(_dm);

      socket.deliver(_callFrame('declined'));
      await settle();

      expect(stateOf(container).outgoing, isNull);
      expect(session.left, 1);
      expect(stateOf(container).notice?.message, 'ana declined the call.');
    });

    test('unavailable reads differently from declined', () async {
      final container = containerWith();
      await settle();
      await notifierOf(container).start(_dm);

      socket.deliver(_callFrame('unavailable'));
      await settle();

      expect(stateOf(container).notice?.message, 'ana is unavailable.');
    });
  });

  group('the actions', () {
    test('start rings first, then joins', () async {
      final container = containerWith();
      await settle();

      await notifierOf(container).start(_dm, video: true);

      expect(adapter.paths, ['/api/dms/$_dm/call']);
      expect(session.joined, [(_dm, true)]);
      expect(stateOf(container).outgoing, _dm);
    });

    test('a join that fails takes the ring down with it', () async {
      final container = containerWith();
      await settle();
      session.joinFails = true;

      await expectLater(notifierOf(container).start(_dm), throwsA(anything));
      await settle();

      expect(stateOf(container).outgoing, isNull);
      // The ring has to be ended, or the other phone keeps ringing at nobody.
      expect(adapter.requests.last.method, 'DELETE');
    });

    test('accepting clears the ring, answers the server and opens the DM', () async {
      final container = containerWith();
      await settle();
      socket.deliver(_callFrame('ringing'));
      await settle();

      await notifierOf(container).accept(_dm);

      expect(stateOf(container).incoming, isNull);
      expect(adapter.paths, contains('/api/dms/$_dm/call/accept'));
      expect(session.joined, [(_dm, false)]);
    });

    test('declining clears the ring and tells the server', () async {
      final container = containerWith();
      await settle();
      socket.deliver(_callFrame('ringing'));
      await settle();

      await notifierOf(container).decline(_dm);

      expect(stateOf(container).incoming, isNull);
      expect(adapter.requests.single.method, 'DELETE');
    });

    test('hanging up a call we are not in still ends the ring', () async {
      final container = containerWith();
      await settle();

      await notifierOf(container).hangUp(_dm);

      expect(session.left, 0, reason: 'there was no room to leave');
      expect(adapter.requests.single.method, 'DELETE');
    });

    test('hanging up a call we are in leaves the room as well', () async {
      final container = containerWith();
      await settle();
      container
          .read(voiceProvider.notifier)
          .setConnection(_dm, VoiceConnectionStatus.connected);

      await notifierOf(container).hangUp(_dm);

      expect(session.left, 1);
    });
  });
}

/// Stands in for the LiveKit room: records what was asked of it.
class _FakeSession extends VoiceSession {
  // Not `super.ref`: the field it forwards to is private, and a super parameter
  // would have to be spelled with the underscore to match it.
  // ignore: use_super_parameters
  _FakeSession(Ref ref) : super(ref);

  final joined = <(String, bool)>[];
  int left = 0;
  bool joinFails = false;

  @override
  Future<void> join(String channelId, {bool camera = false}) async {
    if (joinFails) throw StateError('no media');
    joined.add((channelId, camera));
  }

  @override
  Future<void> leave() async => left++;
}

class _SignedIn extends AuthNotifier {
  @override
  AuthState build() => const AuthAuthenticated(_me);
}
