import 'package:campfire/models/dm.dart';
import 'package:campfire/state/dms.dart';
import 'package:campfire/state/presence.dart';
import 'package:campfire/theme/icons.dart';
import 'package:campfire/theme/night_sky.dart';
import 'package:campfire/theme/tokens.dart';
import 'package:campfire/widgets/user_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Leftmost column of the drawer: the one server this client talks to, then the
/// open direct messages below it — the same shape as Discord's rail, minus the
/// multi-server part (Campfire is single-server by design), and a straight port
/// of `ServerRail.tsx`.
class ServerRail extends ConsumerWidget {
  const ServerRail({
    required this.serverName,
    this.opaque = false,
    this.onSelect,
    super.key,
  });

  final String serverName;

  /// True in the drawer, where there is a chat pane behind this instead of the
  /// night sky. See [overSky].
  final bool opaque;

  /// Lets the mobile shell close the drawer on a pick; on tablet the rail is
  /// always visible and there is nothing to close.
  final VoidCallback? onSelect;

  static const double width = 72;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(dmsProvider);
    final activeDmId = ref.watch(activeDmIdProvider);

    void select(String? id) {
      ref.read(activeDmIdProvider.notifier).select(id);
      onSelect?.call();
    }

    return Container(
      width: width,
      color: opaque ? overSky(CampfireTokens.rail) : CampfireTokens.rail,
      child: SafeArea(
        right: false,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            _RailItem(
              active: activeDmId == null,
              onTap: () => select(null),
              child: const _ServerButton(),
            ),
            const _RailDivider(),
            for (final conversation in conversations)
              _RailItem(
                active: activeDmId == conversation.id,
                onTap: () => select(conversation.id),
                child: _DmAvatar(
                  conversation: conversation,
                  active: activeDmId == conversation.id,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The squircle with the flame: "the place", as opposed to the round avatars
/// below it, which are people.
class _ServerButton extends StatelessWidget {
  const _ServerButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFBBF24), CampfireTokens.primary, Color(0xFFDC2626)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF7A3D).withValues(alpha: 0.35),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: const Icon(CampfireIcons.brand, size: 24, color: Colors.white),
    );
  }
}

class _DmAvatar extends ConsumerWidget {
  const _DmAvatar({required this.conversation, required this.active});

  final DMConversation conversation;
  final bool active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(isOnlineProvider(conversation.recipient.id));
    final unread = conversation.unreadCount;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: active
                ? Border.all(color: CampfireTokens.primary.withValues(alpha: 0.7), width: 2)
                : null,
          ),
          child: UserAvatar(
            username: conversation.recipient.username,
            avatarUrl: conversation.recipient.avatarUrl,
            size: AvatarSize.lg,
            status: online ? PresenceDot.online : PresenceDot.offline,
          ),
        ),
        if (unread > 0)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              constraints: const BoxConstraints(minWidth: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: CampfireTokens.destructive,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: CampfireTokens.background, width: 2),
              ),
              child: Text(
                unread > 99 ? '99+' : '$unread',
                style: const TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Rail button with the selected-state pill on the left edge.
class _RailItem extends StatelessWidget {
  const _RailItem({required this.active, required this.onTap, required this.child});

  final bool active;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          AnimatedOpacity(
            opacity: active ? 1 : 0,
            duration: const Duration(milliseconds: 150),
            child: Container(
              width: 4,
              height: 20,
              decoration: const BoxDecoration(
                color: CampfireTokens.foreground,
                borderRadius: BorderRadius.horizontal(right: Radius.circular(4)),
              ),
            ),
          ),
          Center(
            child: GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _RailDivider extends StatelessWidget {
  const _RailDivider();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        width: 32,
        height: 1,
        decoration: BoxDecoration(
          color: CampfireTokens.sidebarBorder,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}
