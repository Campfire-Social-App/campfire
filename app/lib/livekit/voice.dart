import 'dart:async';

import 'package:campfire/core/call_service.dart';
import 'package:campfire/core/sounds.dart';
import 'package:campfire/state/api.dart';
import 'package:campfire/state/dms.dart';
import 'package:campfire/state/settings.dart';
import 'package:campfire/state/voice.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';

/// The LiveKit half of voice: one room at a time, its events folded into
/// [voiceProvider]. Port of `livekit/voice.ts`.
///
/// The web client keeps its room in a module-level variable; here it is a
/// provider, which is the same single instance with a lifetime attached to it.
/// Everything below the API is the same session the web client runs — same SFU,
/// same token from `/api/voice/{id}/token`, same room id (the channel's).
class VoiceSession {
  VoiceSession(this._ref);

  final Ref _ref;

  Room? _room;
  EventsListener<RoomEvent>? _listener;

  /// Whether deafening, rather than the microphone button, caused the current
  /// mute. Only an automatic mute may be automatically undone.
  bool _microphoneMutedByDeafen = false;

  VoiceNotifier get _voice => _ref.read(voiceProvider.notifier);
  Sounds get _sounds => _ref.read(soundsProvider);

  AudioCaptureOptions get _microphoneCaptureOptions {
    final enabled = _ref.read(settingsProvider).noiseSuppressionEnabled;
    return AudioCaptureOptions(
      noiseSuppression: enabled,
      echoCancellation: true,
      autoGainControl: true,
      highPassFilter: enabled,
      voiceIsolation: enabled,
      typingNoiseDetection: enabled,
    );
  }

  /// Joins [channelId]'s room, publishing the camera straight away when
  /// [camera] — which is how a video call starts as one rather than as an audio
  /// call somebody then turns the camera on in.
  Future<void> join(String channelId, {bool camera = false}) async {
    await leave();

    _voice.setConnection(channelId, VoiceConnectionStatus.connecting);
    final credentials = await _ref.read(apiProvider).voiceToken(channelId);

    final room = Room(
      // Both off by default in the SDK, and both matter on a phone: adaptive
      // stream drops the resolution of tiles that are small or off screen, and
      // dynacast stops publishing layers nobody has subscribed to.
      roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true),
    );
    _room = room;
    _listen(room);

    try {
      await room.connect(credentials.url, credentials.token);
      await _publishInitialState(room, camera: camera);
      // After the microphone is published, not before: Android only lets the
      // service declare the microphone type once `RECORD_AUDIO` is granted, and
      // the thing that asks for it is the capture itself. Starting it first
      // crashed the process on the very first call of a fresh install.
      await startCallService();
      _voice.setConnection(channelId, VoiceConnectionStatus.connected);
      _sounds.join();
      if (camera) await _enableCameraAfterJoin(room);
    } on Object catch (error) {
      // The UI turns any failure here into one sentence, which is right for a
      // person and useless for finding out *why* — a refused microphone, an
      // expired token and an unreachable SFU all read the same. The cause goes
      // to the log so `flutter logs` still has it.
      debugPrint('voice: join failed — $error');
      await stopCallService();
      _voice.setConnection(null, VoiceConnectionStatus.disconnected);
      _room = null;
      await _listener?.dispose();
      _listener = null;
      // The signal connection may have succeeded even though a later setup step
      // (microphone access, say) failed — disconnect it explicitly so it does
      // not linger as an orphaned session that gets kicked on the next attempt.
      unawaited(room.disconnect());
      rethrow;
    }
  }

  Future<void> _publishInitialState(Room room, {required bool camera}) async {
    var muted = _ref.read(voiceProvider).localMuted;
    if (!muted && !await _enableMicrophone(room)) {
      // Refused, or no microphone at all. Joining to listen beats not joining,
      // and the button already says which state you are in.
      muted = true;
      _voice.setLocalMuted(muted: true);
    }
    _voice.setParticipantMuted(room.localParticipant!.identity, muted: muted);

    final deafened = _ref.read(voiceProvider).localDeafened;
    // Presence decoration must never make an otherwise healthy join fail — for
    // instance against an older server token minted without the metadata grant.
    await room.localParticipant?.setAttributes({'deafened': '$deafened'}).catchError((_) {});
    _voice.setParticipantDeafened(room.localParticipant!.identity, deafened: deafened);

    for (final participant in room.remoteParticipants.values) {
      _voice.setParticipantDeafened(
        participant.identity,
        deafened: participant.attributes['deafened'] == 'true',
      );
    }
    if (deafened) await _applyDeafenToRemoteAudio(room, deafened: true);
  }

  /// Starts capturing, and says whether it worked. The first call of a fresh
  /// install is where Android asks for `RECORD_AUDIO`, so this is also the
  /// point where a refusal has to be survivable.
  Future<bool> _enableMicrophone(Room room) async {
    try {
      await room.localParticipant?.setMicrophoneEnabled(
        true,
        audioCaptureOptions: _microphoneCaptureOptions,
      );
      return true;
    } on Object catch (error) {
      debugPrint('voice: microphone unavailable — $error');
      return false;
    }
  }

  /// Updates WebRTC's native audio-processing module in place when possible.
  /// A joined-muted call has no local track, so its next unmute simply picks up
  /// the setting through [_microphoneCaptureOptions].
  Future<void> applyNoiseSuppression({required bool enabled}) async {
    final publication = _room?.localParticipant
        ?.getTrackPublicationBySource(TrackSource.microphone);
    if (publication?.track case final LocalAudioTrack track) {
      await track.setAudioProcessingOptions(AudioProcessingOptions(
        echoCancellation: true,
        noiseSuppression: enabled,
        autoGainControl: true,
        highPassFilter: enabled,
      ));
    }
  }

  /// After the join is committed: a camera that will not start (no device,
  /// permission refused) must not take the call down with it — it lands as an
  /// audio call instead.
  Future<void> _enableCameraAfterJoin(Room room) async {
    try {
      await room.localParticipant?.setCameraEnabled(true);
      _voice.setLocalCameraEnabled(enabled: true);
    } on Object {
      _voice.setLocalCameraEnabled(enabled: false);
    }
  }

  void _listen(Room room) {
    final listener = room.createListener();
    _listener = listener;

    listener
      ..on<ActiveSpeakersChangedEvent>(
        (event) => _voice.setSpeaking(event.speakers.map((p) => p.identity)),
      )
      ..on<ParticipantAttributesChanged>((event) {
        final deafened = event.attributes['deafened'];
        if (deafened == null) return;
        _voice.setParticipantDeafened(event.participant.identity, deafened: deafened == 'true');
      })
      ..on<TrackSubscribedEvent>((event) {
        if (event.track is VideoTrack) {
          if (!event.publication.muted) {
            _setVideoTrack(event.participant.identity, event.publication.source,
                event.track as VideoTrack);
          }
          return;
        }
        if (event.publication.source == TrackSource.microphone) {
          _voice.setParticipantMuted(event.participant.identity,
              muted: event.publication.muted);
        }
        // Audio needs no attaching here the way it does in a browser: the SDK
        // plays a subscribed remote track itself. Deafening is the one case
        // that has to reach in, and it does so by disabling the subscription.
        if (_ref.read(voiceProvider).localDeafened) {
          unawaited(event.publication.disable());
        }
      })
      ..on<TrackUnsubscribedEvent>((event) {
        if (event.track is VideoTrack) {
          _setVideoTrack(event.participant.identity, event.publication.source, null);
        }
      })
      ..on<LocalTrackPublishedEvent>((event) {
        if (event.publication.track case final VideoTrack track) {
          _setVideoTrack(event.participant.identity, event.publication.source, track);
        }
      })
      ..on<LocalTrackUnpublishedEvent>((event) {
        if (event.publication.track is! VideoTrack) return;
        _setVideoTrack(event.participant.identity, event.publication.source, null);
        // Catches a screen share stopped from the system's own "stop sharing"
        // notification, which never goes through our button.
        if (event.publication.source == TrackSource.screenShareVideo) {
          _voice.setLocalScreenShareEnabled(enabled: false);
          unawaited(startCallService());
        } else if (event.publication.source == TrackSource.camera) {
          _voice.setLocalCameraEnabled(enabled: false);
        }
      })
      // LiveKit mutes camera and microphone tracks in place rather than
      // unpublishing them once they have been published, so tile visibility has
      // to react to mute as well as to publish.
      ..on<TrackMutedEvent>((event) {
        if (event.publication.source == TrackSource.microphone) {
          _voice.setParticipantMuted(event.participant.identity, muted: true);
        } else if (event.publication.kind == TrackType.VIDEO) {
          _setVideoTrack(event.participant.identity, event.publication.source, null);
        }
      })
      ..on<TrackUnmutedEvent>((event) {
        if (event.publication.source == TrackSource.microphone) {
          _voice.setParticipantMuted(event.participant.identity, muted: false);
        } else if (event.publication.track case final VideoTrack track) {
          _setVideoTrack(event.participant.identity, event.publication.source, track);
        }
      })
      ..on<ParticipantDisconnectedEvent>((event) {
        // A 1:1 call is over the moment the other person leaves — unlike a
        // voice channel, where sitting in an empty room waiting for someone is
        // a normal thing to do.
        final channelId = _ref.read(voiceProvider).connectedChannelId;
        final isDm = _ref.read(dmsProvider).any((c) => c.id == channelId);
        if (isDm && room.remoteParticipants.isEmpty) unawaited(leave());
      })
      ..on<RoomDisconnectedEvent>((_) {
        // Only sound off if we had actually finished joining: a mid-setup
        // failure disconnects too, and never played a join sound to answer.
        final wasConnected = _ref.read(voiceProvider).isConnected;
        _voice.setConnection(null, VoiceConnectionStatus.disconnected);
        _room = null;
        // A disconnect the SFU decided on (kicked, room closed, network gone)
        // never passes through `leave`, and would leave the notification up.
        unawaited(stopCallService());
        if (wasConnected) _sounds.leave();
      });
  }

  /// Track visibility is keyed by participant *and* source: a camera and a
  /// screen share are two tiles from the same person.
  void _setVideoTrack(String identity, TrackSource source, VideoTrack? track) {
    switch (source) {
      case TrackSource.camera:
        _voice.setCameraTrack(identity, track);
      case TrackSource.screenShareVideo:
        _voice.setScreenShareTrack(identity, track);
      case _:
        break;
    }
  }

  Future<void> leave() async {
    final room = _room;
    if (room == null) return;
    _room = null;

    await _listener?.dispose();
    _listener = null;
    await room.disconnect();
    await room.dispose();
    // The call is over, so its notification goes with it.
    await stopCallService();
    _voice.setConnection(null, VoiceConnectionStatus.disconnected);
  }

  /// [playFeedback] is off for the mute that deafening performs on the way in,
  /// so the transition makes one sound rather than two. [syncAudio] off keeps
  /// an unmute from undoing a deafen, which is only right when the deafen
  /// transition is the caller.
  Future<void> setMicrophoneMuted({
    required bool muted,
    bool playFeedback = true,
    bool syncAudio = true,
  }) async {
    // A direct microphone action takes ownership of its own state, even while
    // the output is deafened.
    _microphoneMutedByDeafen = false;
    final wasDeafened = _ref.read(voiceProvider).localDeafened;

    // What the microphone ended up doing, which is what the button and everyone
    // else are told about — an unmute the device refuses leaves it muted.
    final room = _room;
    var applied = muted;
    if (room != null) {
      if (muted) {
        await room.localParticipant?.setMicrophoneEnabled(false);
      } else if (await _enableMicrophone(room)) {
        // A call joined muted asks for `RECORD_AUDIO` here rather than at join,
        // so this is where the service can finally claim the microphone type.
        await startCallService();
      } else {
        applied = true;
      }
    }
    _voice.setLocalMuted(muted: applied);
    final identity = room?.localParticipant?.identity;
    if (identity != null) _voice.setParticipantMuted(identity, muted: applied);

    // Unmuting while deafened turns the audio back on too. Let the undeafen
    // transition give the single sound that stands for both changes.
    final willUndeafen = !applied && wasDeafened && syncAudio;
    if (playFeedback && !willUndeafen) {
      applied ? _sounds.microphoneMute() : _sounds.microphoneUnmute();
    }
    if (willUndeafen) await setDeafened(deafened: false);
  }

  Future<void> setDeafened({required bool deafened}) async {
    if (deafened) {
      // Only remember an automatic mute when the microphone was actually live.
      // If it was already muted that was the user's choice, and it has to
      // survive the undeafen.
      if (!_ref.read(voiceProvider).localMuted) {
        await setMicrophoneMuted(muted: true, playFeedback: false);
        _microphoneMutedByDeafen = true;
      } else {
        _microphoneMutedByDeafen = false;
      }
    } else {
      if (_microphoneMutedByDeafen && _ref.read(voiceProvider).localMuted) {
        await setMicrophoneMuted(muted: false, playFeedback: false, syncAudio: false);
      }
      _microphoneMutedByDeafen = false;
    }

    _voice.setLocalDeafened(deafened: deafened);

    final room = _room;
    if (room != null) {
      await _applyDeafenToRemoteAudio(room, deafened: deafened);
      final identity = room.localParticipant?.identity;
      if (identity != null) _voice.setParticipantDeafened(identity, deafened: deafened);
      await room.localParticipant?.setAttributes({'deafened': '$deafened'}).catchError((_) {});
    }

    deafened ? _sounds.deafen() : _sounds.undeafen();
  }

  /// The browser client mutes audio elements; there are none here, so the
  /// subscription itself is switched off — which also stops the server sending
  /// audio nobody is listening to.
  Future<void> _applyDeafenToRemoteAudio(Room room, {required bool deafened}) async {
    for (final participant in room.remoteParticipants.values) {
      for (final publication in participant.audioTrackPublications) {
        await (deafened ? publication.disable() : publication.enable());
      }
    }
  }

  Future<void> setCameraEnabled({required bool enabled}) async {
    if (_room == null) return;
    try {
      await _room?.localParticipant?.setCameraEnabled(enabled);
      _voice.setLocalCameraEnabled(enabled: enabled);
    } on Object {
      _voice.setLocalCameraEnabled(enabled: false);
      rethrow;
    }
  }

  /// Front to back and back again. A phone has two cameras and no other way to
  /// pick between them, which is why this exists here and not in the web client.
  Future<void> switchCamera() async {
    final publication = _room?.localParticipant?.getTrackPublicationBySource(TrackSource.camera);
    if (publication?.track case final LocalVideoTrack track) {
      final options = track.currentOptions;
      final facingFront =
          options is! CameraCaptureOptions || options.cameraPosition == CameraPosition.front;
      await track.setCameraPosition(facingFront ? CameraPosition.back : CameraPosition.front);
    }
  }

  /// Android hands the frames over through MediaProjection, which needs the
  /// system's consent dialog first and a foreground service to stay alive; the
  /// permission call is a no-op everywhere else.
  Future<void> setScreenShareEnabled({required bool enabled}) async {
    final room = _room;
    if (room == null) return;

    try {
      if (enabled) {
        // The API is marked experimental in the SDK, but it is the only way to
        // reach MediaProjection's consent dialog from Dart.
        // ignore: experimental_member_use
        final granted = await Hardware.instance.requestCapturePermission();
        // Dismissing the system dialog is a decision, not a failure.
        if (!granted) return;
        // Between consent and capture, which is the window Android requires
        // the mediaProjection service type to be declared in.
        await startCallService(screenShare: true);
      }
      await room.localParticipant?.setScreenShareEnabled(enabled);
      _voice.setLocalScreenShareEnabled(enabled: enabled);
      // Back to a plain call: the service stays, its projection type does not.
      if (!enabled) await startCallService();
    } on Object {
      await startCallService();
      _voice.setLocalScreenShareEnabled(enabled: false);
      rethrow;
    }
  }

  @visibleForTesting
  bool get hasRoom => _room != null;
}

final voiceSessionProvider = Provider<VoiceSession>((ref) {
  final session = VoiceSession(ref);
  ref.onDispose(() => unawaited(session.leave()));
  return session;
});
