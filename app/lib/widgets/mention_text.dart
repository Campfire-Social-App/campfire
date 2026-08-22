import 'package:campfire/core/mentions.dart';
import 'package:campfire/state/channels.dart';
import 'package:campfire/state/dms.dart';
import 'package:campfire/state/users.dart';
import 'package:campfire/theme/tokens.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Message text with `@name` and `#channel` picked out. Port of `MentionText`
/// in `MessageItem.tsx`.
///
/// A mention of *you* — or `@everyone` — gets the full ember tint; everyone
/// else's gets a fraction of it. A channel mention is tappable and opens that
/// channel, which is why this is stateful: the tap recognisers it builds have
/// to be disposed with the widget.
class MentionText extends ConsumerStatefulWidget {
  const MentionText({
    required this.content,
    required this.style,
    this.currentUsername,
    super.key,
  });

  final String content;
  final TextStyle style;
  final String? currentUsername;

  @override
  ConsumerState<MentionText> createState() => _MentionTextState();
}

class _MentionTextState extends ConsumerState<MentionText> {
  final _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  void _openChannel(String channelId) {
    ref.read(selectedChannelIdProvider.notifier).selected = channelId;
    // A channel and a conversation cannot both be open.
    ref.read(activeDmIdProvider.notifier).select(null);
  }

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(usersProvider).value ?? const [];
    final channels = ref.watch(channelsProvider);

    final knownUsernames = {for (final user in users) user.username.toLowerCase()};
    final channelsByName = {for (final channel in channels) channel.name.toLowerCase(): channel};

    final segments = splitMentions(widget.content, knownUsernames, channelsByName);

    // Rebuilt from scratch each time, so the recognisers from the previous
    // build are dropped with it rather than piling up.
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();

    return Text.rich(
      TextSpan(
        children: [
          for (final segment in segments)
            switch (segment.mention) {
              null => TextSpan(text: segment.text),
              MentionKind.channel => _channelSpan(segment),
              _ => _userSpan(segment),
            },
        ],
      ),
      style: widget.style,
    );
  }

  TextSpan _userSpan(MentionSegment segment) {
    final isSelf = segment.mention == MentionKind.everyone ||
        segment.text.substring(1).toLowerCase() == widget.currentUsername?.toLowerCase();

    return TextSpan(
      text: segment.text,
      style: TextStyle(
        color: isSelf ? CampfireTokens.foreground : CampfireTokens.primary,
        fontWeight: FontWeight.w500,
        backgroundColor: isSelf ? CampfireTokens.emberTint : _softTint,
      ),
    );
  }

  TextSpan _channelSpan(MentionSegment segment) {
    final channelId = segment.channelId;
    final recognizer = TapGestureRecognizer()
      ..onTap = channelId == null ? null : () => _openChannel(channelId);
    _recognizers.add(recognizer);

    return TextSpan(
      text: segment.text,
      style: const TextStyle(
        color: CampfireTokens.primary,
        fontWeight: FontWeight.w500,
        backgroundColor: _softTint,
      ),
      recognizer: recognizer,
    );
  }
}

/// `bg-ember-tint/40` — the tint someone else's mention gets.
const _softTint = Color(0x24B94A00);
