import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/models.dart';
import '../api/providers.dart';
import '../sightings/sighting_detail_screen.dart' show SightingInfo;
import '../widgets/common.dart';

/// Your lost pet's photo next to the sighting photo that matched it.
class MatchDetailScreen extends ConsumerWidget {
  const MatchDetailScreen({super.key, required this.id, this.match});

  final String id;
  final Match? match; // passed from the list; loaded otherwise (e.g. from a notification)

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final loaded = match != null
        ? AsyncData(match)
        : ref.watch(myMatchesProvider).whenData((all) => all.where((m) => m.id == id).firstOrNull);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.possibleMatch)),
      body: switch (loaded) {
        AsyncData(value: final m?) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(l10n.possibleMatchFor(m.lostReportName), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(l10n.similarity((m.score * 100).round())),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _LabeledPhoto(l10n.yourPhoto, m.lostPhotoUrl)),
                const SizedBox(width: 8),
                Expanded(child: _LabeledPhoto(l10n.sightingPhoto, m.sightingPhotoUrl)),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              child: Padding(padding: const EdgeInsets.all(12), child: Text(l10n.matchExplanation)),
            ),
            const SizedBox(height: 16),
            SightingInfo(m.sighting),
          ],
        ),
        AsyncData() => Center(child: Text(l10n.matchNotFound)),
        AsyncError(:final error) => ErrorView(error: error, onRetry: () => ref.invalidate(myMatchesProvider)),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _LabeledPhoto extends StatelessWidget {
  const _LabeledPhoto(this.label, this.url);

  final String label;
  final String? url;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(aspectRatio: 1, child: NetworkPhoto(url)),
        ),
      ],
    );
  }
}
