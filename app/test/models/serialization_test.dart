import 'package:campfire/models/attachment.dart';
import 'package:campfire/models/channel.dart';
import 'package:campfire/models/dm.dart';
import 'package:campfire/models/invite.dart';
import 'package:campfire/models/message.dart';
import 'package:campfire/models/server.dart';
import 'package:campfire/models/user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('User', () {
    test('reads the REST shape', () {
      final user = User.fromJson(const {
        'id': 'u1',
        'username': 'marcio',
        'is_admin': true,
        'created_at': '2026-07-01T12:00:00Z',
      });

      expect(user.username, 'marcio');
      expect(user.isAdmin, isTrue);
      expect(user.createdAt, DateTime.utc(2026, 7, 1, 12));
    });

    test('reads the READY shape, which omits created_at', () {
      final user = User.fromJson(const {
        'id': 'u1',
        'username': 'marcio',
        'is_admin': true,
      });

      expect(user.createdAt, isNull);
    });

    test('round-trips through JSON', () {
      const user = User(id: 'u1', username: 'marcio', isAdmin: false);
      expect(User.fromJson(user.toJson()), user);
    });
  });

  group('Channel', () {
    test('maps the type discriminator', () {
      Channel parse(String type) => Channel.fromJson({
            'id': 'c1',
            'name': 'geral',
            'type': type,
            'position': 0,
          });

      expect(parse('text').type, ChannelType.text);
      expect(parse('voice').type, ChannelType.voice);
      expect(parse('dm').type, ChannelType.dm);
    });

    test('falls back rather than throwing on a kind it has never seen', () {
      final channel = Channel.fromJson(const {
        'id': 'c1',
        'name': 'futuro',
        'type': 'stage',
        'position': 0,
      });

      expect(channel.type, ChannelType.text);
    });
  });

  test('DMConversation keeps a null last_message_at', () {
    final dm = DMConversation.fromJson(const {
      'id': 'd1',
      'recipient': {'id': 'u2', 'username': 'ana', 'is_admin': false},
      'last_message_at': null,
      'unread_count': 0,
    });

    expect(dm.lastMessageAt, isNull);
    expect(dm.recipient.username, 'ana');
  });

  test('Attachment keeps the URL server-relative', () {
    final attachment = Attachment.fromJson(const {
      'id': 'a1',
      'filename': 'nota.pdf',
      'content_type': 'application/pdf',
      'size_bytes': 2048,
      'url': '/api/uploads/a1',
      'created_at': '2026-08-16T22:31:00Z',
    });

    expect(attachment.url, '/api/uploads/a1');
    expect(attachment.sizeBytes, 2048);
  });

  group('Message', () {
    test('defaults attachments to empty and reply_to to null', () {
      final message = Message.fromJson(const {
        'id': 'm1',
        'channel_id': 'c1',
        'author': {'id': 'u1', 'username': 'marcio', 'is_admin': false},
        'content': 'oi',
        'created_at': '2026-08-16T22:31:04Z',
        'edited_at': null,
      });

      expect(message.attachments, isEmpty);
      expect(message.replyTo, isNull);
      expect(message.editedAt, isNull);
    });

    test('reads a page', () {
      final page = MessagePage.fromJson(const {
        'messages': <Map<String, dynamic>>[],
        'has_more': true,
      });

      expect(page.hasMore, isTrue);
    });
  });

  test('ServerSettings reads the upload ceiling', () {
    final settings = ServerSettings.fromJson(const {
      'name': 'Campfire',
      'icon_url': null,
      'max_upload_bytes': 26214400,
    });

    expect(settings.maxUploadBytes, 26214400);
    expect(settings.iconUrl, isNull);
  });

  test('Invite reads the unlimited/never-expiring case', () {
    final invite = Invite.fromJson(const {
      'id': 'i1',
      'code': 'ABC123',
      'created_by_id': 'u1',
      'max_uses': null,
      'uses_count': 2,
      'expires_at': null,
      'created_at': '2026-08-16T22:31:00Z',
    });

    expect(invite.maxUses, isNull);
    expect(invite.expiresAt, isNull);
    expect(invite.usesCount, 2);
  });
}
