import 'package:flutter/material.dart';

import 'widgets/common.dart';
import 'widgets/splash_art.dart';

/// Shown while the stored session is read. Continues the Android launch screen: the same pin,
/// now dropping onto Tunis with radar rings and a trail of paw prints (widgets/splash_art.dart).
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SplashArt(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Wordmark(size: 44, color: Colors.white),
            const SizedBox(height: 6),
            Text(
              context.l10n.tagline,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
            ),
          ],
        ),
      ),
    );
  }
}
