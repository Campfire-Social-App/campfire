import 'dart:async';

import 'package:campfire/models/message.dart';
import 'package:campfire/state/messages.dart';
import 'package:campfire/theme/tokens.dart';
import 'package:campfire/widgets/date_separator.dart';
import 'package:campfire/widgets/message_composer.dart';
import 'package:campfire/widgets/message_item.dart';
import 'package:campfire/widgets/typing_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Two messages from the same author closer together than this are drawn as one
/// run. Same window as `ChatPane.tsx`.
const _groupingWindow = Duration(minutes: 5);

/// How close to the top the list has to get before the next page is asked for.
const _loadMoreThreshold = 300.0;

/// The conversation surface: history, pagination, reply state and the composer.
/// Text channels and DMs differ only in their header and empty state, so both
/// drive this — the same split `ChatPane.tsx` makes.
class ChatPane extends ConsumerStatefulWidget {
  const ChatPane({
    required this.channelId,
    required this.emptyState,
    required this.composerPlaceholder,
    this.banner,
    super.key,
  });

  /// Channel id to read and post in — a text channel or a DM conversation.
  final String channelId;

  /// Shown in place of the message list before anything has been said.
  final Widget emptyState;

  final String composerPlaceholder;

  /// Sits between the header and the history, pushing neither aside — where the
  /// DM view puts a call in progress, so a call never takes the chat away.
  final Widget? banner;

  @override
  ConsumerState<ChatPane> createState() => _ChatPaneState();
}

class _ChatPaneState extends ConsumerState<ChatPane> {
  final _scroll = ScrollController();
  Message? _replyingTo;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(ChatPane old) {
    super.didUpdateWidget(old);
    // A different conversation is a different reply target.
    if (old.channelId != widget.channelId) setState(() => _replyingTo = null);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    // The list is reversed, so "near the top of the history" is near the *end*
    // of the scroll extent.
    final distanceToOldest = _scroll.position.maxScrollExtent - _scroll.position.pixels;
    if (distanceToOldest < _loadMoreThreshold) {
      unawaited(ref.read(messagesProvider(widget.channelId).notifier).loadMore());
    }
  }

  @override
  Widget build(BuildContext context) {
    final channel = ref.watch(messagesProvider(widget.channelId));
    final messages = channel.messages;

    return Column(
      children: [
        ?widget.banner,
        Expanded(
          child: switch (channel) {
            ChannelMessages(error: final String message) when messages.isEmpty =>
              _LoadFailed(
                message: message,
                onRetry: () =>
                    unawaited(ref.read(messagesProvider(widget.channelId).notifier).load()),
              ),
            ChannelMessages(loading: true) when messages.isEmpty => const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: CampfireTokens.ember,
                  ),
                ),
              ),
            _ when messages.isEmpty => widget.emptyState,
            _ => _history(messages, loadingMore: channel.loadingMore),
          },
        ),
        TypingIndicator(channelId: widget.channelId),
        MessageComposer(
          channelId: widget.channelId,
          placeholder: widget.composerPlaceholder,
          replyingTo: _replyingTo,
          onCancelReply: () => setState(() => _replyingTo = null),
          onSent: () {
            // Sending is a deliberate act — come back to the newest message even
            // if the view had been scrolled up to find something to reply to.
            if (_scroll.hasClients) {
              unawaited(
                _scroll.animateTo(
                  0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                ),
              );
            }
          },
        ),
      ],
    );
  }

  /// A reversed list: index 0 is the newest message, at the bottom.
  ///
  /// This is what keeps the view pinned to the newest message for free, and what
  /// makes prepending a page of history invisible — in a normal list both would
  /// need the scroll offset corrected by hand every frame, which is exactly the
  /// dance `useLayoutEffect` does in the web client.
  Widget _history(List<Message> messages, {required bool loadingMore}) {
    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: messages.length + (loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= messages.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: CampfireTokens.ember,
                ),
              ),
            ),
          );
        }

        final position = messages.length - 1 - index;
        final message = messages[position];
        final previous = position > 0 ? messages[position - 1] : null;

        final isNewDay = previous == null ||
            !isSameDay(previous.createdAt.toLocal(), message.createdAt.toLocal());
        final showHeader = previous == null ||
            previous.author.id != message.author.id ||
            isNewDay ||
            message.createdAt.difference(previous.createdAt) > _groupingWindow ||
            // A reply always gets its own header — the quoted line needs an
            // avatar to anchor to, even mid-run from the same author.
            message.replyTo != null;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isNewDay) DateSeparator(date: message.createdAt.toLocal()),
            MessageItem(
              key: ValueKey(message.id),
              message: message,
              showHeader: showHeader,
              onReply: (target) => setState(() => _replyingTo = target),
            ),
          ],
        );
      },
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Could not load this conversation.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: CampfireTokens.mutedForeground,
                  ),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
