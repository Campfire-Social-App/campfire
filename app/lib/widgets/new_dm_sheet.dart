import 'package:campfire/api/api_exception.dart';
import 'package:campfire/models/user.dart';
import 'package:campfire/state/auth.dart';
import 'package:campfire/state/dms.dart';
import 'package:campfire/state/presence.dart';
import 'package:campfire/state/users.dart';
import 'package:campfire/theme/icons.dart';
import 'package:campfire/theme/tokens.dart';
import 'package:campfire/widgets/user_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Start a conversation with someone by name. The mobile shape of
/// `NewDirectMessageDialog.tsx` — the roster is also reachable by tapping a
/// member, so this is the shortcut for a server with more members than fit on a
/// screen.
Future<void> showNewDmSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: CampfireTokens.popover,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _NewDmSheet(),
  );
}

class _NewDmSheet extends ConsumerStatefulWidget {
  const _NewDmSheet();

  @override
  ConsumerState<_NewDmSheet> createState() => _NewDmSheetState();
}

class _NewDmSheetState extends ConsumerState<_NewDmSheet> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _open(String userId) async {
    try {
      await ref.read(activeDmIdProvider.notifier).openWithUser(userId);
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final me = switch (ref.watch(authProvider)) {
      AuthAuthenticated(:final user) => user.id,
      _ => null,
    };
    final query = _query.text.trim().toLowerCase();
    final matches = [
      for (final user in ref.watch(usersProvider).value ?? const <User>[])
        if (user.id != me && user.username.toLowerCase().contains(query)) user,
    ];

    return Padding(
      // Above the keyboard, which is up the moment this opens.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text('New direct message', style: theme.textTheme.titleMedium),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _query,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Find a member',
                  prefixIcon: Icon(CampfireIcons.search, size: 18),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: matches.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No members match that.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: CampfireTokens.mutedForeground,
                        ),
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        for (final user in matches)
                          ListTile(
                            leading: UserAvatar(
                              username: user.username,
                              avatarUrl: user.avatarUrl,
                              size: AvatarSize.sm,
                              status: ref.watch(isOnlineProvider(user.id))
                                  ? PresenceDot.online
                                  : PresenceDot.offline,
                            ),
                            title: Text(
                              user.username,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: usernameColorFor(user.username),
                              ),
                            ),
                            onTap: () => _open(user.id),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
