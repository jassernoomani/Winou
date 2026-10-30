import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../api/providers.dart';
import '../theme.dart';
import '../widgets/animations.dart';
import '../widgets/common.dart';

/// After "I got my pet back": a moment to celebrate, with confetti, the pet's photo, a thank-you,
/// and the good news to share.
class ReunionScreen extends ConsumerStatefulWidget {
  const ReunionScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<ReunionScreen> createState() => _ReunionScreenState();
}

class _ReunionScreenState extends ConsumerState<ReunionScreen> with SingleTickerProviderStateMixin {
  late final _confetti = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // No falling confetti for people who asked their phone for less motion
    if (!MediaQuery.disableAnimationsOf(context) && !_confetti.isAnimating && _confetti.value == 0) {
      _confetti.forward();
    }
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  void _done() => context.canPop() ? context.pop() : context.go('/');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final report = ref.watch(lostReportProvider(widget.id)).value;
    final name = report?.name ?? '';
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              child: Column(
                children: [
                  const Spacer(),
                  FadeSlideIn(
                    scale: 0.6,
                    offset: Offset.zero,
                    duration: const Duration(milliseconds: 600),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Brand.green),
                      child: ClipOval(
                        child: SizedBox.square(dimension: 168, child: NetworkPhoto(report?.photos.firstOrNull?.url)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  FadeSlideIn(
                    index: 2,
                    child: Text(
                      l10n.reunionTitle(name),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FadeSlideIn(
                    index: 3,
                    child: Text(
                      l10n.reunionBody,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(color: context.tokens.muted, height: 1.45),
                    ),
                  ),
                  const Spacer(),
                  FadeSlideIn(
                    index: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 8,
                      children: [
                        FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: Brand.green, foregroundColor: Brand.ink),
                          onPressed: report == null
                              ? null
                              : () => SharePlus.instance.share(
                                  ShareParams(
                                    text: l10n.reunionShareText(name, speciesLabel(l10n, report.species).toLowerCase()),
                                  ),
                                ),
                          icon: const Icon(LucideIcons.partyPopper),
                          label: Text(l10n.shareGoodNews),
                        ),
                        TextButton(onPressed: _done, child: Text(l10n.done)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _confetti,
              builder: (_, _) => CustomPaint(size: Size.infinite, painter: _Confetti(_confetti.value)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paper bits in the brand's colours falling and turning, fading out at the end.
class _Confetti extends CustomPainter {
  _Confetti(this.t);

  final double t; // 0 to 1

  static const _colors = [Brand.blue, Brand.coral, Brand.green, Brand.amber, Brand.sky, Brand.indigo];
  static final _pieces = List.generate(90, (i) {
    final random = math.Random(i * 7919);
    return (
      x: random.nextDouble(),
      delay: random.nextDouble() * 0.35,
      speed: 0.7 + random.nextDouble() * 0.6,
      drift: (random.nextDouble() - 0.5) * 0.25,
      spin: (random.nextDouble() - 0.5) * 14,
      size: 6 + random.nextDouble() * 6,
      color: _colors[i % _colors.length],
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (t == 0 || t == 1) return;
    final fade = t > 0.8 ? (1 - t) / 0.2 : 1.0;
    final paint = Paint();
    for (final p in _pieces) {
      final progress = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0) * p.speed;
      if (progress <= 0) continue;
      final y = -20 + progress * (size.height + 40);
      final x = (p.x + p.drift * progress + math.sin(progress * 9 + p.x * 6) * 0.03) * size.width;
      paint.color = p.color.withValues(alpha: fade);
      canvas
        ..save()
        ..translate(x, y)
        ..rotate(progress * p.spin)
        ..drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5),
            const Radius.circular(1.5),
          ),
          paint,
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_Confetti old) => old.t != t;
}
