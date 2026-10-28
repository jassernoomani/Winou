import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/models.dart';
import '../api/providers.dart';
import '../auth/auth_controller.dart';
import '../reports/lost_report_detail_screen.dart' show confirm;
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
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.delete,
              onPressed: () => _delete(context, ref),
            ),
        ],
      ),
      body: switch (sighting) {
        AsyncData(:final value) => RefreshIndicator(
          onRefresh: () => ref.refresh(sightingProvider(id).future),
          child: ListView(
            children: [
              PhotoGallery(value.photos, showStatus: value.isMine),
              Padding(padding: const EdgeInsets.all(16), child: SightingInfo(value)),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InfoRow(Icons.pets, speciesLabel(l10n, sighting.species)),
        InfoRow(Icons.schedule, l10n.seenOn(formatDateTime(context, sighting.seenAt))),
        InfoRow(Icons.healing_outlined, conditionLabel(l10n, sighting.condition)),
        if (sighting.note != null) InfoRow(Icons.notes, sighting.note!),
        const SizedBox(height: 16),
        LocationPreview(sighting.location),
      ],
    );
  }
}
