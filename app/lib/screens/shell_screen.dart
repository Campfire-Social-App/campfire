import 'package:campfire/models/channel.dart';
import 'package:campfire/models/dm.dart';
import 'package:campfire/screens/dm_view.dart';
import 'package:campfire/screens/text_channel_view.dart';
import 'package:campfire/screens/voice_channel_view.dart';
import 'package:campfire/state/calls.dart';
import 'package:campfire/state/channels.dart';
import 'package:campfire/state/dms.dart';
import 'package:campfire/state/gateway.dart';
import 'package:campfire/state/presence.dart';
import 'package:campfire/state/server.dart';
import 'package:campfire/state/voice.dart';
import 'package:campfire/theme/icons.dart';
import 'package:campfire/theme/night_sky.dart';
import 'package:campfire/theme/tokens.dart';
import 'package:campfire/widgets/call_center.dart';
import 'package:campfire/widgets/channel_sidebar.dart';
import 'package:campfire/widgets/dm_call_buttons.dart';
import 'package:campfire/widgets/dm_sidebar.dart';
import 'package:campfire/widgets/member_list.dart';
import 'package:campfire/widgets/server_rail.dart';
import 'package:campfire/widgets/user_avatar.dart';
import 'package:campfire/ws/gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// What the app shows once there is a session (task I2).
///
/// One tree, two shapes, chosen by width:
///
/// * **Phone** — Discord's arrangement: the rail and the channel list ride in
///   the left drawer, the member roster in the right one, and the open channel
///   owns the whole screen with its name in the app bar. Both drawers are
///   edge-swipeable, which is how that layout is actually navigated.
/// * **Tablet and desktop** — the web client's four columns, side by side, with
///   no drawers and no app bar.
///
/// Everything inside is the same widget in both cases; only the frame changes.
/// [NightSky] stays at the root either way, so the ember glow carries across
/// every column instead of stopping at a pane's edge.
class ShellScreen extends ConsumerWidget {
  const ShellScreen({super.key});

  /// Below this, one pane at a time. Roughly a large phone in landscape or a
  /// small tablet in portrait — the point where four columns stop fitting.
  static const double wideBreakpoint = 900;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Every provider READY seeds has to be alive *before* READY arrives. The
    // gateway's event stream is a broadcast: a notifier that is first watched
    // deeper in the tree — presence from the app bar, the DM list from inside
    // the drawer — is built after the frame has already gone by, and sits empty
    // until something else happens to update it. Watching them here, above the
    // early return, is what the React client gets for free from its stores
    // being module-level singletons.
    final channels = ref.watch(channelsProvider);
    ref
      ..watch(presenceProvider)
      ..watch(dmsProvider)
      // READY carries the voice states too, and a ring can arrive before
      // anything voice-related is on screen — both have to be listening first.
      ..watch(voiceProvider)
      ..watch(callsProvider)
      // Nothing else keeps the socket open — the lifecycle provider is kept
      // alive by this screen being mounted, and torn down when it is not. Last,
      // so the listeners above are subscribed before it can connect.
      ..watch(gatewayLifecycleProvider);

    final status = ref.watch(gatewayStatusProvider).value ?? GatewayStatus.connecting;

    // Before READY lands there is genuinely nothing to draw — the client does
    // not fetch these lists over REST (PLANO_FLUTTER.md §6).
    if (channels.isEmpty && status != GatewayStatus.connected) {
      return NightSky(child: _Connecting(status: status));
    }

    final wide = MediaQuery.sizeOf(context).width >= wideBreakpoint;
    // The ring and the incoming-call card sit above whichever shape is on
    // screen: a call can arrive while you are anywhere in the app.
    return CallCenter(
      child: NightSky(child: wide ? const _WideShell() : const _PhoneShell()),
    );
  }
}

/// Phone: drawers on both edges, one pane on screen.
class _PhoneShell extends ConsumerWidget {
  const _PhoneShell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scaffoldKey = GlobalKey<ScaffoldState>();
    final serverName = ref.watch(serverProvider)?.name ?? 'Campfire';
    final width = MediaQuery.sizeOf(context).width;

    // Leaving a sliver of the pane visible is what makes the drawer read as
    // sitting on top of the conversation rather than replacing it.
    final drawerWidth = (width * 0.86).clamp(240.0, ServerRail.width + ChannelSidebar.defaultWidth);

    return Scaffold(
      key: scaffoldKey,
      backgroundColor: Colors.transparent,
      // The whole left edge opens the channel list, as on Discord — the default
      // 20dp strip is a hard target on a tall phone.
      drawerEdgeDragWidth: width * 0.5,
      drawerScrimColor: Colors.black.withValues(alpha: 0.5),
      appBar: _ChannelAppBar(
        onOpenChannels: () => scaffoldKey.currentState?.openDrawer(),
        onOpenMembers: () => scaffoldKey.currentState?.openEndDrawer(),
      ),
      drawer: Drawer(
        width: drawerWidth,
        backgroundColor: Colors.transparent,
        shape: const RoundedRectangleBorder(),
        child: Row(
          children: [
            ServerRail(
              serverName: serverName,
              opaque: true,
              onSelect: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: ChannelSidebar(
                serverName: serverName,
                width: drawerWidth - ServerRail.width,
                opaque: true,
                onSelect: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
      endDrawer: Drawer(
        width: (width * 0.78).clamp(240.0, MemberList.defaultWidth),
        backgroundColor: Colors.transparent,
        shape: const RoundedRectangleBorder(),
        child: MemberList(
          width: (width * 0.78).clamp(240.0, MemberList.defaultWidth),
          opaque: true,
          onOpenDm: () => Navigator.of(context).pop(),
        ),
      ),
      body: const _Pane(),
    );
  }
}

/// Tablet and desktop: the web client's four columns.
class _WideShell extends ConsumerWidget {
  const _WideShell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverName = ref.watch(serverProvider)?.name ?? 'Campfire';
    final inDm = ref.watch(activeDmProvider) != null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Row(
        children: [
          ServerRail(serverName: serverName),
          // A conversation takes the second column too, the way it does in the
          // web client — the channel list has nothing to say about a DM.
          if (inDm) const DmSidebar() else ChannelSidebar(serverName: serverName),
          const Expanded(
            child: Column(
              children: [
                _WideHeader(),
                Expanded(child: _Pane()),
              ],
            ),
          ),
          // A 1:1 has no roster, so the column gives way — same as the web
          // client, where the DM view takes over the two right-hand panes.
          if (!inDm) const MemberList(),
        ],
      ),
    );
  }
}

/// The phone's app bar: which channel you are in, who is around, and the two
/// doors out to the drawers.
class _ChannelAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const _ChannelAppBar({required this.onOpenChannels, required this.onOpenMembers});

  final VoidCallback onOpenChannels;
  final VoidCallback onOpenMembers;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dm = ref.watch(activeDmProvider);
    final channel = ref.watch(_openChannelProvider);
    final onlineCount = ref.watch(presenceProvider).length;

    return AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      leadingWidth: 44,
      leading: IconButton(
        icon: const Icon(LucideIcons.arrowLeft, size: 20),
        color: CampfireTokens.foreground,
        tooltip: 'Channels',
        onPressed: onOpenChannels,
      ),
      titleSpacing: 0,
      title: switch ((dm, channel)) {
        (final DMConversation conversation, _) => _DmTitle(conversation: conversation),
        (_, final Channel open) => _ChannelTitle(channel: open, onlineCount: onlineCount),
        _ => Text('Campfire', style: theme.textTheme.titleMedium),
      },
      actions: [
        if (dm != null) DmCallButtons(conversation: dm),
        // A 1:1 has no roster to show.
        if (dm == null)
          IconButton(
            icon: const Icon(LucideIcons.users, size: 20),
            color: CampfireTokens.mutedForeground,
            tooltip: 'Members',
            onPressed: onOpenMembers,
          ),
        const SizedBox(width: 4),
      ],
    );
  }
}

class _ChannelTitle extends StatelessWidget {
  const _ChannelTitle({required this.channel, required this.onlineCount});

  final Channel channel;
  final int onlineCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Icon(
              channel.type == ChannelType.text
                  ? CampfireIcons.textChannel
                  : CampfireIcons.voiceChannel,
              size: 16,
              color: CampfireTokens.mutedForeground,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                channel.name,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontFamily: 'Fraunces',
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: CampfireTokens.online,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              '$onlineCount online',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: CampfireTokens.mutedForeground,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DmTitle extends ConsumerWidget {
  const _DmTitle({required this.conversation});

  final DMConversation conversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final online = ref.watch(isOnlineProvider(conversation.recipient.id));

    return Row(
      children: [
        UserAvatar(
          username: conversation.recipient.username,
          avatarUrl: conversation.recipient.avatarUrl,
          size: AvatarSize.sm,
          status: online ? PresenceDot.online : PresenceDot.offline,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            conversation.recipient.username,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(fontSize: 16),
          ),
        ),
      ],
    );
  }
}

/// The wide layout's header, over the chat column only — the drawers' buttons
/// have nothing to open there, so it is just the name.
class _WideHeader extends ConsumerWidget {
  const _WideHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dm = ref.watch(activeDmProvider);
    final channel = ref.watch(_openChannelProvider);

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: CampfireTokens.border)),
      ),
      child: Row(
        children: [
          if (dm != null) ...[
            _DmTitle(conversation: dm),
            const Spacer(),
            DmCallButtons(conversation: dm),
          ] else if (channel != null) ...[
            Icon(
              channel.type == ChannelType.text
                  ? CampfireIcons.textChannel
                  : CampfireIcons.voiceChannel,
              size: 18,
              color: CampfireTokens.mutedForeground,
            ),
            const SizedBox(width: 6),
            Text(
              channel.name,
              style: theme.textTheme.titleSmall?.copyWith(
                fontFamily: 'Fraunces',
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Whatever the shell is showing: a conversation wins over a channel, the same
/// precedence `ServerShell.tsx` gives it.
class _Pane extends ConsumerWidget {
  const _Pane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dm = ref.watch(activeDmProvider);
    if (dm != null) return DmView(conversation: dm);

    final channel = ref.watch(_openChannelProvider);
    if (channel == null) {
      return const _Empty(
        icon: CampfireIcons.textChannel,
        message: 'No channel yet.',
      );
    }

    return switch (channel.type) {
      ChannelType.voice => VoiceChannelView(channel: channel),
      // A `dm` channel never reaches here through the sidebar — it is a
      // conversation, and the DM branch above catches it — but it is still a
      // room with messages in it, so it reads like any other text channel.
      ChannelType.text || ChannelType.dm => TextChannelView(channel: channel),
    };
  }
}

/// The selected channel, resolved. Null while a DM is open or before READY.
final _openChannelProvider = Provider<Channel?>((ref) {
  final id = ref.watch(selectedChannelIdProvider);
  if (id == null) return null;
  for (final channel in ref.watch(channelsProvider)) {
    if (channel.id == id) return channel;
  }
  return null;
});

class _Connecting extends StatelessWidget {
  const _Connecting({required this.status});

  final GatewayStatus status;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _Empty(
        icon: CampfireIcons.connection,
        message: status == GatewayStatus.connecting ? 'Connecting…' : 'Reconnecting…',
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: CampfireTokens.mutedForeground),
          const SizedBox(height: 12),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: CampfireTokens.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}
