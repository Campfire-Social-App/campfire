// GENERATED FILE — DO NOT EDIT.
//
// Source: client/src/index.css (`:root` overlaid with `.dark`).
// Regenerate: dart run tool/generate_tokens.dart
//
// The stylesheet states these in oklch; the generator converts them to sRGB
// so the two clients cannot drift apart by hand-editing.

import 'dart:ui';

/// Every custom property the dark theme defines, as a Flutter [Color].
abstract final class CampfireTokens {
  static const Color accent = Color(0xFF1D2335);
  static const Color accentForeground = Color(0xFFEAE3DE);
  static const Color background = Color(0xFF060915);
  static const Color border = Color(0x14FFFFFF);
  static const Color card = Color(0xFF0E121E);
  static const Color cardForeground = Color(0xFFEAE3DE);
  static const Color chart1 = Color(0xFFF67F2F);
  static const Color chart2 = Color(0xFFFFA242);
  static const Color chart3 = Color(0xFFE64343);
  static const Color chart4 = Color(0xFFB48DF4);
  static const Color chart5 = Color(0xFF4EB068);
  static const Color destructive = Color(0xFFE64343);
  static const Color dnd = Color(0xFFE64343);
  static const Color ember = Color(0xFFFFA242);
  static const Color emberTint = Color(0x59B94A00);
  static const Color emberTintBorder = Color(0x66DC692E);
  static const Color foreground = Color(0xFFEAE3DE);
  static const Color glass = Color(0x12FFFFFF);
  static const Color glassBorder = Color(0x1AFFFFFF);
  static const Color idle = Color(0xFFFFA242);
  static const Color input = Color(0x1AFFFFFF);
  static const Color muted = Color(0xFF141824);
  static const Color mutedForeground = Color(0xFFB7A89B);
  static const Color offline = Color(0xFF6D717E);
  static const Color online = Color(0xFF4EB068);
  static const Color popover = Color(0xFF0B0E18);
  static const Color popoverForeground = Color(0xFFEAE3DE);
  static const Color primary = Color(0xFFF67F2F);
  static const Color primaryForeground = Color(0xFF2D1205);
  static const Color rail = Color(0x8003040B);
  static const Color ring = Color(0xFFE85E00);
  static const Color scrollbarThumb = Color(0x1AFFFFFF);
  static const Color scrollbarThumbHover = Color(0x73E85E00);
  static const Color secondary = Color(0xFF1A1F2E);
  static const Color secondaryForeground = Color(0xFFDBCEC4);
  static const Color sidebar = Color(0x66060911);
  static const Color sidebarAccent = Color(0x0FFFFFFF);
  static const Color sidebarAccentForeground = Color(0xFFEAE3DE);
  static const Color sidebarBorder = Color(0x0FFFFFFF);
  static const Color sidebarForeground = Color(0xFFEAE3DE);
  static const Color sidebarPrimary = Color(0xFFF67F2F);
  static const Color sidebarPrimaryForeground = Color(0xFF2D1205);
  static const Color sidebarRing = Color(0xFFE85E00);

  /// `--radius`, in logical pixels.
  static const double radius = 12;
}

/// Colours of the two full-bleed backdrops: the shell gradient behind every
/// translucent column, and the auth screens' starfield.
abstract final class ShellTokens {
  static const Color emberGlow = Color(0xFFB03000);
  static const Color skyBottom = Color(0xFF05070F);
  static const Color skyTop = Color(0xFF080C1A);
  static const Color starfieldBase = Color(0xFF04060E);
  static const Color starfieldGlow = Color(0x4DB03000);

  /// The ember glow breathes between these two states over 14s; the first is
  /// the flare, the second the settle. Sizes are fractions of the viewport.
  static const double glowAlphaPeak = 0.35;
  static const double glowWidthPeak = 0.55;
  static const double glowHeightPeak = 0.45;
  static const double glowAlphaTrough = 0.16;
  static const double glowWidthTrough = 0.4;
  static const double glowHeightTrough = 0.32;
}
