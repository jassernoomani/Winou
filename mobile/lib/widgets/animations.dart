import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Fades and slides its child in once, when first built. In lists, [index] staggers the items.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = const Offset(0, 0.12),
    this.scale = 1,
    this.duration = const Duration(milliseconds: 420),
  });

  final Widget child;
  final int index;
  final Offset offset; // start position, as a fraction of the child's size
  final double scale; // start scale
  final Duration duration;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: widget.duration);
  late final _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    final delay = Duration(milliseconds: 45 * math.min(widget.index, 8)); // later items need no wait
    Future.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _curve,
    child: SlideTransition(
      position: Tween(begin: widget.offset, end: Offset.zero).animate(_curve),
      child: widget.scale == 1
          ? widget.child
          : ScaleTransition(
              scale: Tween(begin: widget.scale, end: 1.0).animate(_curve),
              child: widget.child,
            ),
    ),
  );
}

/// The match score as a ring that fills up, with the percentage counting along.
class SimilarityRing extends StatelessWidget {
  const SimilarityRing(this.score, {super.key, this.size = 64});

  final double score; // 0..1
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: score.clamp(0, 1)),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => SizedBox.square(
        dimension: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _RingPainter(value, track: colors.primaryContainer, stroke: size / 12),
            ),
            Center(
              child: Text(
                '${(value * 100).round()}%',
                style: TextStyle(fontSize: size / 4, fontWeight: FontWeight.w900, color: colors.onSurface),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, {required this.track, required this.stroke});

  final double value;
  final Color track;
  final double stroke; // the guide: 8px on a 96px ring

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      Paint()
        ..color = Brand.blue
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value || old.track != track || old.stroke != stroke;
}

/// A soft pulsing halo, to draw the eye to something urgent (an injured animal on the map).
class Pulse extends StatefulWidget {
  const Pulse({super.key, required this.color, required this.child, this.size = 52});

  final Color color;
  final Widget child;
  final double size;

  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: widget.size,
    child: Stack(
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (_, _) => Container(
            width: widget.size * (0.5 + 0.5 * _controller.value),
            height: widget.size * (0.5 + 0.5 * _controller.value),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color.withValues(alpha: 0.45 * (1 - _controller.value)),
            ),
          ),
        ),
        widget.child,
      ],
    ),
  );
}

/// A gentle bob up and down, for the logo on the splash and sign-in screens.
class Bob extends StatefulWidget {
  const Bob({super.key, required this.child});

  final Widget child;

  @override
  State<Bob> createState() => _BobState();
}

class _BobState extends State<Bob> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (_, child) =>
        Transform.translate(offset: Offset(0, -6 * Curves.easeInOut.transform(_controller.value)), child: child),
    child: widget.child,
  );
}
