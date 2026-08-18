import 'dart:async';
import 'dart:ui' as ui;

import 'package:campfire/theme/tokens.dart';
import 'package:flutter/material.dart';

/// The whole app's backdrop: a warm campfire glow rising from the bottom of the
/// window over an indigo night sky that darkens toward the horizon.
///
/// This is the only widget in the app that paints a background. Everything
/// above it — rail, sidebar, member list, composer — is translucent, so the
/// glow carries across all four columns instead of stopping at the chat pane's
/// edges. The glow breathes on a 14s cycle, like a fire settling and flaring
/// back up; [ShellTokens] holds both ends of that cycle, read out of the CSS
/// keyframes by the token generator.
class NightSky extends StatefulWidget {
  const NightSky({required this.child, super.key});

  final Widget child;

  @override
  State<NightSky> createState() => _NightSkyState();
}

class _NightSkyState extends State<NightSky> with SingleTickerProviderStateMixin {
  /// Half the 14s CSS cycle: the controller reverses to make the other half,
  /// which is what `0% -> 50% -> 100%` with symmetric keyframes describes.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  );

  late final Animation<double> _breathe = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Honours the OS "reduce motion" switch, the same way the stylesheet's
    // `prefers-reduced-motion` media query drops the animation.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 0;
    } else if (!_controller.isAnimating) {
      unawaited(_controller.repeat(reverse: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _breathe,
        builder: (context, child) => CustomPaint(
          painter: _NightSkyPainter(_breathe.value),
          isComplex: true,
          willChange: _controller.isAnimating,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

class _NightSkyPainter extends CustomPainter {
  const _NightSkyPainter(this.t);

  /// 0 at the flare, 1 at the settle.
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    canvas
      ..drawRect(rect, Paint()..color = CampfireTokens.background)
      ..drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [ShellTokens.skyTop, ShellTokens.skyBottom],
          ).createShader(rect),
      );

    paintEmberGlow(
      canvas,
      size,
      color: ShellTokens.emberGlow,
      alpha: ui.lerpDouble(ShellTokens.glowAlphaPeak, ShellTokens.glowAlphaTrough, t)!,
      widthFraction: ui.lerpDouble(ShellTokens.glowWidthPeak, ShellTokens.glowWidthTrough, t)!,
      heightFraction: ui.lerpDouble(ShellTokens.glowHeightPeak, ShellTokens.glowHeightTrough, t)!,
    );
  }

  @override
  bool shouldRepaint(_NightSkyPainter oldDelegate) => oldDelegate.t != t;
}

/// The `radial-gradient(ellipse W H at 50% Y%, colour, transparent 70%)` the two
/// backdrops share.
///
/// Flutter's [RadialGradient] is circular, so the ellipse is made by scaling the
/// canvas around the glow's centre and painting a unit circle into it — the
/// shader is scaled along with the geometry, which is exactly the CSS shape.
void paintEmberGlow(
  Canvas canvas,
  Size size, {
  required Color color,
  required double alpha,
  required double widthFraction,
  required double heightFraction,
  double centerY = 1,
}) {
  final radiusX = widthFraction * size.width;
  final radiusY = heightFraction * size.height;
  if (radiusX <= 0 || radiusY <= 0) return;

  canvas
    ..save()
    ..translate(size.width / 2, size.height * centerY)
    ..scale(radiusX, radiusY);

  final transparent = color.withValues(alpha: 0);
  final shader = ui.Gradient.radial(
    Offset.zero,
    1,
    [color.withValues(alpha: alpha), transparent, transparent],
    // `transparent 70%` in the stylesheet: fully faded at 70% of the radius.
    [0, 0.7, 1],
  );

  // In the scaled frame the viewport spans this much; `TileMode.clamp` leaves
  // everything past the ellipse transparent.
  canvas
    ..drawRect(
      Rect.fromLTRB(
        -size.width / 2 / radiusX,
        -size.height * centerY / radiusY,
        size.width / 2 / radiusX,
        size.height * (1 - centerY) / radiusY,
      ),
      Paint()..shader = shader,
    )
    ..restore();
}

/// Backdrop for the full-bleed auth screens: the same campfire glow over an
/// opaque night-navy, plus star points tiled across a 260px grid.
///
/// Opaque on its own, unlike [NightSky]'s columns — there is no gradient behind
/// it.
class Starfield extends StatelessWidget {
  const Starfield({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: const _StarfieldPainter(),
        isComplex: true,
        child: child,
      ),
    );
  }
}

/// A star in the repeating 260x260 tile: position as a fraction of the tile,
/// radius in logical pixels, and how brightly it burns.
typedef _Star = (double x, double y, double radius, double opacity);

class _StarfieldPainter extends CustomPainter {
  const _StarfieldPainter();

  static const _tile = 260.0;
  static const List<_Star> _stars = [
    (0.10, 0.20, 1.5, 0.85),
    (0.35, 0.65, 1.0, 0.60),
    (0.60, 0.15, 1.5, 0.70),
    (0.80, 0.55, 1.0, 0.50),
    (0.92, 0.30, 2.0, 0.90),
    (0.15, 0.85, 1.0, 0.55),
    (0.45, 0.90, 1.5, 0.70),
    (0.70, 0.80, 1.0, 0.50),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = ShellTokens.starfieldBase);

    for (var originY = 0.0; originY < size.height; originY += _tile) {
      for (var originX = 0.0; originX < size.width; originX += _tile) {
        for (final (x, y, radius, opacity) in _stars) {
          canvas.drawCircle(
            Offset(originX + x * _tile, originY + y * _tile),
            radius,
            Paint()..color = Colors.white.withValues(alpha: opacity),
          );
        }
      }
    }

    paintEmberGlow(
      canvas,
      size,
      color: ShellTokens.starfieldGlow,
      alpha: ShellTokens.starfieldGlow.a,
      widthFraction: 0.7,
      heightFraction: 0.45,
      // The stylesheet pushes this one just below the bottom edge.
      centerY: 1.05,
    );
  }

  @override
  bool shouldRepaint(_StarfieldPainter oldDelegate) => false;
}
