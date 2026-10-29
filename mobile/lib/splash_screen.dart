import 'package:flutter/material.dart';

import 'theme.dart';
import 'widgets/animations.dart';
import 'widgets/common.dart';

/// Shown while the stored session is read. Continues the Android launch screen (same blue).
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: Brand.gradient),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const FadeSlideIn(
                scale: 0.6,
                offset: Offset.zero,
                duration: Duration(milliseconds: 600),
                child: Bob(child: AppLogo(size: 112)),
              ),
              const SizedBox(height: 20),
              FadeSlideIn(index: 3, child: const Wordmark(size: 40, color: Colors.white)),
              const SizedBox(height: 4),
              FadeSlideIn(
                index: 5,
                child: Text(
                  context.l10n.tagline,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
