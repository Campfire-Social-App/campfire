import 'dart:async';

import 'package:campfire/models/events.dart';
import 'package:campfire/models/user.dart';
import 'package:campfire/state/api.dart';
import 'package:campfire/state/gateway.dart';
import 'package:campfire/state/presence.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Everyone with an account on this server, for the member list and for
/// resolving a mention or an avatar to a person.
///
/// The one list the client *does* fetch over REST (`state/users.ts` does the
/// same): READY carries who is *online*, not who exists, so the roster's
/// offline half has no other source. PLANO_FLUTTER.md §6 rules out REST for
/// what READY already sends — this is not that.
class UsersNotifier extends AsyncNotifier<List<User>> {
  @override
  Future<List<User>> build() async {
    listenToGateway(ref, (event) {
      switch (event) {
        // Someone changed their profile — today that is the avatar, which the
        // roster, the message list and the rail all draw.
        case UserUpdateEvent(:final user):
          final known = state.value;
          if (known == null) return;
          state = AsyncData([
            for (final existing in known) existing.id == user.id ? user : existing,
          ]);

        // A user who registered while this client was open shows up on their
        // first presence frame; refetching then is cheaper than a poll.
        case PresenceUpdateEvent(:final data):
          final known = state.value;
          if (known != null && !known.any((User u) => u.id == data.userId)) {
            unawaited(refresh());
          }

        case _:
          break;
      }
    });

    return ref.read(apiProvider).listUsers();
  }

  /// Re-reads the roster. Errors keep the previous list on screen — a member
  /// list that empties itself because one request failed is worse than a stale
  /// one, and the next event tries again.
  Future<void> refresh() async {
    final users = await ref.read(apiProvider).listUsers();
    state = AsyncData(users);
  }
}

final usersProvider =
    AsyncNotifierProvider<UsersNotifier, List<User>>(UsersNotifier.new);

/// The roster split the member list draws, online first, each half sorted by
/// name — the same shape `MemberList.tsx` builds inline.
typedef MemberRoster = ({List<User> online, List<User> offline});

final memberRosterProvider = Provider<MemberRoster>((ref) {
  final users = ref.watch(usersProvider).value ?? const <User>[];
  final online = ref.watch(presenceProvider);

  final sorted = [...users]
    ..sort((a, b) => a.username.toLowerCase().compareTo(b.username.toLowerCase()));

  return (
    online: sorted.where((u) => online.contains(u.id)).toList(),
    offline: sorted.where((u) => !online.contains(u.id)).toList(),
  );
});

/// One user by id, for the places that hold an id and need a name and a face.
final Provider<User?> Function(String) userByIdProvider = Provider.family<User?, String>(
  (ref, userId) {
    final users = ref.watch(usersProvider).value ?? const <User>[];
    for (final user in users) {
      if (user.id == userId) return user;
    }
    return null;
  },
);
