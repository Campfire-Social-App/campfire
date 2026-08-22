import 'dart:async';

import 'package:campfire/livekit/voice.dart';
import 'package:campfire/models/dm.dart';
import 'package:campfire/state/auth.dart';
import 'package:campfire/state/calls.dart';
import 'package:campfire/state/channels.dart';
import 'package:campfire/state/dms.dart';
import 'package:campfire/state/settings.dart';
import 'package:campfire/state/voice.dart';
import 'package:campfire/theme/icons.dart';
import 'package:campfire/theme/tokens.dart';
import 'package:campfire/widgets/user_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Who you are signed in as, at the foot of the channel column — the same slot
/// `UserBar.tsx` occupies, and the same border-only card as the composer so the
/// two floating panels read as one system.
///
/// While a voice session is up the card grows a strip above the identity row:
/// where the call is, the way out of it, and the microphone and audio toggles,
/// reachable from wherever in the app you happen to be.
class UserBar extends ConsumerWidget {
  const UserBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    if (auth is! AuthAuthenticated) return const SizedBox.shrink();

    final user = auth.user;
    final theme = Theme.of(context);
    final voice = ref.watch(voiceProvider);
    final inVoice = voice.status != VoiceConnectionStatus.disconnected;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: CampfireTokens.glassBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (inVoice) const _VoiceStrip(),
            Container(
              height: 58,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: inVoice ? CampfireTokens.glassBorder : Colors.transparent,
                  ),
                ),
              ),
              child: Row(
                children: [
                  UserAvatar(
                    username: user.username,
                    avatarUrl: user.avatarUrl,
                    status: PresenceDot.online,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          user.username,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                        Text(
                          user.isAdmin ? 'Admin' : 'Member',
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            color: CampfireTokens.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (inVoice) ...[
                    _Toggle(
                      icon: voice.localMuted ? CampfireIcons.micOff : CampfireIcons.micOn,
                      tooltip: voice.localMuted ? 'Unmute microphone' : 'Mute microphone',
                      active: voice.localMuted,
                      onTap: () => ref
                          .read(voiceSessionProvider)
                          .setMicrophoneMuted(muted: !voice.localMuted),
                    ),
                    _Toggle(
                      icon: voice.localDeafened
                          ? CampfireIcons.volumeMuted
                          : CampfireIcons.deafenOff,
                      tooltip: voice.localDeafened ? 'Undeafen' : 'Deafen',
                      active: voice.localDeafened,
                      onTap: () => ref
                          .read(voiceSessionProvider)
                          .setDeafened(deafened: !voice.localDeafened),
                    ),
                  ],
                  IconButton(
                    icon: const Icon(CampfireIcons.settings, size: 18),
                    color: CampfireTokens.mutedForeground,
                    tooltip: 'Settings',
                    onPressed: () => _showSettings(context, ref),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Leaving before signing out lets the SFU see a clean disconnect instead of
  /// waiting out the participant timeout — and a ring we started has to be
  /// called off, or the other phone keeps ringing at an account that is gone.
  Future<void> _leaveAnyCall(WidgetRef ref) async {
    final channelId = ref.read(voiceProvider).connectedChannelId;
    if (channelId == null) return;

    final isDm = ref.read(dmsProvider).any((c) => c.id == channelId);
    if (isDm) {
      await ref.read(callsProvider.notifier).hangUp(channelId);
    } else {
      await ref.read(voiceSessionProvider).leave();
    }
  }

  void _showSettings(BuildContext context, WidgetRef ref) {
    unawaited(showModalBottomSheet<void>(
      context: context,
      backgroundColor: CampfireTokens.popover,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.repeat, size: 18),
              title: const Text('Switch server'),
              subtitle: const Text('Sign out and pick a different Campfire'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                await _leaveAnyCall(ref);
                await ref.read(authProvider.notifier).logout();
                await ref.read(settingsProvider.notifier).clearServerUrl();
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.logOut, size: 18),
              title: const Text('Sign out'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                await _leaveAnyCall(ref);
                await ref.read(authProvider.notifier).logout();
              },
            ),
          ],
        ),
      ),
    ));
  }
}

/// Where the voice session is and how to get out of it — the strip the web
/// client shows above the identity row while connected.
class _VoiceStrip extends ConsumerWidget {
  const _VoiceStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final voice = ref.watch(voiceProvider);
    final channelId = voice.connectedChannelId;
    if (channelId == null) return const SizedBox.shrink();

    // A DM call's room is the conversation, which has no channel name — label
    // it with whoever is on the other end instead.
    final conversation =
        ref.watch(dmsProvider).where((c) => c.id == channelId).firstOrNull;
    final channelName =
        ref.watch(channelsProvider).where((c) => c.id == channelId).firstOrNull?.name;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(CampfireIcons.connection, size: 13, color: CampfireTokens.online),
                    const SizedBox(width: 6),
                    Text(
                      switch ((voice.status, conversation)) {
                        (VoiceConnectionStatus.connecting, _) => 'Connecting…',
                        (_, final DMConversation _) => 'In call',
                        _ => 'Voice connected',
                      },
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 13,
                        color: CampfireTokens.online,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Text(
                  channelName ?? conversation?.recipient.username ?? '',
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: CampfireTokens.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(CampfireIcons.callEnd, size: 17),
            color: CampfireTokens.mutedForeground,
            tooltip: 'Disconnect',
            // Hanging up a 1:1 has to end the ring as well, which leaving the
            // room alone would not do.
            onPressed: () => unawaited(
              conversation != null
                  ? ref.read(callsProvider.notifier).hangUp(channelId)
                  : ref.read(voiceSessionProvider).leave(),
            ),
          ),
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool active;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 18),
      color: active ? CampfireTokens.destructive : CampfireTokens.mutedForeground,
      tooltip: tooltip,
      onPressed: () => unawaited(onTap()),
    );
  }
}
