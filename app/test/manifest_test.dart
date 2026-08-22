import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Android manifest', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml');

    test('declares INTERNET in the manifest that ships', () {
      // The Flutter template puts this permission in the debug and profile
      // manifests only. Without it in `main`, debug builds work and the release
      // APK cannot make a single request — the app reaches the connect screen
      // and insists no server is reachable. This test exists because that
      // shipped once.
      expect(manifest.existsSync(), isTrue);
      expect(
        manifest.readAsStringSync(),
        contains('android.permission.INTERNET'),
        reason: 'a release build without this has no network at all',
      );
    });

    test('installs under the product name rather than the package name', () {
      expect(manifest.readAsStringSync(), contains('android:label="Campfire"'));
    });

    test('asks for what a call needs', () {
      final xml = manifest.readAsStringSync();
      for (final permission in [
        'android.permission.RECORD_AUDIO',
        'android.permission.CAMERA',
        'android.permission.MODIFY_AUDIO_SETTINGS',
      ]) {
        expect(xml, contains(permission), reason: permission);
      }
    });

    test('declares the foreground service a call runs under', () {
      // Without it Android 11 takes the microphone away the moment the app
      // leaves the screen, and MediaProjection refuses to start at all — and
      // both failures only show up on a device, never in a test or a debug run
      // on the desk.
      final xml = manifest.readAsStringSync();
      expect(xml, contains('android:name=".CallService"'));
      expect(xml, contains('android:foregroundServiceType="microphone|mediaProjection"'));
      expect(xml, contains('android.permission.FOREGROUND_SERVICE_MICROPHONE'));
      expect(xml, contains('android.permission.FOREGROUND_SERVICE_MEDIA_PROJECTION'));
    });

    test('claims only the service types it holds the permission for', () {
      // Declaring the microphone type before `RECORD_AUDIO` is granted throws
      // `SecurityException` from Android 14, and an exception out of
      // `onStartCommand` kills the process — joining a voice channel on a fresh
      // install crashed the app until the service started checking first.
      final kotlin = File(
        'android/app/src/main/kotlin/com/campfire/campfire/CallService.kt',
      ).readAsStringSync();
      expect(kotlin, contains('checkSelfPermission(Manifest.permission.RECORD_AUDIO)'));
      expect(kotlin, contains('catch (error: Exception)'));
    });
  });

  group('iOS Info.plist', () {
    final plist = File('ios/Runner/Info.plist');

    test('explains why it wants the microphone and the camera', () {
      // iOS kills an app that touches either without a usage string, with no
      // prompt and no log worth reading.
      final xml = plist.readAsStringSync();
      expect(xml, contains('NSMicrophoneUsageDescription'));
      expect(xml, contains('NSCameraUsageDescription'));
    });

    test('keeps audio running with the app in the background', () {
      expect(plist.readAsStringSync(), contains('<string>audio</string>'));
    });
  });
}
