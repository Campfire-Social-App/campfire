import 'dart:async';

import 'package:campfire/models/dm.dart';
import 'package:campfire/models/events.dart';
import 'package:campfire/state/api.dart';
import 'package:campfire/state/gateway.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The 1:1 conversations this user has open, newest first. Port of
/// `state/dms.ts`: seeded by READY, kept current by `DM_UPDATE`.
class DmsNotifier extends Notifier<List<DMConversation>> {
  @override
  List<DMConversation> build() {
    listenToGateway(ref, (event) {
      switch (event) {
        case ReadyEvent(:final data):
          state = _sorted(data.dms);
        case DMUpdateEvent(:final conversation):
          upsert(conversation);
        case _:
          break;
      }
    });
    return const [];
  }

  /// Most recent first; a conversation with no messages yet stays pinned at the
  /// top, matching how the server orders the initial list.
  List<DMConversation> _sorted(List<DMConversation> conversations) {
    return [...conversations]..sort((a, b) {
        final (x, y) = (a.lastMessageAt, b.lastMessageAt);
        if (x == null && y == null) return 0;
        if (x == null) return -1;
        if (y == null) return 1;
        return y.compareTo(x);
      });
    }

  void upsert(DMConversation conversation) {
    // While a conversation is on screen its messages are read by definition —
    // don't let the server's unread count (computed before we saw it) put a
    // badge on the DM the user is literally looking at.
    final active = ref.read(activeDmIdProvider);
    final next = conversation.id == active
        ? conversation.copyWith(unreadCount: 0)
        : conversation;

    if (next.unreadCount == 0 && conversation.unreadCount > 0) {
      // Read receipts are best-effort; a failed one just re-badges on reload.
      unawaited(ref.read(apiProvider).markDmRead(next.id).catchError((_) {}));
    }

    final without = state.where((c) => c.id != next.id);
    state = _sorted([...without, next]);
  }

  /// Clears the badge locally the moment the conversation is opened, so the
  /// count does not survive until the server's next frame.
  void markRead(String id) {
    state = [
      for (final c in state) c.id == id ? c.copyWith(unreadCount: 0) : c,
    ];
  }
}

final dmsProvider =
    NotifierProvider<DmsNotifier, List<DMConversation>>(DmsNotifier.new);

/// Non-null means the DM view is showing instead of the server's channels.
class ActiveDmNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) {
    state = id;
    if (id == null) return;

    ref.read(dmsProvider.notifier).markRead(id);
    unawaited(ref.read(apiProvider).markDmRead(id).catchError((_) {}));
  }

  /// Opens (creating if needed) the conversation with a member, and shows it.
  /// The server's get-or-create is what keeps a second tap from making a second
  /// conversation.
  Future<void> openWithUser(String userId) async {
    final conversation = await ref.read(apiProvider).openDmWith(userId);
    ref.read(dmsProvider.notifier).upsert(conversation);
    select(conversation.id);
  }
}

final activeDmIdProvider =
    NotifierProvider<ActiveDmNotifier, String?>(ActiveDmNotifier.new);

/// The open conversation, or null when the server's channels are on screen.
final activeDmProvider = Provider<DMConversation?>((ref) {
  final id = ref.watch(activeDmIdProvider);
  if (id == null) return null;
  for (final conversation in ref.watch(dmsProvider)) {
    if (conversation.id == id) return conversation;
  }
  return null;
});
