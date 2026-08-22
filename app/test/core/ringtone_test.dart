import 'dart:typed_data';

import 'package:campfire/core/ringtone.dart';
import 'package:flutter_test/flutter_test.dart';

/// The tones are generated rather than shipped, so the file the player is
/// handed is only as correct as this code — hence the header checks. The web
/// client gets the same guarantee for free from the browser's oscillator.
void main() {
  const sampleRate = 44100;

  String tag(Uint8List wav, int at) => String.fromCharCodes(wav.sublist(at, at + 4));

  ByteData view(Uint8List wav) => ByteData.sublistView(wav);

  test('renders a canonical 16-bit mono WAV', () {
    final wav = renderRingtone(RingPattern.incoming);
    final data = view(wav);

    expect(tag(wav, 0), 'RIFF');
    expect(tag(wav, 8), 'WAVE');
    expect(tag(wav, 12), 'fmt ');
    expect(tag(wav, 36), 'data');
    expect(data.getUint16(20, Endian.little), 1, reason: 'uncompressed PCM');
    expect(data.getUint16(22, Endian.little), 1, reason: 'mono');
    expect(data.getUint32(24, Endian.little), sampleRate);
    expect(data.getUint16(34, Endian.little), 16, reason: 'bits per sample');
    // The two lengths in the header have to agree with the buffer, or a player
    // reads past the end or stops early.
    expect(data.getUint32(4, Endian.little), wav.length - 8);
    expect(data.getUint32(40, Endian.little), wav.length - 44);
  });

  test('is exactly one cycle long, so looping keeps the beat', () {
    for (final pattern in [RingPattern.incoming, RingPattern.outgoing]) {
      final samples = (renderRingtone(pattern).length - 44) ~/ 2;
      expect(samples, (pattern.cycle.inMilliseconds * sampleRate / 1000).round());
    }
  });

  test('the rest after the beeps really is silence', () {
    final wav = renderRingtone(RingPattern.outgoing);
    final data = view(wav);
    // One 900 ms beep in a 3.2 s cycle: everything past the first second is the
    // gap between rings, and has to be quiet or the loop drones.
    for (var sample = sampleRate; sample < (wav.length - 44) ~/ 2; sample += 97) {
      expect(data.getInt16(44 + sample * 2, Endian.little), 0);
    }
  });

  test('opens and closes on a ramp rather than a step', () {
    // A gain that switches instead of sliding clicks audibly at both ends.
    final wav = renderRingtone(RingPattern.incoming);
    final data = view(wav);

    int amplitudeAt(int sample) => data.getInt16(44 + sample * 2, Endian.little).abs();

    expect(amplitudeAt(0), 0);
    final peak = [
      for (var i = 0; i < sampleRate ~/ 8; i++) amplitudeAt(i),
    ].reduce((a, b) => a > b ? a : b);
    expect(peak, greaterThan(1000), reason: 'audible once it is up');
    // The last sample of the first beep is on the way back down to nothing.
    final beepEnd = (RingPattern.incoming.duration.inMilliseconds * sampleRate / 1000).round();
    expect(amplitudeAt(beepEnd - 1), lessThan(peak ~/ 4));
  });
}
