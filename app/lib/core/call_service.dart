import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The Android foreground service a call runs under.
///
/// Two things need it: the microphone, which Android 11 takes away from an app
/// that is not in the foreground, and MediaProjection, which Android 10 refuses
/// to hand out unless such a service is already running. flutter_webrtc does
/// both captures and ships no service, so the app carries its own
/// (`android/app/src/main/kotlin/.../CallService.kt`).
///
/// Everywhere else these are no-ops: iOS keeps the audio alive through the
/// `audio` background mode declared in `Info.plist`, and a desktop needs
/// neither.
const _channel = MethodChannel('campfire/call_service');

bool get _needsForegroundService =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// Starts it, or promotes one already running: [screenShare] adds the
/// `mediaProjection` type Android wants declared while the screen is captured.
Future<void> startCallService({bool screenShare = false}) async {
  if (!_needsForegroundService) return;
  await _channel.invokeMethod<void>('start', {'screenShare': screenShare});
}

Future<void> stopCallService() async {
  if (!_needsForegroundService) return;
  // Never worth failing a hang-up over: the call is what the user asked to
  // end, and the service is bookkeeping around it.
  await _channel.invokeMethod<void>('stop').catchError((_) {});
}
