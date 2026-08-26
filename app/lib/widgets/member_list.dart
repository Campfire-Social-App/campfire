import 'package:campfire/api/api_exception.dart';
import 'package:campfire/models/user.dart';
import 'package:campfire/state/auth.dart';
import 'package:campfire/state/dms.dart';
import 'package:campfire/state/users.dart';
import 'package:campfire/theme/night_sky.dart';
import 'package:campfire/theme/tokens.dart';
import 'package:campfire/widgets/bot_badge.dart';
import 'package:campfire/widgets/user_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Everyone on the server, online first. Port of `MemberList.tsx`.
///
/// On the phone this is the right drawer — Discord puts the roster behind the
/// same left-swipe — and tapping a member opens the DM with them, which is also
/// what the web client's row does.
class MemberList extends ConsumerWidget {
  const MemberList({
    this.width = defaultWidth,
    this.opaque = false,
    this.onOpenDm,
    super.key,
  });

  /// What the column measures — the drawer sizes itself to the screen, the
  /// wide layout takes the default.
  final double width;

  /// True in the drawer, where there is a chat pane behind this instead of the
  /// night sky. See [overSky].
  final bool opaque;

  /// Closes the drawer once a conversation is on screen.
  final VoidCallback? onOpenDm;

  static const double defaultWidth = 256;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roster = ref.watch(memberRosterProvider);
    final users = ref.watch(usersProvider);

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: opaque ? overSky(CampfireTokens.sidebar) : CampfireTokens.sidebar,
        border: const Border(left: BorderSide(color: CampfireTokens.sidebarBorder)),
      ),
      child: SafeArea(
        child: switch (users) {
          AsyncError(:final error) => _Failed(
              message: error is ApiException ? error.message : 'Could not load the members.',
              onRetry: () => ref.read(usersProvider.notifier).refresh(),
            ),
          AsyncLoading() when roster.online.isEmpty && roster.offline.isEmpty => const Center(
              child: CircularProgressIndicator(strokeWidth: 2, color: CampfireTokens.ember),
            ),
          _ => ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              children: [
                _Group(
                  title: 'Online — ${roster.online.length}',
                  users: roster.online,
                  online: true,
                  onOpenDm: onOpenDm,
                ),
                _Group(
                  title: 'Offline — ${roster.offline.length}',
                  users: roster.offline,
                  online: false,
                  onOpenDm: onOpenDm,
                ),
              ],
            ),
        },
      ),
    );
  }
}

class _Group extends ConsumerWidget {
  const _Group({
    required this.title,
    required this.users,
    required this.online,
    this.onOpenDm,
  });

  final String title;
  final List<User> users;
  final bool online;
  final VoidCallback? onOpenDm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (users.isEmpty) return const SizedBox.shrink();

    final currentUserId = switch (ref.watch(authProvider)) {
      AuthAuthenticated(:final user) => user.id,
      _ => null,
    };

    Future<void> startDm(User user) async {
      // Tapping yourself is a no-op rather than an error — the server rejects
      // it. A bot has nobody on the other end to read a DM, so it is the same.
      if (user.id == currentUserId || user.isBot) return;
      try {
        await ref.read(activeDmIdProvider.notifier).openWithUser(user.id);
        onOpenDm?.call();
      } on ApiException catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
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
          const SizedBox(height: 4),
          for (final user in users)
            Opacity(
              opacity: online ? 1 : 0.5,
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: () => startDm(user),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    child: Row(
                      children: [
                        UserAvatar(
                          username: user.username,
                          avatarUrl: user.avatarUrl,
                          size: AvatarSize.sm,
                          status: online ? PresenceDot.online : PresenceDot.offline,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            user.username,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontSize: 14,
                                  color: CampfireTokens.foreground,
                                ),
                          ),
                        ),
                        if (user.isBot) const BotBadge(),
                        if (user.isAdmin)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: CampfireTokens.emberTint,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'admin',
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    fontSize: 10,
                                    color: CampfireTokens.ember,
                                  ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: CampfireTokens.mutedForeground,
                  ),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
