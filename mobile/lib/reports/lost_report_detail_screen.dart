import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/models.dart';
import '../api/providers.dart';
import '../auth/auth_controller.dart';
import '../widgets/common.dart';
import '../widgets/location.dart';

/// Matches the API's LOCATION_FUZZ_M: how far the public position may be from the real one.
const _fuzzRadiusM = 300.0;

class LostReportDetailScreen extends ConsumerWidget {
  const LostReportDetailScreen({super.key, required this.id});

  final String id;

  Future<void> _act(BuildContext context, WidgetRef ref, LostReport report, String action) async {
    final l10n = context.l10n;
    final api = ref.read(apiProvider);
    try {
      if (action == 'delete') {
        final ok = await confirm(context, l10n.deleteReportQuestion, l10n.delete);
        if (!ok) return;
        await api.deleteLostReport(report.id);
        if (context.mounted) context.pop();
        return;
      }
      await api.setReportStatus(report.id, ReportStatus.values.byName(action));
      ref.invalidate(lostReportProvider(id));
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final report = ref.watch(lostReportProvider(id));
    return Scaffold(
      appBar: AppBar(
        title: Text(report.value?.name ?? ''),
        actions: [
          if (report.value case final r? when r.isMine)
            PopupMenuButton<String>(
              onSelected: (action) => _act(context, ref, r, action),
              itemBuilder: (_) => [
                if (r.status != ReportStatus.found) PopupMenuItem(value: 'found', child: Text(l10n.markFound)),
                if (r.status != ReportStatus.closed) PopupMenuItem(value: 'closed', child: Text(l10n.closeReport)),
                if (r.status != ReportStatus.open) PopupMenuItem(value: 'open', child: Text(l10n.reopenReport)),
                PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
              ],
            ),
        ],
      ),
      body: switch (report) {
        AsyncData(:final value) => RefreshIndicator(
          onRefresh: () => ref.refresh(lostReportProvider(id).future),
          child: ListView(
            children: [
              PhotoGallery(value.photos, showStatus: value.isMine),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(value.name, style: Theme.of(context).textTheme.headlineSmall)),
                        Chip(label: Text(statusLabel(l10n, value.status))),
                      ],
                    ),
                    InfoRow(Icons.pets, speciesLabel(l10n, value.species)),
                    InfoRow(Icons.schedule, l10n.lastSeenOn(formatDateTime(context, value.lastSeenAt))),
                    if (value.description != null) ...[const SizedBox(height: 8), Text(value.description!)],
                    const SizedBox(height: 16),
                    LocationPreview(
                      value.lastSeen,
                      approximateRadiusM: value.locationIsApproximate ? _fuzzRadiusM : null,
                    ),
                    if (value.locationIsApproximate)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(l10n.approximateArea, style: Theme.of(context).textTheme.bodySmall),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        AsyncError(:final error) => ErrorView(error: error, onRetry: () => ref.invalidate(lostReportProvider(id))),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

Future<bool> confirm(BuildContext context, String question, String action) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(question),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(action)),
        ],
      ),
    ) ??
    false;
