import 'dart:math' as math;

import 'package:flutter/material.dart';

/// "Continue with Google", with Google's four-colour G as its brand guidelines ask.
class GoogleButton extends StatelessWidget {
  const GoogleButton({super.key, required this.label, required this.onPressed, this.busy = false});

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: busy ? null : onPressed,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 12,
      children: [
        busy
            ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const SizedBox.square(dimension: 20, child: CustomPaint(painter: _GoogleG())),
        Text(label),
      ],
    ),
  );
}

/// The G: four arcs (red, yellow, green, blue) and the blue bar.
class _GoogleG extends CustomPainter {
  const _GoogleG();

  static const _blue = Color(0xFF4285F4);
  static const _green = Color(0xFF34A853);
  static const _yellow = Color(0xFFFBBC05);
  static const _red = Color(0xFFEA4335);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.2;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    Paint paint(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    double deg(double d) => d * math.pi / 180;
    // Angles from 3 o'clock, clockwise
    canvas
      ..drawArc(rect, deg(-40), deg(-100), false, paint(_red))
      ..drawArc(rect, deg(-140), deg(-80), false, paint(_yellow))
      ..drawArc(rect, deg(140), deg(-95), false, paint(_green))
      ..drawArc(rect, deg(45), deg(-45), false, paint(_blue))
      ..drawLine(
        Offset(size.width * 0.52, size.height / 2),
        Offset(size.width - stroke / 2, size.height / 2),
        paint(_blue)..strokeCap = StrokeCap.butt,
      );
  }

  @override
  bool shouldRepaint(_GoogleG old) => false;
}
