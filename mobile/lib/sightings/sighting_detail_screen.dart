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
import '../widgets/report_sheet.dart';

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
            )
          else if (sighting.value != null)
            PopupMenuButton<void>(
              icon: const Icon(LucideIcons.ellipsisVertical),
              tooltip: l10n.more,
              itemBuilder: (_) => [
                PopupMenuItem(
                  onTap: () async {
                    if (await reportContent(context, ref, ReportTarget.sighting, id) == true && context.mounted) {
                      context.pop(); // hidden: nothing left to see
                    }
                  },
                  child: Text(l10n.report),
                ),
              ],
            ),
        ],
      ),
      body: switch (sighting) {
        AsyncData(:final value) => RefreshIndicator(
          onRefresh: () => ref.refresh(sightingProvider(id).future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              if (value.hidden) ...[
                Note(l10n.hiddenNotice, tone: Tone.neutral, icon: LucideIcons.eyeOff),
                const SizedBox(height: 12),
              ],
              if (value.needsHelp) ...[
                Note(
                  value.condition == Condition.injured ? l10n.injuredBanner : l10n.needsHelpBanner,
                  tone: Tone.injured,
                  icon: LucideIcons.heartPulse,
                ),
                const SizedBox(height: 12),
              ],
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: PhotoGallery(value.photos, showStatus: value.isMine),
              ),
              if (value.isStray) ...[const SizedBox(height: 16), FadeSlideIn(child: _StrayStatusCard(value))],
              const SizedBox(height: 16),
              FadeSlideIn(index: 1, child: SightingInfo(value)),
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

/// What became of a stray, and the buttons to update it. "Still around" is worth pressing even when
/// nothing changed: it keeps the animal on the map.
class _StrayStatusCard extends ConsumerStatefulWidget {
  const _StrayStatusCard(this.sighting);

  final Sighting sighting;

  @override
  ConsumerState<_StrayStatusCard> createState() => _StrayStatusCardState();
}

class _StrayStatusCardState extends ConsumerState<_StrayStatusCard> {
  bool _busy = false;

  Future<void> _set(StrayStatus status) async {
    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).setStrayStatus(widget.sighting.id, status);
      ref.invalidate(sightingProvider(widget.sighting.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.strayUpdated)));
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final s = widget.sighting;
    final updated = s.strayStatusAt ?? s.seenAt;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 10,
          children: [
            Text(l10n.strayStatusTitle, style: Theme.of(context).textTheme.titleMedium),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StatusPill(
                  strayStatusLabel(l10n, s.strayStatus),
                  tone: strayStatusTone(s.strayStatus),
                  icon: strayStatusIcon(s.strayStatus),
                ),
                Text(timeAgo(l10n, updated), style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            if (s.helpedBy case final association?)
              Row(
                spacing: 6,
                children: [
                  Icon(LucideIcons.badgeCheck, size: 18, color: context.tokens.accent),
                  Expanded(child: Text(l10n.helpedBy(association))),
                ],
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final status in StrayStatus.values)
                  ChoiceChip(
                    label: Text(strayStatusLabel(l10n, status)),
                    selected: s.strayStatus == status,
                    // "Still around" again is allowed: it refreshes the date
                    onSelected: _busy || (s.strayStatus == status && status != StrayStatus.around)
                        ? null
                        : (_) => _set(status),
                  ),
              ],
            ),
            Text(l10n.strayAroundHelp, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
