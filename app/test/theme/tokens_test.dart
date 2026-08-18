import 'package:campfire/theme/tokens.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('oklch to sRGB', () {
    // Spot-checks of the generator's colour maths, verified by converting each
    // result back to OKLCH with an independent implementation and comparing
    // against what `index.css` states. They fail if the conversion regresses or
    // if someone hand-edits the generated file.
    test('the ember accent lands on the same orange the web client shows', () {
      expect(CampfireTokens.primary, isSameColorAs(const Color(0xFFF67F2F)));
      expect(CampfireTokens.ring, isSameColorAs(const Color(0xFFE85E00)));
    });

    test('the night sky stays a deep indigo, not a flat black', () {
      expect(CampfireTokens.background, isSameColorAs(const Color(0xFF060915)));
      expect(ShellTokens.skyTop, isSameColorAs(const Color(0xFF080C1A)));
      expect(ShellTokens.skyBottom, isSameColorAs(const Color(0xFF05070F)));
      // It darkens toward the horizon, the way the linear-gradient reads.
      expect(ShellTokens.skyBottom.computeLuminance(), lessThan(ShellTokens.skyTop.computeLuminance()));
    });

    test('the foreground is warm off-white rather than pure white', () {
      expect(CampfireTokens.foreground, isSameColorAs(const Color(0xFFEAE3DE)));
      expect(CampfireTokens.foreground.r, greaterThan(CampfireTokens.foreground.b));
    });

    test('presence colours keep their meanings apart', () {
      expect(CampfireTokens.online, isSameColorAs(const Color(0xFF4EB068)));
      expect(CampfireTokens.dnd, isSameColorAs(const Color(0xFFE64343)));
      expect(CampfireTokens.offline, isSameColorAs(const Color(0xFF6D717E)));
    });
  });

  group('alpha', () {
    test('the glass surfaces stay translucent so the gradient shows through', () {
      // `oklch(1 0 0 / 0.07)` — white at 7%. An opaque value here would flatten
      // the shell's depth, which is the bug this guards against.
      expect(CampfireTokens.glass.a, closeTo(0.07, 0.004));
      expect(CampfireTokens.glassBorder.a, closeTo(0.10, 0.004));
      expect(CampfireTokens.sidebar.a, closeTo(0.40, 0.004));
      expect(CampfireTokens.rail.a, closeTo(0.50, 0.004));
    });

    test('the ember tint is warm and partial, for selected state', () {
      expect(CampfireTokens.emberTint.a, closeTo(0.35, 0.004));
      expect(CampfireTokens.emberTint.r, greaterThan(CampfireTokens.emberTint.b));
    });
  });

  group('shell animation', () {
    test('the glow settles from the flare rather than the other way round', () {
      expect(ShellTokens.glowAlphaTrough, lessThan(ShellTokens.glowAlphaPeak));
      expect(ShellTokens.glowWidthTrough, lessThan(ShellTokens.glowWidthPeak));
      expect(ShellTokens.glowHeightTrough, lessThan(ShellTokens.glowHeightPeak));
    });

    test('the glow is read as viewport fractions', () {
      for (final value in [
        ShellTokens.glowWidthPeak,
        ShellTokens.glowHeightPeak,
        ShellTokens.glowWidthTrough,
        ShellTokens.glowHeightTrough,
      ]) {
        expect(value, inExclusiveRange(0, 1));
      }
    });
  });

  test('the radius matches the stylesheet 0.75rem', () {
    expect(CampfireTokens.radius, 12.0);
  });
}
