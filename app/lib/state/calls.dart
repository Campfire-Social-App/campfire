import 'dart:async';

import 'package:campfire/livekit/voice.dart';
import 'package:campfire/models/events.dart';
import 'package:campfire/state/api.dart';
import 'package:campfire/state/dms.dart';
import 'package:campfire/state/gateway.dart';
import 'package:campfire/state/voice.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Something the user has to be told about a call that is no longer on screen —
/// declined, unavailable, missed. Carries a [seq] because the same sentence can
/// legitimately happen twice, and it is the change the UI reacts to.
@immutable
class CallNotice {
  const CallNotice(this.message, this.seq);

  final String message;
  final int seq;

  @override
  bool operator ==(Object other) =>
      other is CallNotice && other.message == message && other.seq == seq;

  @override
  int get hashCode => Object.hash(message, seq);
}

@immutable
class CallsState {
  const CallsState({this.incoming, this.outgoing, this.notice});

  /// A call ringing at us right now — at most one, newest wins.
  final DMCallData? incoming;

  /// The DM channel we are ringing and waiting on an answer for.
  final String? outgoing;

  final CallNotice? notice;

  CallsState copyWith({
    DMCallData? incoming,
    bool clearIncoming = false,
    String? outgoing,
    bool clearOutgoing = false,
    CallNotice? notice,
  }) {
    return CallsState(
      incoming: clearIncoming ? null : (incoming ?? this.incoming),
      outgoing: clearOutgoing ? null : (outgoing ?? this.outgoing),
      notice: notice ?? this.notice,
    );
  }
}

/// The ring: who is calling, who we are calling, and the ways either of those
/// ends. Port of `state/calls.ts` together with the `DM_CALL` half of
/// `gateway.ts`, which in the web client lives in the socket itself.
///
/// Once a call is answered it stops being signalling and becomes a LiveKit
/// room, which is [VoiceSession]'s business — nothing here follows it there.
class CallsNotifier extends Notifier<CallsState> {
  var _seq = 0;

  @override
  CallsState build() {
    listenToGateway(ref, _apply);
    return const CallsState();
  }

  void _apply(GatewayEvent event) {
    if (event case DMCallEvent(:final data)) {
      switch (data.action) {
        case DMCallAction.ringing:
          state = state.copyWith(incoming: data);
        case DMCallAction.accepted:
          // They are joining the room we are already in — there is nothing to
          // do but stop waiting.
          clearOutgoing(data.channelId);
        case DMCallAction.declined:
        case DMCallAction.unavailable:
          clearOutgoing(data.channelId);
          unawaited(ref.read(voiceSessionProvider).leave());
          _notify(
            data.action == DMCallAction.declined
                ? '${data.from.username} declined the call.'
                : '${data.from.username} is unavailable.',
          );
        case DMCallAction.cancelled:
          clearIncoming(data.channelId);
          _notify('Missed call from ${data.from.username}.');
      }
    }
  }

  void _notify(String message) => state = state.copyWith(notice: CallNotice(message, ++_seq));

  /// Both clears take the channel they mean, so a late frame from a call that
  /// is already over cannot wipe the state of the one that replaced it.
  void clearIncoming(String channelId) {
    if (state.incoming?.channelId != channelId) return;
    state = state.copyWith(clearIncoming: true);
  }

  void clearOutgoing(String channelId) {
    if (state.outgoing != channelId) return;
    state = state.copyWith(clearOutgoing: true);
  }

  // ------------------------------------------------------------- the actions

  // Two independent things happen in each of these: the ring is signalled over
  // the gateway, so the other client lights up, and we join or leave the
  // LiveKit room the DM channel stands for. Port of `lib/calls.ts`.

  Future<void> start(String channelId, {bool video = false}) async {
    // Ring first: a 409 (they are already calling us) must not leave us sitting
    // in a room we then have to back out of.
    await ref.read(apiProvider).startDmCall(channelId);
    state = state.copyWith(outgoing: channelId);

    try {
      await ref.read(voiceSessionProvider).join(channelId, camera: video);
    } on Object {
      clearOutgoing(channelId);
      unawaited(ref.read(apiProvider).endDmCall(channelId).catchError((_) {}));
      rethrow;
    }
  }

  Future<void> accept(String channelId, {bool video = false}) async {
    clearIncoming(channelId);
    await ref.read(apiProvider).acceptDmCall(channelId);
    await ref.read(voiceSessionProvider).join(channelId, camera: video);
    // Answering should land you in the conversation — it may be one the callee
    // has never opened, which the ring itself put in their rail.
    ref.read(activeDmIdProvider.notifier).select(channelId);
  }

  Future<void> decline(String channelId) async {
    clearIncoming(channelId);
    await ref.read(apiProvider).endDmCall(channelId);
  }

  /// The one exit for "hang up", whether the call was answered or never got
  /// past ringing.
  Future<void> hangUp(String channelId) async {
    clearOutgoing(channelId);
    if (ref.read(voiceProvider).isConnectedTo(channelId)) {
      await ref.read(voiceSessionProvider).leave();
    }
    // Harmless once the call was answered — the server has no ring left to end.
    await ref.read(apiProvider).endDmCall(channelId).catchError((_) {});
  }
}

final callsProvider = NotifierProvider<CallsNotifier, CallsState>(CallsNotifier.new);
