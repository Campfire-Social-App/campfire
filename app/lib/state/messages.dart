import 'dart:async';

import 'package:campfire/models/events.dart';
import 'package:campfire/models/message.dart';
import 'package:campfire/state/api.dart';
import 'package:campfire/state/auth.dart';
import 'package:campfire/state/gateway.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One channel's history, oldest first — the order the list renders in.
@immutable
class ChannelMessages {
  const ChannelMessages({
    this.messages = const [],
    this.hasMore = false,
    this.loading = false,
    this.loadingMore = false,
    this.error,
  });

  final List<Message> messages;

  /// Whether the server said there is another page above this one.
  final bool hasMore;

  /// The first load, when there is nothing to show yet.
  final bool loading;

  /// A page being fetched above what is already on screen.
  final bool loadingMore;

  /// Set when the first load failed; the list offers a retry rather than
  /// pretending the channel is empty.
  final String? error;

  bool get isEmpty => messages.isEmpty;

  ChannelMessages copyWith({
    List<Message>? messages,
    bool? hasMore,
    bool? loading,
    bool? loadingMore,
    String? error,
    bool clearError = false,
  }) {
    return ChannelMessages(
      messages: messages ?? this.messages,
      hasMore: hasMore ?? this.hasMore,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// The history of one channel or DM conversation. Port of `state/messages.ts`,
/// split per channel instead of one map: a family keyed by channel id means the
/// chat pane only rebuilds for the conversation it is showing.
///
/// Kept alive across a channel switch (see [messagesProvider]), so going back to
/// a channel shows what was already loaded instead of a spinner.
class MessagesNotifier extends Notifier<ChannelMessages> {
  MessagesNotifier(this._channelId);

  final String _channelId;

  @override
  ChannelMessages build() {
    listenToGateway(ref, _apply);
    // After this build returns, not during it: `load` touches `state`, which
    // does not exist until the initial value below has been handed back.
    unawaited(Future.microtask(load));
    return const ChannelMessages(loading: true);
  }

  void _apply(GatewayEvent event) {
    switch (event) {
      case MessageCreateEvent(:final message):
        if (message.channelId != _channelId) return;
        // The optimistic copy of our own message is still in the list; the
        // server's version replaces it rather than doubling it up.
        final pending = state.messages.indexWhere(
          (m) => m.pending && m.author.id == message.author.id && m.content == message.content,
        );
        if (pending >= 0) {
          final messages = [...state.messages];
          messages[pending] = message;
          state = state.copyWith(messages: messages);
          return;
        }
        if (state.messages.any((m) => m.id == message.id)) return;
        state = state.copyWith(messages: [...state.messages, message]);

      case MessageUpdateEvent(:final message):
        if (message.channelId != _channelId) return;
        state = state.copyWith(
          messages: [
            for (final existing in state.messages)
              if (existing.id != message.id)
                existing
              else
                // The broadcast carries everyone's counts but cannot know
                // whether *this* client reacted, so the local flags survive the
                // edit — same reconciliation `updateMessage` does in the store.
                message.copyWith(
                  reactions: [
                    for (final reaction in message.reactions)
                      reaction.copyWith(
                        reactedByMe: existing.reactions
                                .where((current) => current.type == reaction.type)
                                .firstOrNull
                                ?.reactedByMe ??
                            reaction.reactedByMe,
                      ),
                  ],
                ),
          ],
        );

      case MessageDeleteEvent(:final data):
        if (data.channelId != _channelId) return;
        state = state.copyWith(
          messages: state.messages.where((m) => m.id != data.id).toList(),
        );

      case MessageReactionUpdateEvent(:final data):
        if (data.channelId != _channelId) return;
        applyReaction(data);

      case _:
        break;
    }
  }

  /// First page. Also the retry path, so a channel that failed to load once is
  /// one tap from trying again.
  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final page = await ref.read(apiProvider).listMessages(_channelId);
      state = ChannelMessages(messages: page.messages, hasMore: page.hasMore);
    } on Object catch (error) {
      state = state.copyWith(loading: false, error: '$error');
    }
  }

  /// The page above what is on screen, requested when the list nears the top.
  Future<void> loadMore() async {
    final current = state;
    if (current.loading || current.loadingMore || !current.hasMore || current.isEmpty) {
      return;
    }

    state = current.copyWith(loadingMore: true);
    try {
      final page = await ref.read(apiProvider).listMessages(
            _channelId,
            before: current.messages.first.id,
          );
      // Re-read: a live message may have arrived while the page was in flight.
      state = state.copyWith(
        messages: [...page.messages, ...state.messages],
        hasMore: page.hasMore,
        loadingMore: false,
      );
    } on Object {
      // Silent: the list keeps what it has and the next scroll tries again.
      state = state.copyWith(loadingMore: false);
    }
  }

  /// Posts, showing the message immediately.
  ///
  /// The placeholder carries a local id and [Message.pending]; whichever
  /// arrives first — the POST's response or the broadcast — replaces it, and a
  /// failure turns it into a row that can be retried or dismissed rather than
  /// losing what was typed.
  Future<void> send({
    required String content,
    List<String> attachmentIds = const [],
    String? replyToId,
    MessageReplyPreview? replyTo,
  }) async {
    final author = switch (ref.read(authProvider)) {
      AuthAuthenticated(:final user) => user,
      _ => null,
    };
    if (author == null) return;

    final pending = Message(
      id: 'pending:${DateTime.now().microsecondsSinceEpoch}',
      pending: true,
      channelId: _channelId,
      author: author,
      content: content,
      createdAt: DateTime.now(),
      editedAt: null,
      replyTo: replyTo,
      // Attachments are already uploaded by the time this runs — the composer
      // holds them — but the placeholder does not have their metadata, so it
      // shows the text alone for the moment before the real message lands.
    );
    state = state.copyWith(messages: [...state.messages, pending]);

    try {
      final sent = await ref.read(apiProvider).sendMessage(
            _channelId,
            content,
            attachmentIds: attachmentIds,
            replyToId: replyToId,
          );
      _replacePending(pending.id, sent);
    } on Object {
      _markFailed(pending.id);
      rethrow;
    }
  }

  /// Sends a failed message again, in place.
  Future<void> retry(Message failed) async {
    state = state.copyWith(
      messages: state.messages.where((m) => m.id != failed.id).toList(),
    );
    await send(
      content: failed.content,
      replyToId: failed.replyTo?.id,
      replyTo: failed.replyTo,
    );
  }

  /// Drops a failed message. Nothing was ever posted, so this is local only.
  void discard(String messageId) {
    state = state.copyWith(
      messages: state.messages.where((m) => m.id != messageId).toList(),
    );
  }

  void _replacePending(String pendingId, Message sent) {
    if (state.messages.any((m) => m.id == sent.id)) {
      // The broadcast beat the response; just drop the placeholder.
      state = state.copyWith(
        messages: state.messages.where((m) => m.id != pendingId).toList(),
      );
      return;
    }
    state = state.copyWith(
      messages: [
        for (final message in state.messages) message.id == pendingId ? sent : message,
      ],
    );
  }

  void _markFailed(String pendingId) {
    state = state.copyWith(
      messages: [
        for (final message in state.messages)
          if (message.id == pendingId) message.copyWith(sendFailed: true) else message,
      ],
    );
  }

  /// Folds one reaction frame into the message it belongs to.
  ///
  /// [MessageReactionUpdateData.reacted] describes the user in the frame, so it
  /// only moves `reactedByMe` when that user is us; otherwise the local flag is
  /// left exactly as it was.
  void applyReaction(MessageReactionUpdateData update) {
    final currentUserId = switch (ref.read(authProvider)) {
      AuthAuthenticated(:final user) => user.id,
      _ => null,
    };

    state = state.copyWith(
      messages: [
        for (final message in state.messages)
          if (message.id != update.messageId)
            message
          else
            message.copyWith(
              reactions: [
                for (final reaction in message.reactions)
                  if (reaction.type != update.type) reaction,
                if (update.count > 0)
                  MessageReaction(
                    type: update.type,
                    count: update.count,
                    reactedByMe: update.userId == currentUserId
                        ? update.reacted
                        : message.reactions
                                .where((r) => r.type == update.type)
                                .firstOrNull
                                ?.reactedByMe ??
                            false,
                  ),
              ]..sort((a, b) => a.type.index.compareTo(b.type.index)),
            ),
      ],
    );
  }
}

/// One notifier per channel, kept alive so switching back and forth does not
/// refetch a history that is already in memory and current — the gateway keeps
/// it that way while the socket is up.
// Typed as a function of the channel id, the way `isOnlineProvider` is: the
// family class itself is not exported, and this is what the lint wants to see.
final NotifierProvider<MessagesNotifier, ChannelMessages> Function(String)
    messagesProvider =
    NotifierProvider.family<MessagesNotifier, ChannelMessages, String>(
  MessagesNotifier.new,
);
