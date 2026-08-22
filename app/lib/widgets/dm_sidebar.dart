import 'dart:async';

import 'package:campfire/models/dm.dart';
import 'package:campfire/state/dms.dart';
import 'package:campfire/state/presence.dart';
import 'package:campfire/state/voice.dart';
import 'package:campfire/theme/icons.dart';
import 'package:campfire/theme/night_sky.dart';
import 'package:campfire/theme/tokens.dart';
import 'package:campfire/widgets/channel_sidebar.dart';
import 'package:campfire/widgets/new_dm_sheet.dart';
import 'package:campfire/widgets/user_avatar.dart';
import 'package:campfire/widgets/user_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The conversation list, standing in for the channel column while a DM is
/// open — same column, same user bar at the foot. Port of
/// `DirectMessageSidebar.tsx` (task G1).
///
/// The phone reaches its conversations through the rail's avatars instead, so
/// this is the wide layout's second column; it takes [opaque] all the same, in
/// case a drawer ever wants it.
class DmSidebar extends ConsumerWidget {
  const DmSidebar({
    this.width = ChannelSidebar.defaultWidth,
    this.opaque = false,
    this.onSelect,
    super.key,
  });

  final double width;
  final bool opaque;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(dmsProvider);
    final activeId = ref.watch(activeDmIdProvider);
    final theme = Theme.of(context);

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: opaque ? overSky(CampfireTokens.sidebar) : CampfireTokens.sidebar,
        border: const Border(
          left: BorderSide(color: CampfireTokens.sidebarBorder),
          right: BorderSide(color: CampfireTokens.sidebarBorder),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: CampfireTokens.sidebarBorder)),
              ),
              child: SizedBox(
                height: 52,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Direct messages',
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontFamily: 'Fraunces',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(CampfireIcons.add, size: 18),
                        color: CampfireTokens.mutedForeground,
                        tooltip: 'New direct message',
                        onPressed: () => unawaited(showNewDmSheet(context)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: conversations.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No conversations yet. Tap a member to start one.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: CampfireTokens.mutedForeground,
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      children: [
                        for (final conversation in conversations)
                          _ConversationRow(
                            conversation: conversation,
                            active: activeId == conversation.id,
                            onTap: () {
                              ref.read(activeDmIdProvider.notifier).select(conversation.id);
                              onSelect?.call();
                            },
                          ),
                      ],
                    ),
            ),
            const UserBar(),
          ],
        ),
      ),
    );
  }
}

class _ConversationRow extends ConsumerWidget {
  const _ConversationRow({
    required this.conversation,
    required this.active,
    required this.onTap,
  });

  final DMConversation conversation;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final recipient = conversation.recipient;
    final online = ref.watch(isOnlineProvider(recipient.id));
    // Voice state for a DM only ever reaches its two members, so anyone in this
    // room means a call in this conversation.
    final inCall = ref.watch(voiceParticipantsProvider(conversation.id)).isNotEmpty;
    final unread = conversation.unreadCount;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: active ? CampfireTokens.emberTint.withValues(alpha: 0.5 * 0.35) : null,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: active
                    ? CampfireTokens.emberTintBorder.withValues(alpha: 0.75 * 0.4)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                UserAvatar(
                  username: recipient.username,
                  avatarUrl: recipient.avatarUrl,
                  size: AvatarSize.sm,
                  status: online ? PresenceDot.online : PresenceDot.offline,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    recipient.username,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 14,
                      color: active || unread > 0
                          ? CampfireTokens.foreground
                          : CampfireTokens.mutedForeground,
                      fontWeight: active || unread > 0 ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                if (inCall)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(CampfireIcons.callAnswer, size: 13, color: CampfireTokens.online),
                  ),
                if (unread > 0)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    constraints: const BoxConstraints(minWidth: 18),
                    decoration: BoxDecoration(
                      color: CampfireTokens.destructive,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      unread > 99 ? '99+' : '$unread',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  )
                else if (conversation.lastMessageAt case final DateTime at)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Text(
                      shortAge(at),
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 10,
                        color: CampfireTokens.mutedForeground,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// How long ago, in the width a sidebar row can spare: `now`, `5m`, `2h`, `3d`.
/// The web client leans on `date-fns` for the same thing, which spells the unit
/// out — there is no room for that next to a name and a badge.
String shortAge(DateTime at, {DateTime? now}) {
  final elapsed = (now ?? DateTime.now()).difference(at);
  if (elapsed.inMinutes < 1) return 'now';
  if (elapsed.inHours < 1) return '${elapsed.inMinutes}m';
  if (elapsed.inDays < 1) return '${elapsed.inHours}h';
  if (elapsed.inDays < 7) return '${elapsed.inDays}d';
  return '${elapsed.inDays ~/ 7}w';
}
