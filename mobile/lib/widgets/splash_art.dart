import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// The launch scene: the app icon's pin drops onto a map of Tunis while radar rings pulse around
/// it and a trail of paw prints walks up to it. Drawn in code, so it is sharp at any size; still
/// (the final frame) when the phone asks for reduced motion.
class SplashArt extends StatefulWidget {
  const SplashArt({super.key, required this.child});

  /// Under the pin: the wordmark and tagline.
  final Widget child;

  @override
  State<SplashArt> createState() => _SplashArtState();
}

class _SplashArtState extends State<SplashArt> with TickerProviderStateMixin {
  // One run for the entrance (pin, paw prints, words), a loop for the rings
  late final _entrance = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  late final _rings = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _entrance.value = 1;
      _rings.value = 0.35;
    } else if (!_entrance.isAnimating && _entrance.value == 0) {
      _entrance.forward();
      _rings.repeat();
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    _rings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final pin = math.min(size.width * 0.62, 260.0);
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: Brand.gradient),
      child: AnimatedBuilder(
        animation: Listenable.merge([_entrance, _rings]),
        builder: (context, _) {
          final t = _entrance.value;
          // The pin falls from above and lands with a small bounce
          final drop = Curves.bounceOut.transform(const Interval(0.0, 0.55).transform(t));
          final words = Curves.easeOutCubic.transform(const Interval(0.45, 0.9).transform(t));
          return Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _ScenePainter(
                  rings: _rings.value,
                  trail: const Interval(0.25, 1.0).transform(t),
                  landed: drop,
                  pinCenter: Offset(size.width / 2, size.height * 0.40),
                  pinSize: pin,
                ),
              ),
              Positioned(
                left: (size.width - pin) / 2,
                top: size.height * 0.40 - pin * 0.5 - (1 - drop) * size.height * 0.35,
                width: pin,
                height: pin,
                child: Opacity(
                  opacity: Curves.easeOut.transform(const Interval(0, 0.15).transform(t)),
                  child: Image.asset('assets/icon/splash.png', width: pin, height: pin),
                ),
              ),
              Positioned(
                left: 24,
                right: 24,
                top: size.height * 0.40 + pin * 0.62,
                child: Opacity(
                  opacity: words,
                  child: Transform.translate(offset: Offset(0, (1 - words) * 16), child: widget.child),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter({
    required this.rings,
    required this.trail,
    required this.landed,
    required this.pinCenter,
    required this.pinSize,
  });

  final double rings; // 0..1, looping
  final double trail; // 0..1: how many paw prints are down
  final double landed; // 0..1: the pin's fall
  final Offset pinCenter;
  final double pinSize;

  @override
  void paint(Canvas canvas, Size size) {
    _glow(canvas, size);
    _skyline(canvas, size);
    _radar(canvas);
    _pawTrail(canvas, size);
    _groundShadow(canvas);
  }

  /// A soft light top-left, like the icon.
  void _glow(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = RadialGradient(colors: [Colors.white.withValues(alpha: 0.22), Colors.white.withValues(alpha: 0)])
          .createShader(Rect.fromCircle(center: Offset(size.width * 0.15, size.height * 0.1), radius: size.width));
    canvas.drawRect(Offset.zero & size, paint);
  }

  /// Rings spreading from the pin and fading: "looking for them, nearby".
  void _radar(Canvas canvas) {
    final head = pinCenter.translate(0, -pinSize * 0.12);
    for (var i = 0; i < 3; i++) {
      final phase = (rings + i / 3) % 1.0;
      final radius = pinSize * (0.45 + phase * 1.4);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = Colors.white.withValues(alpha: 0.32 * (1 - phase) * landed);
      canvas.drawCircle(head, radius, paint);
    }
  }

  /// Paw prints walking in from the top-left corner down to the pin, appearing one by one (the
  /// space under the pin is for the words).
  void _pawTrail(Canvas canvas, Size size) {
    const steps = 7;
    final start = Offset(size.width * 0.06, size.height * 0.05);
    final end = pinCenter.translate(-pinSize * 0.42, -pinSize * 0.05);
    for (var i = 0; i < steps; i++) {
      final shown = (trail * steps - i).clamp(0.0, 1.0);
      if (shown <= 0) continue;
      final f = i / (steps - 1);
      // A gentle curve, alternating left and right feet
      final along = Offset.lerp(start, end, f)!;
      final bend = math.sin(f * math.pi) * size.width * 0.12;
      final side = (i.isEven ? -1 : 1) * 9.0;
      final direction = (end - start).direction;
      final normal = Offset(math.cos(direction + math.pi / 2), math.sin(direction + math.pi / 2));
      final at = along + normal * (side - bend * 0.4);
      _paw(canvas, at, 8 + f * 4, direction + math.pi / 2, Colors.white.withValues(alpha: (0.18 + f * 0.2) * shown));
    }
  }

  void _paw(Canvas canvas, Offset at, double r, double angle, Color color) {
    final paint = Paint()..color = color;
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(angle);
    canvas.drawOval(Rect.fromCenter(center: Offset(0, r * 0.35), width: r * 1.5, height: r * 1.2), paint);
    for (final (dx, dy) in [(-0.75, -0.45), (-0.27, -0.95), (0.27, -0.95), (0.75, -0.45)]) {
      canvas.drawOval(Rect.fromCenter(center: Offset(dx * r, dy * r), width: r * 0.5, height: r * 0.62), paint);
    }
    canvas.restore();
  }

  /// The pin's shadow on the ground, growing as it lands.
  void _groundShadow(Canvas canvas) {
    final tip = pinCenter.translate(0, pinSize * 0.44);
    final paint = Paint()
      ..color = const Color(0xFF0F0C46).withValues(alpha: 0.35 * landed)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawOval(Rect.fromCenter(center: tip, width: pinSize * 0.5 * landed, height: pinSize * 0.1), paint);
  }

  /// Tunis along the bottom: rooftops, domes, a minaret, arches and palm trees, as a soft silhouette.
  void _skyline(Canvas canvas, Size size) {
    final w = size.width;
    final base = size.height;
    final unit = w / 100;
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.16);
    final path = Path()..moveTo(0, base);

    void box(double x, double width, double height) => path
      ..lineTo(x * unit, base - height * unit)
      ..lineTo((x + width) * unit, base - height * unit)
      ..lineTo((x + width) * unit, base);

    void dome(double x, double width, double wall) {
      final left = x * unit;
      final right = (x + width) * unit;
      final spring = base - wall * unit;
      path
        ..lineTo(left, spring)
        ..arcToPoint(Offset(right, spring), radius: Radius.circular(width * unit / 2))
        ..lineTo(right, base);
    }

    box(0, 9, 9);
    dome(9, 10, 8);
    box(19, 7, 12);
    // The minaret: a square tower with a small lantern on top
    box(26, 5, 21);
    path
      ..lineTo(26.8 * unit, base - 21 * unit)
      ..lineTo(26.8 * unit, base - 24 * unit)
      ..lineTo(30.2 * unit, base - 24 * unit)
      ..lineTo(30.2 * unit, base - 21 * unit);
    box(31, 10, 10);
    dome(41, 14, 9);
    box(55, 8, 7);
    dome(63, 8, 11);
    box(71, 12, 9);
    dome(83, 9, 7);
    box(92, 8, 10);
    path
      ..lineTo(w, base)
      ..close();
    canvas.drawPath(path, paint);

    // Arched doorways cut into the walls
    final door = Paint()..color = Brand.indigo.withValues(alpha: 0.18);
    for (final x in [3.5, 34.0, 74.0, 95.0]) {
      final rect = Rect.fromLTWH(x * unit, base - 5 * unit, 2.6 * unit, 5 * unit);
      canvas.drawRRect(
        RRect.fromRectAndCorners(rect, topLeft: Radius.circular(1.3 * unit), topRight: Radius.circular(1.3 * unit)),
        door,
      );
    }

    // Palm trees on either side
    for (final (x, height) in [(15.0, 17.0), (60.0, 15.0), (88.0, 19.0)]) {
      _palm(canvas, Offset(x * unit, base), height * unit, paint);
    }
  }

  void _palm(Canvas canvas, Offset foot, double height, Paint paint) {
    final trunk = Path()
      ..moveTo(foot.dx - 2, foot.dy)
      ..quadraticBezierTo(foot.dx + height * 0.08, foot.dy - height * 0.5, foot.dx + 1, foot.dy - height)
      ..lineTo(foot.dx + 3, foot.dy - height)
      ..quadraticBezierTo(foot.dx + height * 0.1 + 2, foot.dy - height * 0.5, foot.dx + 2, foot.dy)
      ..close();
    canvas.drawPath(trunk, paint);
    final crown = foot.translate(2, -height);
    for (final angle in [-2.6, -2.1, -1.6, -1.05, -0.55]) {
      final leaf = Path()
        ..moveTo(crown.dx, crown.dy)
        ..quadraticBezierTo(
          crown.dx + math.cos(angle) * height * 0.35,
          crown.dy + math.sin(angle) * height * 0.45,
          crown.dx + math.cos(angle + 0.5) * height * 0.5,
          crown.dy + math.sin(angle + 0.5) * height * 0.3 + height * 0.1,
        )
        ..quadraticBezierTo(
          crown.dx + math.cos(angle) * height * 0.25,
          crown.dy + math.sin(angle) * height * 0.25,
          crown.dx,
          crown.dy,
        );
      canvas.drawPath(leaf, paint);
    }
  }

  @override
  bool shouldRepaint(_ScenePainter old) =>
      old.rings != rings || old.trail != trail || old.landed != landed || old.pinSize != pinSize;
}
