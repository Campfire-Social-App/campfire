import 'dart:async';
import 'dart:math';

import 'package:campfire/state/api.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Reports mic/device lifecycle events to `POST /api/diagnostics/audio-events`,
/// so production bugs ("mutes itself", device switches) leave a trail in
/// Postgres. `debugPrint` alone is stripped from release builds, which is why
/// none of this survived to be diagnosable before — see `livekit/voice.dart`.
///
/// Port of `client/src/lib/audioDiagnostics.ts`: same batching shape, same
/// best-effort flush (a failed send is retried next tick, never surfaced to
/// the user).
class AudioDiagnostics {
  AudioDiagnostics(this._ref);

  static const _maxQueue = 200;
  static const _flushInterval = Duration(seconds: 3);
  static const _flushAtSize = 20;

  final Ref _ref;
  final _random = Random();

  String? _sessionId;
  String? _channelId;
  final List<Map<String, dynamic>> _queue = [];
  bool _flushing = false;
  Timer? _timer;

  String get _platform {
    if (kIsWeb) return 'flutter-web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      _ => 'unknown',
    };
  }

  /// Call once per join attempt — every event logged until [endSession] shares
  /// this id, so the whole attempt can be pulled with one `WHERE session_id`.
  void startSession(String channelId) {
    _sessionId = '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 32)}';
    _channelId = channelId;
    _timer ??= Timer.periodic(_flushInterval, (_) => unawaited(_flush()));
  }

  void endSession() {
    unawaited(_flush());
    _sessionId = null;
    _channelId = null;
  }

  void logEvent(String eventType, [Map<String, dynamic> detail = const {}]) {
    _queue.add({
      'platform': _platform,
      'event_type': eventType,
      'channel_id': _channelId,
      'session_id': _sessionId,
      'client_ts': DateTime.now().toUtc().toIso8601String(),
      'detail': detail,
    });
    if (_queue.length > _maxQueue) {
      _queue.removeRange(0, _queue.length - _maxQueue);
    }
    if (_queue.length >= _flushAtSize) {
      unawaited(_flush());
    } else {
      _timer ??= Timer.periodic(_flushInterval, (_) => unawaited(_flush()));
    }
  }

  Future<void> _flush() async {
    if (_flushing || _queue.isEmpty) return;
    _flushing = true;
    final batch = List<Map<String, dynamic>>.of(_queue);
    _queue.clear();
    try {
      await _ref.read(apiProvider).sendAudioEvents(batch);
    } on Object {
      // The server (or network) is unreachable — keep the batch for the next
      // tick rather than dropping it, capped so an outage can't grow this
      // without bound.
      _queue.insertAll(0, batch);
      if (_queue.length > _maxQueue) {
        _queue.removeRange(0, _queue.length - _maxQueue);
      }
    } finally {
      _flushing = false;
    }
  }
}
