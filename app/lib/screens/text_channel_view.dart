import 'package:campfire/models/channel.dart';
import 'package:campfire/theme/icons.dart';
import 'package:campfire/theme/tokens.dart';
import 'package:campfire/widgets/chat_pane.dart';
import 'package:flutter/material.dart';

/// A text channel's pane. The header lives in the shell's app bar on the phone,
/// so what is left here is the conversation itself — which is [ChatPane], the
/// same widget a DM uses.
class TextChannelView extends StatelessWidget {
  const TextChannelView({required this.channel, super.key});

  final Channel channel;

  @override
  Widget build(BuildContext context) {
    return ChatPane(
      // Keyed by channel so switching rebuilds the pane rather than reusing the
      // previous channel's scroll position and reply target.
      key: ValueKey(channel.id),
      channelId: channel.id,
      composerPlaceholder: 'Message #${channel.name}',
      emptyState: _Empty(channel: channel),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.channel});

  final Channel channel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              CampfireIcons.textChannel,
              size: 36,
              color: CampfireTokens.mutedForeground,
            ),
            const SizedBox(height: 8),
            Text(
              'Welcome to #${channel.name}!',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'This is the beginning of the channel.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: CampfireTokens.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
