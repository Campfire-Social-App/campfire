import 'package:campfire/models/channel.dart';
import 'package:campfire/state/auth.dart';
import 'package:campfire/state/channels.dart';
import 'package:campfire/state/gateway.dart';
import 'package:campfire/state/server.dart';
import 'package:campfire/theme/icons.dart';
import 'package:campfire/theme/night_sky.dart';
import 'package:campfire/theme/tokens.dart';
import 'package:campfire/ws/gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the app shows once there is a session.
///
/// Deliberately thin for now: everything on it comes from the READY frame, so
/// it is the proof that the gateway round trip works end to end. The four-column
/// adaptive layout (rail, channels, chat, members) is task I2, and the chat
/// pane itself is lane E.
class ShellScreen extends ConsumerWidget {
  const ShellScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Nothing else keeps the socket open — the lifecycle provider is kept alive
    // by this screen being mounted, and torn down when it is not.
    ref.watch(gatewayLifecycleProvider);

    final theme = Theme.of(context);
    final server = ref.watch(serverProvider);
    final channels = ref.watch(channelsProvider);
    final status = ref.watch(gatewayStatusProvider).value ?? GatewayStatus.connecting;
    final auth = ref.watch(authProvider);

    return NightSky(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          title: Text(server?.name ?? 'Campfire', style: theme.textTheme.titleLarge),
          actions: [
            _StatusDot(status),
            PopupMenuButton<void>(
              icon: const Icon(CampfireIcons.settings),
              itemBuilder: (context) => [
                PopupMenuItem(
                  onTap: () => ref.read(authProvider.notifier).logout(),
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: switch (status) {
            // Before READY lands there is genuinely nothing to draw — the client
            // does not fetch these lists over REST (PLANO_FLUTTER.md §6).
            GatewayStatus.connected when channels.isEmpty => const _Empty(
                icon: CampfireIcons.textChannel,
                message: 'No channels yet.',
              ),
            _ when channels.isEmpty => _Empty(
                icon: CampfireIcons.connection,
                message: status == GatewayStatus.connecting
                    ? 'Connecting…'
                    : 'Reconnecting…',
              ),
            _ => _ChannelList(channels: channels),
          },
        ),
        bottomNavigationBar: auth is AuthAuthenticated ? _UserBar(auth.user.username) : null,
      ),
    );
  }
}

class _ChannelList extends ConsumerWidget {
  const _ChannelList({required this.channels});

  final List<Channel> channels;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedChannelIdProvider);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: channels.length,
      itemBuilder: (context, index) {
        final channel = channels[index];
        final isSelected = channel.id == selected;

        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Material(
            color: isSelected ? CampfireTokens.emberTint : Colors.transparent,
            borderRadius: BorderRadius.circular(CampfireTokens.radius * 0.8),
            child: ListTile(
              dense: true,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(CampfireTokens.radius * 0.8),
                side: isSelected
                    ? const BorderSide(color: CampfireTokens.emberTintBorder)
                    : BorderSide.none,
              ),
              leading: Icon(
                channel.type == ChannelType.voice
                    ? CampfireIcons.voiceChannel
                    : CampfireIcons.textChannel,
                size: 18,
                color: isSelected ? CampfireTokens.ember : CampfireTokens.mutedForeground,
              ),
              title: Text(
                channel.name,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isSelected
                          ? CampfireTokens.foreground
                          : CampfireTokens.mutedForeground,
                    ),
              ),
              onTap: () =>
                  ref.read(selectedChannelIdProvider.notifier).selected = channel.id,
            ),
          ),
        );
      },
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot(this.status);

  final GatewayStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      GatewayStatus.connected => CampfireTokens.online,
      GatewayStatus.connecting => CampfireTokens.idle,
      GatewayStatus.disconnected => CampfireTokens.dnd,
    };

    return Tooltip(
      message: switch (status) {
        GatewayStatus.connected => 'Connected',
        GatewayStatus.connecting => 'Connecting',
        GatewayStatus.disconnected => 'Disconnected',
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

class _UserBar extends StatelessWidget {
  const _UserBar(this.username);

  final String username;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: CampfireTokens.glass,
          border: Border(top: BorderSide(color: CampfireTokens.glassBorder)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: CampfireTokens.primary,
              child: Text(
                username.characters.first.toUpperCase(),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: CampfireTokens.primaryForeground,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(username, style: theme.textTheme.titleSmall),
          ],
        ),
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
