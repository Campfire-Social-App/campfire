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
  });
}
