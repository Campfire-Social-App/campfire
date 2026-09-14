import 'package:campfire/livekit/voice.dart';
import 'package:campfire/state/voice.dart';
import 'package:campfire/widgets/voice_controls.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _CameraOnVoice extends VoiceNotifier {
  @override
  VoiceState build() => const VoiceState(localCameraEnabled: true);
}

void main() {
  for (final dense in [false, true]) {
    testWidgets(
      'Android controls fit a narrow screen (dense: $dense)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              voiceProvider.overrideWith(_CameraOnVoice.new),
              // No media room or native plugins are needed for a layout check.
              voiceSessionProvider.overrideWith(VoiceSession.new),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(24),
                  child: VoiceControls(dense: dense, onHangUp: () async {}),
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.byTooltip('Switch camera'), findsOneWidget);
        expect(find.byTooltip('Share screen'), findsOneWidget);
        expect(find.byTooltip('Disconnect'), findsOneWidget);
        final buttons = find.byType(InkWell);
        expect(buttons, findsNWidgets(6));
        for (final element in buttons.evaluate()) {
          final size = tester.getSize(find.byWidget(element.widget));
          expect(size.width, greaterThanOrEqualTo(48));
          expect(size.height, greaterThanOrEqualTo(48));
        }
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }
}
