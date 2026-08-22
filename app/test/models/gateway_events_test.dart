import 'package:campfire/models/channel.dart';
import 'package:campfire/models/events.dart';
import 'package:campfire/models/user.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/gateway.dart';

void main() {
  group('GatewayEvent.fromFrame', () {
    test('parses READY into one frame of boot state', () {
      final event = GatewayEvent.fromFrame(readyFrame) as ReadyEvent;
      final data = event.data;

      expect(data.user.username, 'marcio');
      expect(data.user.createdAt, isNull, reason: 'READY builds its user dict by hand');
      expect(data.server.maxUploadBytes, 26214400);
      expect(data.channels.map((c) => c.type), [ChannelType.text, ChannelType.voice]);
      expect(data.dms.single.unreadCount, 3);
      expect(data.onlineUserIds, hasLength(1));
      expect(data.voiceStates.single.speaking, isTrue);
    });

    test('parses MESSAGE_CREATE with attachments and a reply preview', () {
      final event = GatewayEvent.fromFrame(messageCreateFrame) as MessageCreateEvent;

      expect(event.message.content, 'olha esse vídeo @marcio');
      expect(event.message.attachments.single.filename, 'fogueira.mp4');
      expect(event.message.replyTo?.author.username, 'marcio');
      expect(event.message.replyTo?.hasAttachments, isFalse);
    });

    test('parses the small payloads', () {
      expect(
        GatewayEvent.fromFrame(const {
          'op': 'MESSAGE_DELETE',
          'data': {'id': 'm1', 'channel_id': 'c1'},
        }),
        const GatewayEvent.messageDelete(MessageDeleteData(id: 'm1', channelId: 'c1')),
      );
      expect(
        GatewayEvent.fromFrame(const {
          'op': 'CHANNEL_DELETE',
          'data': {'id': 'c1'},
        }),
        const GatewayEvent.channelDelete(ChannelDeleteData(id: 'c1')),
      );
      expect(
        GatewayEvent.fromFrame(const {
          'op': 'TYPING_START',
          'data': {'user_id': 'u1', 'channel_id': 'c1'},
        }),
        const GatewayEvent.typingStart(TypingStartData(userId: 'u1', channelId: 'c1')),
      );
      expect(
        GatewayEvent.fromFrame(const {
          'op': 'PRESENCE_UPDATE',
          'data': {'user_id': 'u1', 'status': 'offline'},
        }),
        const GatewayEvent.presenceUpdate(
          PresenceUpdateData(userId: 'u1', status: PresenceStatus.offline),
        ),
      );
    });

    test('parses every VOICE_STATE_UPDATE action the server sends', () {
      final joined = GatewayEvent.fromFrame(const {
        'op': 'VOICE_STATE_UPDATE',
        'data': {'action': 'joined', 'user_id': 'u1', 'username': 'ana', 'channel_id': 'c1'},
      }) as VoiceStateUpdateEvent;
      expect(joined.data.action, VoiceStateAction.joined);
      expect(joined.data.username, 'ana');

      // Leaving voice altogether reports a null channel.
      final left = GatewayEvent.fromFrame(const {
        'op': 'VOICE_STATE_UPDATE',
        'data': {'action': 'left', 'user_id': 'u1', 'channel_id': null},
      }) as VoiceStateUpdateEvent;
      expect(left.data.channelId, isNull);
      expect(left.data.username, isNull);

      // `room_finished` is about the room, so it names no user at all.
      final finished = GatewayEvent.fromFrame(const {
        'op': 'VOICE_STATE_UPDATE',
        'data': {'action': 'room_finished', 'channel_id': 'c1'},
      }) as VoiceStateUpdateEvent;
      expect(finished.data.action, VoiceStateAction.roomFinished);
      expect(finished.data.userId, isNull);
    });

    test('parses every step of a DM call ring', () {
      for (final (wire, action) in const [
        ('ringing', DMCallAction.ringing),
        ('accepted', DMCallAction.accepted),
        ('declined', DMCallAction.declined),
        ('cancelled', DMCallAction.cancelled),
        ('unavailable', DMCallAction.unavailable),
      ]) {
        final event = GatewayEvent.fromFrame({
          'op': 'DM_CALL',
          'data': {
            'action': wire,
            'channel_id': 'c1',
            'from': const {'id': 'u1', 'username': 'ana'},
          },
        }) as DMCallEvent;

        expect(event.data.action, action);
        expect(event.data.from.username, 'ana');
      }
    });

    test('surfaces an op it does not know instead of throwing', () {
      // A newer server must not be able to kill an older client's socket.
      expect(
        GatewayEvent.fromFrame(const {'op': 'REACTION_ADD', 'data': <String, dynamic>{}}),
        const GatewayEvent.unknown('REACTION_ADD'),
      );
      expect(GatewayEvent.fromFrame(const {}), const GatewayEvent.unknown(''));
    });

    test('accepts a data map that decoded without a value type', () {
      // A frame pulled out of a larger decoded structure can arrive as
      // Map<dynamic, dynamic>; a plain cast would reject it.
      final loose = <String, Object>{
        'op': 'CHANNEL_DELETE',
        'data': <dynamic, dynamic>{'id': 'c1'},
      };

      expect(
        GatewayEvent.fromFrame(loose),
        const GatewayEvent.channelDelete(ChannelDeleteData(id: 'c1')),
      );
    });

    test('lets a known op with a broken payload throw, for the caller to log', () {
      // Unlike an unknown op, this means the contract changed under us — it
      // should be loud in logs rather than silently producing a half-built
      // event. Containing it is the gateway loop's job.
      expect(
        () => GatewayEvent.fromFrame(const {'op': 'CHANNEL_DELETE', 'data': null}),
        throwsA(isA<TypeError>()),
      );
    });
  });

  test('the union covers all fourteen server ops plus the unknown case', () {
    // The point of the sealed class: a fifteenth op on the server stops this
    // switch compiling until someone handles it.
    String name(GatewayEvent event) => switch (event) {
          ReadyEvent() => 'READY',
          MessageCreateEvent() => 'MESSAGE_CREATE',
          MessageUpdateEvent() => 'MESSAGE_UPDATE',
          MessageDeleteEvent() => 'MESSAGE_DELETE',
          MessageReactionUpdateEvent() => 'MESSAGE_REACTION_UPDATE',
          UserUpdateEvent() => 'USER_UPDATE',
          TypingStartEvent() => 'TYPING_START',
          PresenceUpdateEvent() => 'PRESENCE_UPDATE',
          VoiceStateUpdateEvent() => 'VOICE_STATE_UPDATE',
          ChannelCreateEvent() => 'CHANNEL_CREATE',
          ChannelUpdateEvent() => 'CHANNEL_UPDATE',
          ChannelDeleteEvent() => 'CHANNEL_DELETE',
          DMUpdateEvent() => 'DM_UPDATE',
          DMCallEvent() => 'DM_CALL',
          UnknownEvent(:final op) => op,
        };

    expect(name(GatewayEvent.fromFrame(readyFrame)), 'READY');
    expect(name(const GatewayEvent.unknown('NOPE')), 'NOPE');
  });
}
