import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Call tones, synthesized rather than shipped as audio files — the same choice
/// `lib/ringtone.ts` makes, and for the same reason: a ring has to loop for as
/// long as the call rings, and a few sine cycles do that without another asset
/// to decode.
///
/// The web client can hand an oscillator to the browser and let it run. There
/// is no oscillator here, so one full cycle (beeps *and* the rest that follows
/// them) is rendered into a WAV buffer once and handed to the player on loop —
/// which is what makes the pattern, not just the pitch, come out the same.
@immutable
class RingPattern {
  const RingPattern({
    required this.frequencies,
    required this.duration,
    required this.gap,
    required this.cycle,
  });

  /// Two-tone chime, twice, then a rest — "someone is calling you".
  static const incoming = RingPattern(
    frequencies: [660, 880],
    duration: Duration(milliseconds: 320),
    gap: Duration(milliseconds: 140),
    cycle: Duration(milliseconds: 2600),
  );

  /// One low tone per cycle: the caller's own ringback, deliberately duller so
  /// the two are never mistaken for each other.
  static const outgoing = RingPattern(
    frequencies: [440],
    duration: Duration(milliseconds: 900),
    gap: Duration.zero,
    cycle: Duration(milliseconds: 3200),
  );

  /// One beep per entry, in order.
  final List<double> frequencies;

  /// How long each beep sounds for.
  final Duration duration;

  /// Silence between two beeps of the same cycle.
  final Duration gap;

  /// Beat of the pattern: the cycle repeats every this long, so whatever is
  /// left after the beeps is the rest.
  final Duration cycle;
}

const int _sampleRate = 44100;

/// Ramped rather than switched at both ends: an abrupt gain step clicks
/// audibly. Same envelope as the web client's `beep`.
const Duration _attack = Duration(milliseconds: 40);
const Duration _release = Duration(milliseconds: 60);

/// Quiet on purpose. A ring is a notification playing over whatever else the
/// device is doing, and this one is generated at full scale.
const double _amplitude = 0.18;

/// One whole cycle of [pattern] as a 16-bit mono PCM WAV, ready to loop.
Uint8List renderRingtone(RingPattern pattern) {
  final total = (pattern.cycle.inMicroseconds * _sampleRate / 1000000).round();
  final samples = Float64List(total);

  var offset = 0;
  for (final frequency in pattern.frequencies) {
    final length = (pattern.duration.inMicroseconds * _sampleRate / 1000000).round();
    for (var i = 0; i < length && offset + i < total; i++) {
      final t = i / _sampleRate;
      samples[offset + i] =
          math.sin(2 * math.pi * frequency * t) * _amplitude * _envelope(i, length);
    }
    offset += length + (pattern.gap.inMicroseconds * _sampleRate / 1000000).round();
  }

  return _wav(samples);
}

/// Fades in over [_attack] and out over [_release]; flat in between.
double _envelope(int sample, int length) {
  final attack = (_attack.inMicroseconds * _sampleRate / 1000000).round();
  final release = (_release.inMicroseconds * _sampleRate / 1000000).round();
  if (sample < attack) return sample / attack;
  final remaining = length - sample;
  if (remaining < release) return remaining / release;
  return 1;
}

/// The 44-byte canonical WAV header followed by the samples, which is the one
/// container every platform's player reads without a codec.
Uint8List _wav(Float64List samples) {
  const headerBytes = 44;
  const bitsPerSample = 16;
  const channels = 1;
  final dataBytes = samples.length * 2;

  final out = ByteData(headerBytes + dataBytes);
  void ascii(int at, String tag) {
    for (var i = 0; i < tag.length; i++) {
      out.setUint8(at + i, tag.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  out.setUint32(4, headerBytes - 8 + dataBytes, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  out
    ..setUint32(16, 16, Endian.little) // PCM subchunk size
    ..setUint16(20, 1, Endian.little) // format: uncompressed PCM
    ..setUint16(22, channels, Endian.little)
    ..setUint32(24, _sampleRate, Endian.little)
    ..setUint32(28, _sampleRate * channels * bitsPerSample ~/ 8, Endian.little) // byte rate
    ..setUint16(32, channels * bitsPerSample ~/ 8, Endian.little) // block align
    ..setUint16(34, bitsPerSample, Endian.little);
  ascii(36, 'data');
  out.setUint32(40, dataBytes, Endian.little);

  for (var i = 0; i < samples.length; i++) {
    final clamped = samples[i].clamp(-1.0, 1.0);
    out.setInt16(headerBytes + i * 2, (clamped * 32767).round(), Endian.little);
  }

  return out.buffer.asUint8List();
}

/// Plays a [RingPattern] on a loop until told to stop. One at a time: a call
/// ringing in replaces the ringback of a call ringing out.
class Ringtone {
  AudioPlayer? _player;

  void startIncoming() => _start(RingPattern.incoming);
  void startOutgoing() => _start(RingPattern.outgoing);

  @protected
  @visibleForOverriding
  void start(Uint8List wav) {
    final player = AudioPlayer();
    _player = player;
    unawaited(player.setReleaseMode(ReleaseMode.loop));
    // Best effort, like every other sound: a device that cannot ring still
    // shows the call card, which is what actually answers the phone.
    unawaited(player.play(BytesSource(wav, mimeType: 'audio/wav')).catchError((_) {}));
  }

  void _start(RingPattern pattern) {
    stop();
    start(renderRingtone(pattern));
  }

  void stop() {
    final player = _player;
    _player = null;
    if (player == null) return;
    unawaited(player.stop().whenComplete(player.dispose).catchError((_) {}));
  }
}

final ringtoneProvider = Provider<Ringtone>((ref) {
  final ringtone = Ringtone();
  ref.onDispose(ringtone.stop);
  return ringtone;
});
