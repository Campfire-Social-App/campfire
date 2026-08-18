// Reads the React client's `index.css` and writes `lib/theme/tokens.dart`.
//
// The design tokens live in CSS in `oklch()`, which Flutter has no notion of,
// so they have to be converted to sRGB somewhere. Doing it here — at build
// time, from the real stylesheet — rather than by pasting hex codes means the
// day the CSS changes, this script runs again instead of someone hand-matching
// colours by eye.
//
//   dart run tool/generate_tokens.dart
//
// Verify with `dart run tool/generate_tokens.dart --check`, which fails if the
// checked-in output is stale (used by CI).
import 'dart:io';
import 'dart:math' as math;

const _cssPath = '../client/src/index.css';
const _outPath = 'lib/theme/tokens.dart';

/// The `.bg-night-sky` rule's `oklch()` literals, in source order.
const _nightSkyNames = ['emberGlow', 'skyTop', 'skyBottom'];

/// The `.bg-starfield` rule's `oklch()` literals, in source order.
const _starfieldNames = ['starfieldBase', 'starfieldGlow'];

void main(List<String> args) {
  final css = File(_cssPath);
  if (!css.existsSync()) {
    stderr.writeln('Cannot find $_cssPath — run this from the `app/` directory.');
    exit(1);
  }
  final source = css.readAsStringSync();

  // `.dark` sits on top of `:root`, so start from the light defaults and let the
  // dark block win. That is exactly what the cascade does in the browser.
  final vars = <String, String>{
    ..._declarations(_block(source, ':root')),
    ..._declarations(_block(source, '.dark')),
  };

  final colors = <String, Color>{};
  for (final entry in vars.entries) {
    final color = _parseColor(entry.value);
    if (color != null) colors[_camel(entry.key)] = color;
  }

  final nightSky = _namedLiterals(_block(source, '.bg-night-sky'), _nightSkyNames);
  final starfield = _namedLiterals(_block(source, '.bg-starfield'), _starfieldNames);
  final breathe = _emberKeyframes(source);
  final radius = _parseRem(vars['radius'] ?? '0.75rem');

  final generated = _render(
    colors: colors,
    shell: {...nightSky, ...starfield},
    breathe: breathe,
    radius: radius,
  );

  final out = File(_outPath);
  if (args.contains('--check')) {
    final current = out.existsSync() ? out.readAsStringSync() : '';
    if (current != generated) {
      stderr.writeln(
        '$_outPath is out of date with $_cssPath.\n'
        'Run: dart run tool/generate_tokens.dart',
      );
      exit(1);
    }
    stdout.writeln('$_outPath is up to date.');
    return;
  }
  out.writeAsStringSync(generated);
  stdout.writeln('Wrote $_outPath (${colors.length} tokens).');
}

// ---------------------------------------------------------------- CSS parsing

/// Body of the first rule whose selector line starts with [selector], with
/// nested braces (`@keyframes`) matched rather than cut at the first `}`.
String _block(String css, String selector) {
  final start = css.indexOf(RegExp('^\\s*${RegExp.escape(selector)}\\s*\\{', multiLine: true));
  if (start < 0) throw StateError('No `$selector` rule in the stylesheet.');
  final open = css.indexOf('{', start);
  var depth = 0;
  for (var i = open; i < css.length; i++) {
    if (css[i] == '{') depth++;
    if (css[i] == '}') {
      depth--;
      if (depth == 0) return css.substring(open + 1, i);
    }
  }
  throw StateError('Unterminated `$selector` rule.');
}

/// `--name: value;` pairs, keyed without the leading dashes.
Map<String, String> _declarations(String block) {
  final out = <String, String>{};
  for (final m in RegExp(r'--([a-z0-9-]+)\s*:\s*([^;]+);').allMatches(block)) {
    out[m.group(1)!] = m.group(2)!.trim();
  }
  return out;
}

/// Pairs each `oklch()` literal in [block] with a name, by source order.
Map<String, Color> _namedLiterals(String block, List<String> names) {
  final found = RegExp(r'oklch\([^)]*\)').allMatches(block).map((m) => m.group(0)!).toList();
  if (found.length < names.length) {
    throw StateError('Expected ${names.length} oklch() literals, found ${found.length}.');
  }
  return {
    for (var i = 0; i < names.length; i++) names[i]: _parseOklch(found[i])!,
  };
}

/// The two ends of the `ember-breathe` animation: the 0%/100% frame (the fire
/// flared up) and the 50% frame (settled).
({Map<String, double> peak, Map<String, double> trough}) _emberKeyframes(String css) {
  final block = _block(css, '@keyframes ember-breathe');
  final frames = <Map<String, double>>[];
  for (final m in RegExp(r'\{([^{}]*)\}').allMatches(block)) {
    final decls = _declarations(m.group(1)!);
    if (decls.isEmpty) continue;
    frames.add({
      'alpha': double.parse(decls['ember-glow-alpha']!),
      'w': double.parse(decls['ember-glow-w']!.replaceAll('%', '')) / 100,
      'h': double.parse(decls['ember-glow-h']!.replaceAll('%', '')) / 100,
    });
  }
  if (frames.length < 2) throw StateError('ember-breathe needs two keyframes.');
  return (peak: frames[0], trough: frames[1]);
}

double _parseRem(String value) {
  final m = RegExp(r'([\d.]+)rem').firstMatch(value);
  // Tailwind's root font size; 0.75rem is 12 logical pixels.
  return m == null ? 12 : double.parse(m.group(1)!) * 16;
}

// ------------------------------------------------------------------- colours

class Color {
  const Color(this.r, this.g, this.b, this.a);
  final int r;
  final int g;
  final int b;
  final double a;

  /// `0xAARRGGBB`, the literal `dart:ui` Color takes.
  String get argb {
    final alpha = (a * 255).round().clamp(0, 255);
    final value = (alpha << 24) | (r << 16) | (g << 8) | b;
    return '0x${value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }
}

Color? _parseColor(String value) =>
    _parseOklch(value) ?? _parseHex(value) ?? _parseRgba(value);

Color? _parseHex(String value) {
  final m = RegExp(r'^#([0-9a-fA-F]{6})$').firstMatch(value.trim());
  if (m == null) return null;
  final n = int.parse(m.group(1)!, radix: 16);
  return Color((n >> 16) & 0xff, (n >> 8) & 0xff, n & 0xff, 1);
}

Color? _parseRgba(String value) {
  final m = RegExp(r'^rgba?\(([^)]*)\)$').firstMatch(value.trim());
  if (m == null) return null;
  final parts = m.group(1)!.split(',').map((p) => p.trim()).toList();
  if (parts.length < 3) return null;
  return Color(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
    parts.length > 3 ? double.parse(parts[3]) : 1,
  );
}

/// `oklch(L C H)` or `oklch(L C H / A)`. An alpha given as `var(--something)`
/// is animated at runtime, so it is parsed as opaque and applied by the widget.
Color? _parseOklch(String value) {
  final m = RegExp(r'^oklch\(([^)]*)\)$').firstMatch(value.trim());
  if (m == null) return null;
  final body = m.group(1)!;
  final slash = body.indexOf('/');
  final coords = (slash < 0 ? body : body.substring(0, slash)).trim().split(RegExp(r'\s+'));
  if (coords.length < 3) return null;

  var alpha = 1.0;
  if (slash >= 0) {
    final raw = body.substring(slash + 1).trim();
    alpha = raw.startsWith('var(')
        ? 1.0
        : raw.endsWith('%')
            ? double.parse(raw.substring(0, raw.length - 1)) / 100
            : double.parse(raw);
  }

  final (r, g, b) = _oklchToSrgb(
    double.parse(coords[0]),
    double.parse(coords[1]),
    double.parse(coords[2]),
  );
  return Color(r, g, b, alpha);
}

/// Oklab (Björn Ottosson) → linear sRGB → gamma-encoded sRGB, clamped into
/// gamut by clipping each channel, which is what browsers do for these values.
(int, int, int) _oklchToSrgb(double lightness, double chroma, double hueDeg) {
  final hue = hueDeg * math.pi / 180;
  final a = chroma * math.cos(hue);
  final b = chroma * math.sin(hue);

  final lRoot = lightness + 0.3963377774 * a + 0.2158037573 * b;
  final mRoot = lightness - 0.1055613458 * a - 0.0638541728 * b;
  final sRoot = lightness - 0.0894841775 * a - 1.2914855480 * b;

  final l = lRoot * lRoot * lRoot;
  final m = mRoot * mRoot * mRoot;
  final s = sRoot * sRoot * sRoot;

  final red = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s;
  final green = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s;
  final blue = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s;

  return (_encode(red), _encode(green), _encode(blue));
}

int _encode(double linear) {
  final v = linear <= 0.0031308
      ? 12.92 * linear
      : 1.055 * math.pow(linear, 1 / 2.4) - 0.055;
  return (v.clamp(0.0, 1.0) * 255).round();
}

/// `prefer_int_literals` objects to `12.0`, so integral values are written
/// without the fractional part.
String _double(double value) =>
    value == value.roundToDouble() ? value.round().toString() : value.toString();

String _camel(String kebab) {
  final parts = kebab.split('-');
  return parts.first +
      parts.skip(1).map((p) => p.isEmpty ? '' : p[0].toUpperCase() + p.substring(1)).join();
}

// -------------------------------------------------------------------- output

String _render({
  required Map<String, Color> colors,
  required Map<String, Color> shell,
  required ({Map<String, double> peak, Map<String, double> trough}) breathe,
  required double radius,
}) {
  final buffer = StringBuffer()
    ..writeln('// GENERATED FILE — DO NOT EDIT.')
    ..writeln('//')
    ..writeln('// Source: client/src/index.css (`:root` overlaid with `.dark`).')
    ..writeln('// Regenerate: dart run tool/generate_tokens.dart')
    ..writeln('//')
    ..writeln('// The stylesheet states these in oklch; the generator converts them to sRGB')
    ..writeln('// so the two clients cannot drift apart by hand-editing.')
    ..writeln()
    ..writeln("import 'dart:ui';")
    ..writeln()
    ..writeln('/// Every custom property the dark theme defines, as a Flutter [Color].')
    ..writeln('abstract final class CampfireTokens {');

  final names = colors.keys.toList()..sort();
  for (final name in names) {
    buffer.writeln('  static const Color $name = Color(${colors[name]!.argb});');
  }
  buffer
    ..writeln()
    ..writeln('  /// `--radius`, in logical pixels.')
    ..writeln('  static const double radius = ${_double(radius)};')
    ..writeln('}')
    ..writeln()
    ..writeln('/// Colours of the two full-bleed backdrops: the shell gradient behind every')
    ..writeln("/// translucent column, and the auth screens' starfield.")
    ..writeln('abstract final class ShellTokens {');

  final shellNames = shell.keys.toList()..sort();
  for (final name in shellNames) {
    buffer.writeln('  static const Color $name = Color(${shell[name]!.argb});');
  }

  buffer
    ..writeln()
    ..writeln('  /// The ember glow breathes between these two states over 14s; the first is')
    ..writeln('  /// the flare, the second the settle. Sizes are fractions of the viewport.')
    ..writeln('  static const double glowAlphaPeak = ${_double(breathe.peak['alpha']!)};')
    ..writeln('  static const double glowWidthPeak = ${_double(breathe.peak['w']!)};')
    ..writeln('  static const double glowHeightPeak = ${_double(breathe.peak['h']!)};')
    ..writeln('  static const double glowAlphaTrough = ${_double(breathe.trough['alpha']!)};')
    ..writeln('  static const double glowWidthTrough = ${_double(breathe.trough['w']!)};')
    ..writeln('  static const double glowHeightTrough = ${_double(breathe.trough['h']!)};')
    ..writeln('}');

  return buffer.toString();
}
