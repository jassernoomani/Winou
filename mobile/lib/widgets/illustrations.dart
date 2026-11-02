import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme.dart';
import 'animations.dart';

/// The app icon's radar rings around [child], gently pulsing outwards: "looking, nearby". The
/// same motif as the icon and the launch screen. Still when the phone asks for reduced motion.
class RadarRings extends StatefulWidget {
  const RadarRings({super.key, required this.child, required this.color, this.size = 200, this.rings = 3});

  final Widget child;
  final Color color;
  final double size; // the whole drawing, rings included
  final int rings;

  @override
  State<RadarRings> createState() => _RadarRingsState();
}

class _RadarRingsState extends State<RadarRings> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 0.3;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: widget.size,
    child: CustomPaint(
      painter: _RingsPainter(_controller, widget.color, widget.rings),
      child: Center(child: widget.child),
    ),
  );
}

class _RingsPainter extends CustomPainter {
  _RingsPainter(this.progress, this.color, this.rings) : super(repaint: progress);

  final Animation<double> progress;
  final Color color;
  final int rings;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final max = size.shortestSide / 2;
    for (var i = 0; i < rings; i++) {
      final phase = (progress.value + i / rings) % 1.0;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color.withValues(alpha: 0.45 * (1 - phase));
      canvas.drawCircle(center, max * (0.42 + 0.58 * phase), paint);
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) => old.color != color || old.rings != rings;
}

/// The app's pin (the icon's), as an image.
class BrandPin extends StatelessWidget {
  const BrandPin({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) =>
      Image.asset('assets/icon/splash.png', width: size, height: size, excludeFromSemantics: true);
}

/// The welcome pages' pictures, on the blue gradient: the pin among radar rings (find a lost pet),
/// a photo being compared (I saw an animal), and a heart-paw (help street animals).
enum WelcomeArt { lost, saw, strays }

class WelcomeIllustration extends StatelessWidget {
  const WelcomeIllustration(this.art, {super.key});

  final WelcomeArt art;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: switch (art) {
      WelcomeArt.lost => const RadarRings(color: Colors.white, size: 240, child: BrandPin(size: 150)),
      WelcomeArt.saw => const _PhotoMatch(),
      WelcomeArt.strays => const _HeartPaw(),
    },
  );
}

/// A photo card, tilted, with a match ring on its corner: the app compares what you saw.
class _PhotoMatch extends StatelessWidget {
  const _PhotoMatch();

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 240,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Transform.rotate(
          angle: -0.12,
          child: Container(
            width: 150,
            height: 170,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
        Transform.rotate(
          angle: 0.06,
          child: Container(
            width: 150,
            height: 170,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 24, offset: Offset(0, 10))],
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFDBEAFE), Color(0xFFE0E7FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(child: Icon(LucideIcons.camera, size: 56, color: Brand.blue)),
            ),
          ),
        ),
        const Positioned(
          right: 18,
          bottom: 22,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 12, offset: Offset(0, 4))],
            ),
            child: Padding(
              padding: EdgeInsets.all(6),
              child: CircleAvatar(
                radius: 26,
                backgroundColor: Brand.green,
                child: Icon(LucideIcons.check, size: 30, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// A paw whose pad is a heart, as in the icon, gently bobbing: caring for street animals.
class _HeartPaw extends StatelessWidget {
  const _HeartPaw();

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 240,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.16)),
        ),
        Bob(
          child: Container(
            width: 136,
            height: 136,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Color(0x40000000), blurRadius: 24, offset: Offset(0, 10))],
            ),
            child: const CustomPaint(painter: _HeartPawPainter()),
          ),
        ),
      ],
    ),
  );
}

/// The app icon's paw: four rounded toes and a heart for the main pad.
class _HeartPawPainter extends CustomPainter {
  const _HeartPawPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide * 0.36;
    final toes = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFBBF24), Brand.amber],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromCircle(center: c, radius: r));
    for (final (dx, dy, angle) in [
      (-0.60, -0.22, 0.52),
      (-0.235, -0.53, 0.17),
      (0.235, -0.53, -0.17),
      (0.60, -0.22, -0.52),
    ]) {
      canvas.save();
      canvas.translate(c.dx + dx * r, c.dy + dy * r);
      canvas.rotate(-angle);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 0.30 * r, height: 0.41 * r), toes);
      canvas.restore();
    }
    // The heart: two arcs meeting at a point, the classic curve
    final heart = Path();
    final h = 0.88 * r;
    final top = Offset(c.dx, c.dy + 0.24 * r - h * 0.28);
    heart
      ..moveTo(top.dx, top.dy)
      ..cubicTo(
        top.dx - h * 0.1,
        top.dy - h * 0.38,
        top.dx - h * 0.62,
        top.dy - h * 0.32,
        top.dx - h * 0.56,
        top.dy + h * 0.08,
      )
      ..cubicTo(top.dx - h * 0.52, top.dy + h * 0.36, top.dx - h * 0.2, top.dy + h * 0.52, top.dx, top.dy + h * 0.78)
      ..cubicTo(
        top.dx + h * 0.2,
        top.dy + h * 0.52,
        top.dx + h * 0.52,
        top.dy + h * 0.36,
        top.dx + h * 0.56,
        top.dy + h * 0.08,
      )
      ..cubicTo(top.dx + h * 0.62, top.dy - h * 0.32, top.dx + h * 0.1, top.dy - h * 0.38, top.dx, top.dy)
      ..close();
    canvas.drawPath(
      heart,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFB7185), Color(0xFFE11D48)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(heart.getBounds()),
    );
  }

  @override
  bool shouldRepaint(_HeartPawPainter old) => false;
}
