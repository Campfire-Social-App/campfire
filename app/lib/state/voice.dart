import 'package:campfire/core/secure_store.dart';
import 'package:campfire/core/sounds.dart';
import 'package:campfire/models/events.dart';
import 'package:campfire/models/server.dart';
import 'package:campfire/state/auth.dart';
import 'package:campfire/state/gateway.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart' show VideoTrack;

enum VoiceConnectionStatus { disconnected, connecting, connected }

/// Everything the UI knows about voice: who is in which room, which room we are
/// in, and the state of our own microphone, camera and screen.
///
/// Port of `state/voice.ts`. The LiveKit room itself lives in
/// `livekit/voice.dart` — this half holds no session, so it can be driven from
/// a test without a media stack.
@immutable
class VoiceState {
  const VoiceState({
    this.participants = const [],
    this.connectedChannelId,
    this.status = VoiceConnectionStatus.disconnected,
    this.localMuted = false,
    this.localDeafened = false,
    this.localCameraEnabled = false,
    this.localScreenShareEnabled = false,
    this.speakingUserIds = const {},
    this.cameraTracks = const {},
    this.screenShareTracks = const {},
    this.microphoneVolumes = const {},
    this.screenShareVolumes = const {},
    this.screenShareAudioUserIds = const {},
    this.viewingScreenShares = const {},
  });

  /// Who the *server* says is in a voice channel, anywhere on the server —
  /// this is what draws the names under a channel you have not joined.
  final List<VoiceParticipantState> participants;

  /// The room we are connected to, or null. A DM call's room is the
  /// conversation, so this is a channel id either way.
  final String? connectedChannelId;
  final VoiceConnectionStatus status;

  final bool localMuted;
  final bool localDeafened;
  final bool localCameraEnabled;
  final bool localScreenShareEnabled;

  final Set<String> speakingUserIds;

  /// Camera and screen-share tracks of everyone in the room we are in, keyed by
  /// user id. Only ever populated while connected — a track cannot exist
  /// without a subscription.
  final Map<String, VideoTrack> cameraTracks;
  final Map<String, VideoTrack> screenShareTracks;

  /// Local listening preference, 0.0-1.0, keyed by remote user id. Absence
  /// means "never touched the slider", not muted — `livekit/voice.dart`
  /// applies 1.0 in that case. Never cleared on disconnect: it is a standing
  /// preference, not room state.
  final Map<String, double> microphoneVolumes;
  final Map<String, double> screenShareVolumes;

  /// Remote participants currently publishing a screen-share *audio* track —
  /// distinct from `screenShareTracks`, which is the picture. Room-scoped, so
  /// it resets like `speakingUserIds` on disconnect. Drives whether the
  /// second slider in the volume sheet has anything to control.
  final Set<String> screenShareAudioUserIds;

  /// Remote users whose screen share we have opted into subscribing to — the
  /// opt-in model from `state/voice.ts`'s `viewingScreenShares`. Room-scoped:
  /// resets like `speakingUserIds` on disconnect, since a subscription choice
  /// about one room means nothing in the next.
  final Set<String> viewingScreenShares;

  bool get isConnected => status == VoiceConnectionStatus.connected;

  /// Whether we are in [channelId]'s room right now.
  bool isConnectedTo(String channelId) => connectedChannelId == channelId;

  List<VoiceParticipantState> inChannel(String channelId) =>
      [for (final p in participants) if (p.channelId == channelId) p];

  VoiceState copyWith({
    List<VoiceParticipantState>? participants,
    String? connectedChannelId,
    bool clearConnectedChannel = false,
    VoiceConnectionStatus? status,
    bool? localMuted,
    bool? localDeafened,
    bool? localCameraEnabled,
    bool? localScreenShareEnabled,
    Set<String>? speakingUserIds,
    Map<String, VideoTrack>? cameraTracks,
    Map<String, VideoTrack>? screenShareTracks,
    Map<String, double>? microphoneVolumes,
    Map<String, double>? screenShareVolumes,
    Set<String>? screenShareAudioUserIds,
    Set<String>? viewingScreenShares,
  }) {
    return VoiceState(
      participants: participants ?? this.participants,
      connectedChannelId:
          clearConnectedChannel ? null : (connectedChannelId ?? this.connectedChannelId),
      status: status ?? this.status,
      localMuted: localMuted ?? this.localMuted,
      localDeafened: localDeafened ?? this.localDeafened,
      localCameraEnabled: localCameraEnabled ?? this.localCameraEnabled,
      localScreenShareEnabled: localScreenShareEnabled ?? this.localScreenShareEnabled,
      speakingUserIds: speakingUserIds ?? this.speakingUserIds,
      cameraTracks: cameraTracks ?? this.cameraTracks,
      screenShareTracks: screenShareTracks ?? this.screenShareTracks,
      microphoneVolumes: microphoneVolumes ?? this.microphoneVolumes,
      screenShareVolumes: screenShareVolumes ?? this.screenShareVolumes,
      screenShareAudioUserIds: screenShareAudioUserIds ?? this.screenShareAudioUserIds,
      viewingScreenShares: viewingScreenShares ?? this.viewingScreenShares,
    );
  }
}

class VoiceNotifier extends Notifier<VoiceState> {
  Future<void> _ready = Future<void>.value();

  /// Completes once the stored volume preferences have been read, whether or
  /// not there were any. `persistVolumes` awaits this so a write that lands
  /// before hydration finishes cannot be clobbered by it.
  Future<void> get ready => _ready;

  SessionStore get _store => ref.read(sessionStoreProvider);

  @override
  VoiceState build() {
    listenToGateway(ref, (event) {
      switch (event) {
        case ReadyEvent(:final data):
          state = state.copyWith(participants: data.voiceStates);
        case VoiceStateUpdateEvent(:final data):
          _applyVoiceStateUpdate(data);
        case _:
          break;
      }
    });
    _ready = _loadVolumes();
    return const VoiceState();
  }

  Future<void> _loadVolumes() async {
    try {
      final mic = await _store.readMicrophoneVolumes();
      final screen = await _store.readScreenShareVolumes();
      // Merge rather than overwrite: a slider touched in the gap between
      // `build()` returning and this future resolving must win over whatever
      // was on disk, or the hydration would stomp the user's own just-made
      // change.
      state = state.copyWith(
        microphoneVolumes: {...mic, ...state.microphoneVolumes},
        screenShareVolumes: {...screen, ...state.screenShareVolumes},
      );
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'campfire',
          context: ErrorDescription('reading stored participant volumes'),
        ),
      );
    }
  }

  void _applyVoiceStateUpdate(VoiceStateUpdateData data) {
    switch (data.action) {
      case VoiceStateAction.joined:
        final userId = data.userId;
        final channelId = data.channelId;
        if (userId == null || channelId == null) return;
        state = state.copyWith(
          participants: [
            for (final p in state.participants)
              if (p.userId != userId) p,
            VoiceParticipantState(
              userId: userId,
              username: data.username ?? userId,
              channelId: channelId,
              muted: data.muted ?? false,
              deafened: data.deafened ?? false,
              screenSharing: data.screenSharing ?? false,
            ),
          ],
        );
      case VoiceStateAction.updated:
        final userId = data.userId;
        if (userId == null) return;
        state = state.copyWith(
          participants: [
            for (final participant in state.participants)
              if (participant.userId == userId)
                participant.copyWith(
                  muted: data.muted ?? participant.muted,
                  deafened: data.deafened ?? participant.deafened,
                  screenSharing: data.screenSharing ?? participant.screenSharing,
                )
              else
                participant,
          ],
        );
      case VoiceStateAction.left:
        final userId = data.userId;
        if (userId == null) return;
        state = state.copyWith(
          participants: [
            for (final p in state.participants)
              if (p.userId != userId) p,
          ],
        );
      case VoiceStateAction.roomFinished:
        final channelId = data.channelId;
        if (channelId == null) return;
        state = state.copyWith(
          participants: [
            for (final p in state.participants)
              if (p.channelId != channelId) p,
          ],
        );
    }

    _soundOffForOthers(data);
  }

  /// Our own join and leave sounds come from the room's lifecycle (see
  /// `livekit/voice.dart`); here we only sound off for *other* people, and only
  /// in the room we are actually sitting in.
  void _soundOffForOthers(VoiceStateUpdateData data) {
    final me = switch (ref.read(authProvider)) {
      AuthAuthenticated(:final user) => user.id,
      _ => null,
    };
    if (data.userId == me) return;
    if (data.channelId == null || data.channelId != state.connectedChannelId) return;

    final sounds = ref.read(soundsProvider);
    switch (data.action) {
      case VoiceStateAction.joined:
        sounds.join();
      case VoiceStateAction.left:
        sounds.leave();
      case VoiceStateAction.updated:
        break;
      case VoiceStateAction.roomFinished:
        break;
    }
  }

  // ------------------------------------------------- driven by the room

  void setConnection(String? channelId, VoiceConnectionStatus status) {
    final disconnected = status == VoiceConnectionStatus.disconnected;
    state = state.copyWith(
      connectedChannelId: disconnected ? null : channelId,
      clearConnectedChannel: disconnected,
      status: status,
      // Nothing about a room we are no longer in is still true.
      speakingUserIds: disconnected ? const {} : null,
      cameraTracks: disconnected ? const {} : null,
      screenShareTracks: disconnected ? const {} : null,
      screenShareAudioUserIds: disconnected ? const {} : null,
      viewingScreenShares: disconnected ? const {} : null,
      localCameraEnabled: disconnected ? false : null,
      localScreenShareEnabled: disconnected ? false : null,
    );
  }

  void setLocalMuted({required bool muted}) => state = state.copyWith(localMuted: muted);

  void setLocalDeafened({required bool deafened}) =>
      state = state.copyWith(localDeafened: deafened);

  void setLocalCameraEnabled({required bool enabled}) =>
      state = state.copyWith(localCameraEnabled: enabled);

  void setLocalScreenShareEnabled({required bool enabled}) =>
      state = state.copyWith(localScreenShareEnabled: enabled);

  void setParticipantMuted(String userId, {required bool muted}) {
    state = state.copyWith(
      participants: [
        for (final p in state.participants) p.userId == userId ? p.copyWith(muted: muted) : p,
      ],
    );
  }

  void setParticipantDeafened(String userId, {required bool deafened}) {
    state = state.copyWith(
      participants: [
        for (final p in state.participants)
          p.userId == userId ? p.copyWith(deafened: deafened) : p,
      ],
    );
  }

  void setSpeaking(Iterable<String> userIds) =>
      state = state.copyWith(speakingUserIds: userIds.toSet());

  void setCameraTrack(String userId, VideoTrack? track) => state = state.copyWith(
        cameraTracks: _withTrack(state.cameraTracks, userId, track),
      );

  void setScreenShareTrack(String userId, VideoTrack? track) => state = state.copyWith(
        screenShareTracks: _withTrack(state.screenShareTracks, userId, track),
      );

  Map<String, VideoTrack> _withTrack(
    Map<String, VideoTrack> tracks,
    String userId,
    VideoTrack? track,
  ) {
    final next = {...tracks};
    if (track == null) {
      next.remove(userId);
    } else {
      next[userId] = track;
    }
    return next;
  }

  void setMicrophoneVolume(String userId, double volume) => state = state.copyWith(
        microphoneVolumes: {...state.microphoneVolumes, userId: volume},
      );

  void setScreenShareVolume(String userId, double volume) => state = state.copyWith(
        screenShareVolumes: {...state.screenShareVolumes, userId: volume},
      );

  void setScreenShareAudioActive(String userId, {required bool active}) {
    final next = {...state.screenShareAudioUserIds};
    active ? next.add(userId) : next.remove(userId);
    state = state.copyWith(screenShareAudioUserIds: next);
  }

  void setScreenShareViewing(String userId, {required bool viewing}) {
    final next = {...state.viewingScreenShares};
    viewing ? next.add(userId) : next.remove(userId);
    state = state.copyWith(viewingScreenShares: next);
  }

  /// Called from `VoiceSession.persistParticipantVolumes`, on a slider's
  /// `onChangeEnd` — not on every drag tick.
  Future<void> persistVolumes() async {
    await _ready;
    await _store.writeMicrophoneVolumes(state.microphoneVolumes);
    await _store.writeScreenShareVolumes(state.screenShareVolumes);
  }
}

final voiceProvider = NotifierProvider<VoiceNotifier, VoiceState>(VoiceNotifier.new);

/// Who is in one channel's room, for the sidebar rows and the tiles.
final Provider<List<VoiceParticipantState>> Function(String) voiceParticipantsProvider =
    Provider.family<List<VoiceParticipantState>, String>(
  (ref, channelId) => ref.watch(voiceProvider).inChannel(channelId),
);
