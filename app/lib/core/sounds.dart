import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The short feedback clips voice actions make — the same six files the web
/// client plays, bundled from `assets/sounds/`.
///
/// Port of `lib/sounds.ts`. Each call gets its own player: the sounds are
/// under a second and can legitimately overlap (mute while someone is joining),
/// and a single shared player would cut the first one off.
class Sounds {
  /// Matches `VOICE_SOUND_VOLUME` in the web client — these are feedback, not
  /// content, and at full volume they are louder than the call itself.
  static const double volume = 0.5;

  void join() => play('join.mp3');
  void leave() => play('leave.mp3');
  void microphoneMute() => play('mic_mute.mp3');
  void microphoneUnmute() => play('mic_unmute.mp3');
  void deafen() => play('deafen.mp3');
  void undeafen() => play('undeafen.mp3');

  /// Fire and forget, deliberately: a device with no audio output, or a web
  /// autoplay policy that has not seen a gesture yet, must not turn a mute into
  /// a thrown error. Overridden in tests to keep the suite silent.
  @protected
  @visibleForOverriding
  void play(String asset) {
    final player = AudioPlayer();
    player.onPlayerComplete.listen((_) => unawaited(player.dispose()));
    unawaited(player.play(AssetSource('sounds/$asset'), volume: volume).catchError((_) {
      // Nothing to fall back to and nothing to report: dispose and move on.
      return player.dispose();
    }));
  }
}

final soundsProvider = Provider<Sounds>((ref) => Sounds());
