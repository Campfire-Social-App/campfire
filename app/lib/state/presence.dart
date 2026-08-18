import 'package:campfire/models/events.dart';
import 'package:campfire/models/user.dart';
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
