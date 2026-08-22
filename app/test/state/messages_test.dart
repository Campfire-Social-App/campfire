import 'package:campfire/api/client.dart';
import 'package:campfire/core/secure_store.dart';
import 'package:campfire/models/events.dart';
import 'package:campfire/models/message.dart';
import 'package:campfire/models/user.dart';
import 'package:campfire/state/api.dart';
import 'package:campfire/state/auth.dart';
import 'package:campfire/state/gateway.dart';
import 'package:campfire/state/messages.dart';
import 'package:campfire/ws/gateway.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/fake_adapter.dart';
import '../ws/fake_socket.dart';

const _channelId = 'ch1';
const _me = User(id: 'u1', username: 'marcio', isAdmin: false);

Map<String, dynamic> messageJson(
  String id, {
  String content = 'oi',
  String authorId = 'u2',
  String authorName = 'ana',
  String createdAt = '2026-08-20T12:00:00Z',
  List<Map<String, dynamic>> reactions = const [],
}) =>
    {
      'id': id,
      'channel_id': _channelId,
      'author': {'id': authorId, 'username': authorName, 'is_admin': false},
      'content': content,
      'created_at': createdAt,
      'edited_at': null,
      'attachments': <dynamic>[],
      'reply_to': null,
      'reactions': reactions,
    };

void main() {
  late FakeSocket socket;

  /// A container with a signed-in user, a fake network and a socket the test
  /// pushes frames into.
  ProviderContainer containerWith((int, Object?) Function(RequestOptions) handle) {
    socket = FakeSocket();
    final adapter = FakeAdapter(handle);
    final store = InMemorySecureStore();

    final container = ProviderContainer(
      overrides: [
        secureStoreProvider.overrideWithValue(store),
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
    return container;
  }

  /// Lets the notifier's deferred first load, the fake HTTP round trip and any
  /// frame handling run — several turns of the event loop, not one.
  Future<void> settle() async {
    for (var i = 0; i < 8; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// Subscribing is what builds the notifier — nothing loads until something
  /// is watching, exactly as in the app.
  void watch(ProviderContainer container) =>
      container.listen(messagesProvider(_channelId), (_, _) {});

  ChannelMessages stateOf(ProviderContainer container) =>
      container.read(messagesProvider(_channelId));

  MessagesNotifier notifierOf(ProviderContainer container) =>
      container.read(messagesProvider(_channelId).notifier);

  test('loads the first page on first watch', () async {
    final container = containerWith(
      (_) => (200, {
        'messages': [messageJson('m1'), messageJson('m2')],
        'has_more': false,
      }),
    );

    watch(container);

    expect(stateOf(container).loading, isTrue);

    await settle();
    final state = stateOf(container);
    expect(state.messages.map((m) => m.id), ['m1', 'm2']);
    expect(state.loading, isFalse);
    expect(state.hasMore, isFalse);
  });

  test('a failed load keeps the error for the retry', () async {
    final container = containerWith((_) => (500, {'detail': 'boom'}));
    watch(container);
    await settle();
    final state = stateOf(container);

    expect(state.error, isNotNull);
    expect(state.messages, isEmpty);
  });

  test('loadMore prepends the older page and asks from the oldest id', () async {
    var call = 0;
    String? before;

    final container = containerWith((request) {
      call++;
      before = request.queryParameters['before'] as String?;
      return call == 1
          ? (200, {'messages': [messageJson('m5')], 'has_more': true})
          : (200, {'messages': [messageJson('m4')], 'has_more': false});
    });

    watch(container);
    await settle();
    await notifierOf(container).loadMore();
    final state = stateOf(container);

    expect(before, 'm5', reason: 'pages back from the oldest message held');
    expect(state.messages.map((m) => m.id), ['m4', 'm5']);
    expect(state.hasMore, isFalse);
  });

  test('MESSAGE_CREATE appends, and ignores other channels', () async {
    final container = containerWith(
      (_) => (200, {'messages': <dynamic>[], 'has_more': false}),
    );
    watch(container);
    container.read(gatewayProvider).connect();
    await settle();

    socket.deliver({'op': 'MESSAGE_CREATE', 'data': messageJson('m9')});
    await settle();
    expect(stateOf(container).messages.single.id, 'm9');

    socket.deliver({
      'op': 'MESSAGE_CREATE',
      'data': {...messageJson('m10'), 'channel_id': 'outro'},
    });
    await settle();
    expect(stateOf(container).messages, hasLength(1));
  });

  test("an optimistic message is replaced by the server's copy, not doubled", () async {
    final container = containerWith((request) {
      if (request.method == 'POST') {
        return (201, messageJson('real', authorId: 'u1', authorName: 'marcio'));
      }
      return (200, {'messages': <dynamic>[], 'has_more': false});
    });

    watch(container);
    await settle();
    final notifier = notifierOf(container);

    final sending = notifier.send(content: 'oi');

    // Straight away, before the POST comes back: the text is on screen.
    final pending = stateOf(container).messages.single;
    expect(pending.pending, isTrue);
    expect(pending.content, 'oi');

    await sending;
    final settled = stateOf(container).messages;
    expect(settled, hasLength(1));
    expect(settled.single.id, 'real');
    expect(settled.single.pending, isFalse);
  });

  test('a send that fails leaves the message marked, ready to retry', () async {
    final container = containerWith((request) {
      if (request.method == 'POST') return (500, {'detail': 'nope'});
      return (200, {'messages': <dynamic>[], 'has_more': false});
    });

    watch(container);
    await settle();
    final notifier = notifierOf(container);

    await expectLater(notifier.send(content: 'oi'), throwsA(anything));

    final failed = stateOf(container).messages.single;
    expect(failed.sendFailed, isTrue);
    expect(failed.content, 'oi');

    notifier.discard(failed.id);
    expect(stateOf(container).messages, isEmpty);
  });

  test('MESSAGE_DELETE removes, MESSAGE_UPDATE rewrites in place', () async {
    final container = containerWith(
      (_) => (200, {'messages': [messageJson('m1'), messageJson('m2')], 'has_more': false}),
    );
    watch(container);
    container.read(gatewayProvider).connect();
    await settle();

    socket.deliver({
      'op': 'MESSAGE_UPDATE',
      'data': {...messageJson('m1', content: 'editado'), 'edited_at': '2026-08-20T12:05:00Z'},
    });
    await settle();
    expect(
      stateOf(container).messages.first.content,
      'editado',
    );

    socket.deliver({
      'op': 'MESSAGE_DELETE',
      'data': {'id': 'm2', 'channel_id': _channelId},
    });
    await settle();
    expect(
      stateOf(container).messages.map((m) => m.id),
      ['m1'],
    );
  });

  group('reactions', () {
    test('a frame about someone else moves the count but not my flag', () async {
      final container = containerWith(
        (_) => (200, {
          'messages': [
            messageJson('m1', reactions: [
              {'type': 'like', 'count': 1, 'reacted_by_me': true},
            ]),
          ],
          'has_more': false,
        }),
      );
      watch(container);
      container.read(gatewayProvider).connect();
      await settle();

      socket.deliver({
        'op': 'MESSAGE_REACTION_UPDATE',
        'data': {
          'message_id': 'm1',
          'channel_id': _channelId,
          'type': 'like',
          'count': 2,
          'user_id': 'u2',
          'reacted': true,
        },
      });
      await settle();

      final reaction = stateOf(container).messages.single.reactions.single;
      expect(reaction.count, 2);
      expect(reaction.reactedByMe, isTrue, reason: 'the frame was about someone else');
    });

    test('a frame about me flips my flag', () async {
      final container = containerWith(
        (_) => (200, {
          'messages': [
            messageJson('m1', reactions: [
              {'type': 'like', 'count': 1, 'reacted_by_me': true},
            ]),
          ],
          'has_more': false,
        }),
      );
      watch(container);
      container.read(gatewayProvider).connect();
      await settle();

      notifierOf(container).applyReaction(
            const MessageReactionUpdateData(
              messageId: 'm1',
              channelId: _channelId,
              type: ReactionType.like,
              count: 0,
              userId: 'u1',
              reacted: false,
            ),
          );

      // Dropping to zero takes the chip away entirely, as in the web client.
      expect(
        stateOf(container).messages.single.reactions,
        isEmpty,
      );
    });
  });
}

/// Signed in as [_me], without going through the keystore or the network.
class _SignedIn extends AuthNotifier {
  @override
  AuthState build() => const AuthAuthenticated(_me);
}
