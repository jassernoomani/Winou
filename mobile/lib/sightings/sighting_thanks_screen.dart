import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/models.dart';
import '../api/providers.dart';
import '../theme.dart';
import '../widgets/animations.dart';
import '../widgets/common.dart';

/// After posting a sighting: thanks, what happens next, and the sighting as it now shows on the map.
class SightingThanksScreen extends ConsumerWidget {
  const SightingThanksScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final (foundBackground, foundForeground) = tokens.tone(Tone.found);
    final sighting = ref.watch(sightingProvider(id)).value;
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          FadeSlideIn(
            scale: 0.6,
            offset: Offset.zero,
            child: Center(
              child: Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(color: foundBackground, shape: BoxShape.circle),
                child: Icon(LucideIcons.heart, size: 52, color: foundForeground),
              ),
            ),
          ),
          const SizedBox(height: 24),
          FadeSlideIn(
            index: 1,
            child: Text(
              l10n.thanksTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: 12),
          FadeSlideIn(
            index: 2,
            child: Text(
              l10n.thanksBody,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: tokens.muted),
            ),
          ),
          const SizedBox(height: 24),
          if (sighting != null) FadeSlideIn(index: 3, child: _SummaryCard(sighting)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: OutlinedButton(onPressed: () => context.go('/'), child: Text(l10n.backToMissingPets)),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard(this.sighting);

  final Sighting sighting;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final species = speciesLabel(l10n, sighting.species);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: tokens.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          spacing: 12,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox.square(dimension: 88, child: NetworkPhoto(sighting.photos.firstOrNull?.url)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  _TypeLabel(sighting.isStray ? l10n.typeStray : l10n.typeSighting, stray: sighting.isStray),
                  Text(
                    sighting.isStray ? l10n.strayOf(species) : l10n.sightingOf(species),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '${timeAgo(l10n, sighting.seenAt)} · ${conditionLabel(l10n, sighting.condition)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small coloured dot and the type, as in the map legend.
class _TypeLabel extends StatelessWidget {
  const _TypeLabel(this.text, {required this.stray});

  final String text;
  final bool stray;

  @override
  Widget build(BuildContext context) => Row(
    spacing: 6,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: stray ? Brand.amber : Brand.blue, shape: BoxShape.circle),
      ),
      Text(text, style: Theme.of(context).textTheme.labelMedium),
    ],
  );
}
