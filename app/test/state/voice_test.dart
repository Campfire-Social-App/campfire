import 'package:campfire/api/client.dart';
import 'package:campfire/core/secure_store.dart';
import 'package:campfire/core/sounds.dart';
import 'package:campfire/models/user.dart';
import 'package:campfire/state/api.dart';
import 'package:campfire/state/auth.dart';
import 'package:campfire/state/gateway.dart';
import 'package:campfire/state/voice.dart';
import 'package:campfire/ws/gateway.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/fake_adapter.dart';
import '../ws/fake_socket.dart';

const _me = User(id: 'u1', username: 'marcio', isAdmin: false);
const _voiceChannel = 'c-voice';

Map<String, dynamic> _voiceFrame(
  String action, {
  String? userId = 'u2',
  String? username = 'ana',
  String? channelId = _voiceChannel,
}) =>
    {
      'op': 'VOICE_STATE_UPDATE',
      'data': {
        'action': action,
        'user_id': userId,
        'username': username,
        'channel_id': channelId,
      },
    };

void main() {
  late FakeSocket socket;
  late _SilentSounds sounds;

  ProviderContainer containerWith() {
    socket = FakeSocket();
    sounds = _SilentSounds();
    final adapter = FakeAdapter((_) => (200, <String, dynamic>{}));

    final container = ProviderContainer(
      overrides: [
        secureStoreProvider.overrideWithValue(InMemorySecureStore()),
        soundsProvider.overrideWithValue(sounds),
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
      ],
    );
    addTearDown(container.dispose);

    container
      ..listen(voiceProvider, (_, _) {})
      ..read(gatewayProvider).connect();
    return container;
  }

  Future<void> settle() async {
    for (var i = 0; i < 4; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  VoiceState stateOf(ProviderContainer c) => c.read(voiceProvider);
  VoiceNotifier notifierOf(ProviderContainer c) => c.read(voiceProvider.notifier);

  test('READY seeds who is already in a room', () async {
    final container = containerWith();
    await settle();

    socket.deliver({
      'op': 'READY',
      'data': {
        'user': {'id': 'u1', 'username': 'marcio', 'is_admin': false},
        'server': {'name': 'Campfire', 'icon_url': null, 'max_upload_bytes': 1},
        'channels': <dynamic>[],
        'dms': <dynamic>[],
        'online_user_ids': <String>[],
        'voice_states': [
          {
            'user_id': 'u2',
            'username': 'ana',
            'channel_id': _voiceChannel,
            'muted': true,
            'speaking': false,
          },
        ],
      },
    });
    await settle();

    final participant = stateOf(container).inChannel(_voiceChannel).single;
    expect(participant.username, 'ana');
    expect(participant.muted, isTrue);
    // The server never sends it — it is a room attribute, and we are not in the
    // room.
    expect(participant.deafened, isFalse);
  });

  test('joined adds once, even if the same person joins twice', () async {
    final container = containerWith();
    await settle();

    socket
      ..deliver(_voiceFrame('joined'))
      ..deliver(_voiceFrame('joined'));
    await settle();

    expect(stateOf(container).inChannel(_voiceChannel), hasLength(1));
  });

  test('joining another room moves the person rather than cloning them', () async {
    final container = containerWith();
    await settle();

    socket.deliver(_voiceFrame('joined'));
    await settle();
    socket.deliver(_voiceFrame('joined', channelId: 'c-outro'));
    await settle();

    expect(stateOf(container).inChannel(_voiceChannel), isEmpty);
    expect(stateOf(container).inChannel('c-outro'), hasLength(1));
  });

  test('left removes, room_finished empties the room', () async {
    final container = containerWith();
    await settle();

    socket
      ..deliver(_voiceFrame('joined'))
      ..deliver(_voiceFrame('joined', userId: 'u3', username: 'bia'));
    await settle();
    expect(stateOf(container).inChannel(_voiceChannel), hasLength(2));

    socket.deliver(_voiceFrame('left', username: null));
    await settle();
    expect(stateOf(container).inChannel(_voiceChannel).single.userId, 'u3');

    socket.deliver(_voiceFrame('room_finished', userId: null, username: null));
    await settle();
    expect(stateOf(container).inChannel(_voiceChannel), isEmpty);
  });

  group('join and leave sounds', () {
    test('play for other people in the room we are sitting in', () async {
      final container = containerWith();
      await settle();
      notifierOf(container).setConnection(_voiceChannel, VoiceConnectionStatus.connected);

      socket.deliver(_voiceFrame('joined'));
      await settle();
      socket.deliver(_voiceFrame('left'));
      await settle();

      expect(sounds.played, ['join.mp3', 'leave.mp3']);
    });

    test('stay quiet for a room we are not in', () async {
      containerWith();
      await settle();

      socket.deliver(_voiceFrame('joined'));
      await settle();

      expect(sounds.played, isEmpty);
    });

    test('stay quiet for ourselves — the room lifecycle already sounded', () async {
      final container = containerWith();
      await settle();
      notifierOf(container).setConnection(_voiceChannel, VoiceConnectionStatus.connected);

      socket.deliver(_voiceFrame('joined', userId: 'u1', username: 'marcio'));
      await settle();

      expect(sounds.played, isEmpty);
    });
  });

  test('disconnecting drops everything that was true of the room', () {
    final container = containerWith();
    final notifier = notifierOf(container)
      ..setConnection(_voiceChannel, VoiceConnectionStatus.connected)
      ..setSpeaking(['u2'])
      ..setLocalCameraEnabled(enabled: true)
      ..setLocalScreenShareEnabled(enabled: true);

    expect(stateOf(container).speakingUserIds, {'u2'});

    notifier.setConnection(null, VoiceConnectionStatus.disconnected);
    final state = stateOf(container);

    expect(state.connectedChannelId, isNull);
    expect(state.speakingUserIds, isEmpty);
    expect(state.localCameraEnabled, isFalse);
    expect(state.localScreenShareEnabled, isFalse);
    // Mute and deafen are the user's standing preference, not the room's: they
    // survive, so the next join starts muted if this one was.
    expect(state.localMuted, isFalse);
  });

  test('mute is remembered across a disconnect', () {
    final container = containerWith();
    final notifier = notifierOf(container)
      ..setConnection(_voiceChannel, VoiceConnectionStatus.connected)
      ..setLocalMuted(muted: true)
      ..setConnection(null, VoiceConnectionStatus.disconnected);

    expect(stateOf(container).localMuted, isTrue);
    notifier.setLocalMuted(muted: false);
    expect(stateOf(container).localMuted, isFalse);
  });
}

/// Records what would have been played instead of reaching for an audio device.
class _SilentSounds extends Sounds {
  final played = <String>[];

  @override
  void play(String asset) => played.add(asset);
}

class _SignedIn extends AuthNotifier {
  @override
  AuthState build() => const AuthAuthenticated(_me);
}
