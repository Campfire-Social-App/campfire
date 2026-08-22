import 'package:campfire/models/events.dart';
import 'package:campfire/models/user.dart';
import 'package:campfire/state/auth.dart';
import 'package:campfire/state/gateway.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Who is online right now. READY seeds the set; `PRESENCE_UPDATE` moves people
/// in and out of it one at a time.
class PresenceNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    listenToGateway(ref, (event) {
      switch (event) {
        case ReadyEvent(:final data):
          state = data.onlineUserIds.toSet();
        case PresenceUpdateEvent(:final data):
          state = data.status == PresenceStatus.online
              ? {...state, data.userId}
              : ({...state}..remove(data.userId));
        case _:
          break;
      }
    });
    return const {};
  }
}

final presenceProvider =
    NotifierProvider<PresenceNotifier, Set<String>>(PresenceNotifier.new);

final Provider<bool> Function(String) isOnlineProvider = Provider.family<bool, String>(
  (ref, userId) => ref.watch(presenceProvider).contains(userId),
);

/// How long a `TYPING_START` keeps someone in the indicator. The server does not
/// send a "stopped", so the client expires it — same TTL as `presence.ts`.
const typingTtl = Duration(seconds: 8);

/// Who is typing in each channel, and until when.
///
/// Entries are dropped lazily, when someone asks: a timer per typist would be a
/// timer per keystroke, and nothing else in the app needs to know the moment an
/// indicator goes stale.
class TypingNotifier extends Notifier<Map<String, Map<String, DateTime>>> {
  @override
  Map<String, Map<String, DateTime>> build() {
    listenToGateway(ref, (event) {
      if (event case TypingStartEvent(:final data)) {
        final until = DateTime.now().add(typingTtl);
        state = {
          ...state,
          data.channelId: {...?state[data.channelId], data.userId: until},
        };
      }
    });
    return const {};
  }

  /// Drops whoever has gone quiet in [channelId]. Returns nothing — the state
  /// change is the point — and does not touch other channels.
  void prune(String channelId) {
    final typists = state[channelId];
    if (typists == null || typists.isEmpty) return;

    final now = DateTime.now();
    final live = {
      for (final entry in typists.entries)
        if (entry.value.isAfter(now)) entry.key: entry.value,
    };
    if (live.length == typists.length) return;

    state = {...state, channelId: live};
  }
}

final typingProvider =
    NotifierProvider<TypingNotifier, Map<String, Map<String, DateTime>>>(
  TypingNotifier.new,
);

/// The user ids typing in one channel right now, excluding whoever is asking —
/// you are never told that you are typing.
final Provider<List<String>> Function(String) typingInChannelProvider =
    Provider.family<List<String>, String>((ref, channelId) {
  final typists = ref.watch(typingProvider)[channelId];
  if (typists == null || typists.isEmpty) return const [];

  final me = switch (ref.watch(authProvider)) {
    AuthAuthenticated(:final user) => user.id,
    _ => null,
  };
  final now = DateTime.now();
  return [
    for (final entry in typists.entries)
      if (entry.key != me && entry.value.isAfter(now)) entry.key,
  ];
});
