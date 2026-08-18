import 'package:campfire/theme/tokens.dart';
import 'package:flutter/material.dart';

/// Weight axis values for the two variable fonts. Both families ship as a
/// single file, so weight is a variation rather than a separate asset — but
/// [TextStyle.fontWeight] still has to be set alongside, because that is what
/// Flutter uses for line metrics and for synthetic fallback.
abstract final class FontWeights {
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
}

/// Body/UI face. `Fraunces` is reserved for headings, per the client's
/// `--font-sans` / `--font-heading` split.
const _sans = 'Geist';
const _heading = 'Fraunces';

TextStyle _geist(double size, FontWeight weight, {double? height, double? spacing}) =>
    TextStyle(
      fontFamily: _sans,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: spacing,
      fontVariations: [FontVariation('wght', weight.value.toDouble())],
    );

TextStyle _fraunces(double size, FontWeight weight, {double? height, double? spacing}) =>
    TextStyle(
      fontFamily: _heading,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: spacing,
      fontVariations: [
        FontVariation('wght', weight.value.toDouble()),
        // Fraunces' optical-size axis; pinned near display sizes so headings
        // keep the high-contrast, slightly wonky cut the web client shows.
        FontVariation('opsz', size.clamp(9, 144).toDouble()),
        const FontVariation('SOFT', 0),
        const FontVariation('WONK', 1),
      ],
    );

/// The one theme the app ships. The web client has a `:root` light block, but
/// it is never applied — the shell hard-codes `.dark`, and so does this.
ThemeData buildCampfireTheme() {
  const scheme = ColorScheme.dark(
    primary: CampfireTokens.primary,
    onPrimary: CampfireTokens.primaryForeground,
    secondary: CampfireTokens.secondary,
    onSecondary: CampfireTokens.secondaryForeground,
    error: CampfireTokens.destructive,
    onError: CampfireTokens.foreground,
    surface: CampfireTokens.card,
    onSurface: CampfireTokens.cardForeground,
    surfaceContainerHighest: CampfireTokens.accent,
    onSurfaceVariant: CampfireTokens.mutedForeground,
    outline: CampfireTokens.border,
    outlineVariant: CampfireTokens.glassBorder,
  );

  final textTheme = TextTheme(
    displayLarge: _fraunces(48, FontWeights.bold, height: 1.1),
    displayMedium: _fraunces(36, FontWeights.bold, height: 1.15),
    displaySmall: _fraunces(30, FontWeights.semiBold, height: 1.2),
    headlineLarge: _fraunces(28, FontWeights.semiBold, height: 1.2),
    headlineMedium: _fraunces(24, FontWeights.semiBold, height: 1.25),
    headlineSmall: _fraunces(20, FontWeights.semiBold, height: 1.3),
    titleLarge: _geist(18, FontWeights.semiBold, height: 1.35),
    titleMedium: _geist(16, FontWeights.medium, height: 1.4),
    titleSmall: _geist(14, FontWeights.medium, height: 1.4),
    bodyLarge: _geist(16, FontWeights.regular, height: 1.5),
    bodyMedium: _geist(15, FontWeights.regular, height: 1.5),
    bodySmall: _geist(13, FontWeights.regular, height: 1.45),
    labelLarge: _geist(14, FontWeights.medium, height: 1.3),
    labelMedium: _geist(12, FontWeights.medium, height: 1.3),
    // Timestamps and the "edited" marker: small, wide, quiet.
    labelSmall: _geist(11, FontWeights.medium, height: 1.3, spacing: 0.2),
  ).apply(
    bodyColor: CampfireTokens.foreground,
    displayColor: CampfireTokens.foreground,
  );

  final radius = BorderRadius.circular(CampfireTokens.radius);

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    textTheme: textTheme,
    fontFamily: _sans,
    // Transparent, not `background`: every surface in this app floats on the
    // single night-sky gradient painted by the shell. Anything that paints its
    // own opaque fill breaks the glow carrying across the columns.
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: Colors.transparent,
    splashFactory: InkSparkle.splashFactory,
    dividerTheme: const DividerThemeData(
      color: CampfireTokens.border,
      space: 1,
      thickness: 1,
    ),
    iconTheme: const IconThemeData(color: CampfireTokens.mutedForeground, size: 20),
    dialogTheme: DialogThemeData(
      backgroundColor: CampfireTokens.popover,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: textTheme.headlineSmall,
      contentTextStyle: textTheme.bodyMedium,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: const BorderSide(color: CampfireTokens.border),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: CampfireTokens.popover,
      surfaceTintColor: Colors.transparent,
      textStyle: textTheme.bodyMedium,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: const BorderSide(color: CampfireTokens.border),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: CampfireTokens.popover,
        borderRadius: BorderRadius.circular(CampfireTokens.radius * 0.6),
        border: Border.all(color: CampfireTokens.border),
      ),
      textStyle: textTheme.labelMedium,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: CampfireTokens.glass,
      hintStyle: textTheme.bodyMedium?.copyWith(color: CampfireTokens.mutedForeground),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: CampfireTokens.glassBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: CampfireTokens.glassBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: CampfireTokens.ring, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: CampfireTokens.destructive),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: CampfireTokens.primary,
        foregroundColor: CampfireTokens.primaryForeground,
        textStyle: textTheme.labelLarge,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: CampfireTokens.mutedForeground,
        textStyle: textTheme.labelLarge,
        minimumSize: const Size(0, 40),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: CampfireTokens.foreground,
        textStyle: textTheme.labelLarge,
        minimumSize: const Size(0, 44),
        side: const BorderSide(color: CampfireTokens.glassBorder),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: CampfireTokens.popover,
      contentTextStyle: textTheme.bodyMedium,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: const BorderSide(color: CampfireTokens.border),
      ),
    ),
  );
}
