import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/models.dart';
import '../api/providers.dart';
import '../auth/auth_controller.dart';
import '../reports/lost_report_detail_screen.dart' show confirm;
import '../theme.dart';
import '../widgets/animations.dart';
import '../widgets/common.dart';
import '../widgets/location.dart';

class SightingDetailScreen extends ConsumerWidget {
  const SightingDetailScreen({super.key, required this.id});

  final String id;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    if (!await confirm(context, l10n.deleteSightingQuestion, l10n.delete)) return;
    try {
      await ref.read(apiProvider).deleteSighting(id);
      if (context.mounted) context.pop();
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final sighting = ref.watch(sightingProvider(id));
    return Scaffold(
      appBar: AppBar(
        title: Text(sighting.value?.isStray ?? false ? l10n.typeStray : l10n.typeSighting),
        actions: [
          if (sighting.value?.isMine ?? false)
            IconButton(
              icon: const Icon(LucideIcons.trash2),
              tooltip: l10n.delete,
              onPressed: () => _delete(context, ref),
            ),
        ],
      ),
      body: switch (sighting) {
        AsyncData(:final value) => RefreshIndicator(
          onRefresh: () => ref.refresh(sightingProvider(id).future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: PhotoGallery(value.photos, showStatus: value.isMine),
              ),
              const SizedBox(height: 16),
              FadeSlideIn(child: SightingInfo(value)),
            ],
          ),
        ),
        AsyncError(:final error) => ErrorView(error: error, onRetry: () => ref.invalidate(sightingProvider(id))),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

/// Species, date, condition, note and map of a sighting (also used on the match screen).
class SightingInfo extends StatelessWidget {
  const SightingInfo(this.sighting, {super.key});

  final Sighting sighting;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final condition = sighting.condition;
    final conditionTone = switch (condition) {
      Condition.healthy => Tone.found,
      Condition.injured => Tone.injured,
      Condition.needsHelp => Tone.stray,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusPill(
              sighting.isStray ? l10n.typeStray : l10n.typeSighting,
              tone: sighting.isStray ? Tone.stray : Tone.info,
              icon: sighting.isStray ? LucideIcons.pawPrint : LucideIcons.eye,
            ),
            StatusPill(conditionLabel(l10n, condition), tone: conditionTone, icon: LucideIcons.heartPulse),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                InfoRow(LucideIcons.pawPrint, speciesLabel(l10n, sighting.species)),
                InfoRow(LucideIcons.clock, l10n.seenOn(formatDateTime(context, sighting.seenAt))),
                if (sighting.note != null) InfoRow(LucideIcons.textAlignStart, sighting.note!),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ClipRRect(borderRadius: BorderRadius.circular(20), child: LocationPreview(sighting.location)),
      ],
    );
  }
}
