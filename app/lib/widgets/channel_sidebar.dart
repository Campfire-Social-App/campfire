import 'dart:async';

import 'package:campfire/livekit/voice.dart';
import 'package:campfire/models/channel.dart';
import 'package:campfire/state/auth.dart';
import 'package:campfire/state/channels.dart';
import 'package:campfire/state/dms.dart';
import 'package:campfire/state/presence.dart';
import 'package:campfire/state/users.dart';
import 'package:campfire/state/voice.dart';
import 'package:campfire/theme/icons.dart';
import 'package:campfire/theme/night_sky.dart';
import 'package:campfire/theme/tokens.dart';
import 'package:campfire/widgets/bot_badge.dart';
import 'package:campfire/widgets/create_channel_sheet.dart';
import 'package:campfire/widgets/invite_sheet.dart';
import 'package:campfire/widgets/server_rail.dart';
import 'package:campfire/widgets/user_avatar.dart';
import 'package:campfire/widgets/user_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The channel column: server header, the text and voice lists, and the user
/// bar pinned to the bottom. Port of `ChannelSidebar.tsx`.
///
/// On the phone this is the body of the left drawer, next to [ServerRail]; on a
/// tablet it is the second of four columns. Either way it is the same widget —
/// only who wraps it changes.
class ChannelSidebar extends ConsumerWidget {
  const ChannelSidebar({
    required this.serverName,
    this.width = defaultWidth,
    this.opaque = false,
    this.onSelect,
    super.key,
  });

  final String serverName;

  /// What the column measures. The drawer hands it the leftovers after the
  /// rail; the wide layout takes the default.
  final double width;

  /// True in the drawer, where there is a chat pane behind this instead of the
  /// night sky. See [overSky].
  final bool opaque;

  /// Closes the drawer after a pick on the phone. Null on wide layouts.
  final VoidCallback? onSelect;

  static const double defaultWidth = 272;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channels = ref.watch(channelsProvider);
    final selectedId = ref.watch(selectedChannelIdProvider);
    final activeDmId = ref.watch(activeDmIdProvider);
    final isAdmin = switch (ref.watch(authProvider)) {
      AuthAuthenticated(:final user) => user.isAdmin,
      _ => false,
    };

    final text = channels.where((c) => c.type == ChannelType.text).toList();
    final voice = channels.where((c) => c.type == ChannelType.voice).toList();

    void select(Channel channel) {
      ref.read(selectedChannelIdProvider.notifier).selected = channel.id;
      // Picking a channel is also how you leave a DM — same as the web client,
      // where the DM view takes over the two right-hand panes.
      ref.read(activeDmIdProvider.notifier).select(null);
      onSelect?.call();
    }

    // A voice row both opens the room and joins it. The desktop client makes
    // that two clicks — join here, then open the screen — which is a reasonable
    // trade when the room is a column you can see anyway; on a phone the room
    // *is* the screen, so a tap that joined without showing anything would look
    // like nothing happened.
    Future<void> selectVoice(Channel channel) async {
      select(channel);
      if (ref.read(voiceProvider).isConnectedTo(channel.id)) return;
      try {
        await ref.read(voiceSessionProvider).join(channel.id);
      } on Object {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn’t join the voice channel.')),
        );
      }
    }

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
            _ServerHeader(serverName: serverName, isAdmin: isAdmin),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                children: [
                  _Category(
                    title: 'Text channels',
                    onCreate: isAdmin ? () => unawaited(showCreateChannelSheet(context)) : null,
                    children: [
                      for (final channel in text)
                        _ChannelRow(
                          channel: channel,
                          active: activeDmId == null && selectedId == channel.id,
                          onTap: () => select(channel),
                        ),
                    ],
                  ),
                  _Category(
                    title: 'Voice channels',
                    onCreate: isAdmin ? () => unawaited(showCreateChannelSheet(context)) : null,
                    children: [
                      for (final channel in voice) ...[
                        _ChannelRow(
                          channel: channel,
                          active: activeDmId == null && selectedId == channel.id,
                          onTap: () => unawaited(selectVoice(channel)),
                        ),
                        _VoiceParticipants(channelId: channel.id),
                      ],
                    ],
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

/// Server name plus the menu behind it — invite, and channel creation for
/// admins. The chevron is the affordance the web client uses for the same menu.
class _ServerHeader extends StatelessWidget {
  const _ServerHeader({required this.serverName, required this.isAdmin});

  final String serverName;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: CampfireTokens.sidebarBorder)),
      ),
      child: InkWell(
        onTap: () => _showMenu(context),
        child: SizedBox(
          height: 52,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    serverName,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontFamily: 'Fraunces',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(
                  CampfireIcons.chevronDown,
                  size: 16,
                  color: CampfireTokens.mutedForeground,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMenu(BuildContext context) {
    unawaited(showModalBottomSheet<void>(
      context: context,
      backgroundColor: CampfireTokens.popover,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(CampfireIcons.invite, size: 18),
              title: const Text('Invite people'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                unawaited(showInviteSheet(context));
              },
            ),
            if (isAdmin)
              ListTile(
                leading: const Icon(CampfireIcons.add, size: 18),
                title: const Text('Create channel'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(showCreateChannelSheet(context));
                },
              ),
          ],
        ),
      ),
    ));
  }
}

class _Category extends StatelessWidget {
  const _Category({required this.title, required this.children, this.onCreate});

  final String title;
  final List<Widget> children;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: CampfireTokens.mutedForeground,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.6,
                          fontSize: 11,
                        ),
                  ),
                ),
                if (onCreate != null)
                  GestureDetector(
                    onTap: onCreate,
                    child: const Icon(
                      CampfireIcons.add,
                      size: 16,
                      color: CampfireTokens.mutedForeground,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          ...children,
        ],
      ),
    );
  }
}

class _ChannelRow extends StatelessWidget {
  const _ChannelRow({required this.channel, required this.active, required this.onTap});

  final Channel channel;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = channel.type == ChannelType.text
        ? CampfireIcons.textChannel
        : CampfireIcons.voiceChannel;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              // Half-strength ember tint — enough to read as selected without
              // competing with the chat pane.
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
                Icon(
                  icon,
                  size: 16,
                  color: active ? CampfireTokens.primary : CampfireTokens.mutedForeground,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    channel.name,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 14,
                          color: active
                              ? CampfireTokens.foreground
                              : CampfireTokens.mutedForeground,
                          fontWeight: active ? FontWeight.w600 : FontWeight.w400,
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

/// Who is sitting in a voice channel, listed under its row — the one place the
/// server's voice state is visible without opening the room.
class _VoiceParticipants extends ConsumerWidget {
  const _VoiceParticipants({required this.channelId});

  final String channelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final participants = ref.watch(voiceParticipantsProvider(channelId));
    if (participants.isEmpty) return const SizedBox.shrink();

    final speaking = ref.watch(voiceProvider).speakingUserIds;

    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 4),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: CampfireTokens.sidebarBorder)),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Column(
            children: [
              for (final participant in participants)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      UserAvatar(
                        username: participant.username,
                        avatarUrl: ref.watch(userByIdProvider(participant.userId))?.avatarUrl,
                        size: AvatarSize.sm,
                        status: ref.watch(isOnlineProvider(participant.userId))
                            ? PresenceDot.online
                            : PresenceDot.offline,
                        speaking: speaking.contains(participant.userId),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          participant.username,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontSize: 13,
                                color: CampfireTokens.mutedForeground,
                              ),
                        ),
                      ),
                      if (ref.watch(userByIdProvider(participant.userId))?.isBot ?? false)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: BotBadge(),
                        ),
                      if (participant.muted)
                        const Icon(
                          CampfireIcons.micOff,
                          size: 13,
                          color: CampfireTokens.destructive,
                        ),
                      if (participant.deafened)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(
                            CampfireIcons.volumeMuted,
                            size: 13,
                            color: CampfireTokens.destructive,
                          ),
                        ),
                      if (participant.screenSharing)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF87171),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 3),
                              const Text(
                                'LIVE',
                                style: TextStyle(
                                  color: Color(0xFFF87171),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
