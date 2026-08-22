import 'package:campfire/models/dm.dart';
import 'package:campfire/theme/tokens.dart';
import 'package:campfire/widgets/chat_pane.dart';
import 'package:campfire/widgets/direct_call_panel.dart';
import 'package:campfire/widgets/user_avatar.dart';
import 'package:flutter/material.dart';

/// A 1:1 conversation. The same [ChatPane] a text channel uses — the DM's id
/// *is* a channel id on the server, so nothing below this line knows the
/// difference — with the recipient in place of the channel name.
class DmView extends StatelessWidget {
  const DmView({required this.conversation, super.key});

  final DMConversation conversation;

  @override
  Widget build(BuildContext context) {
    return ChatPane(
      key: ValueKey(conversation.id),
      channelId: conversation.id,
      composerPlaceholder: 'Message ${conversation.recipient.username}',
      // Between the header and the history: a call in this conversation shows
      // above the messages instead of replacing them.
      banner: DirectCallPanel(conversation: conversation),
      emptyState: _Empty(conversation: conversation),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.conversation});

  final DMConversation conversation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recipient = conversation.recipient;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            UserAvatar(
              username: recipient.username,
              avatarUrl: recipient.avatarUrl,
              size: AvatarSize.lg,
            ),
            const SizedBox(height: 12),
            Text(
              recipient.username,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'This is the beginning of your conversation.',
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
