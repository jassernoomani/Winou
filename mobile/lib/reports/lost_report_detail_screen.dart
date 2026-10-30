import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/models.dart';
import '../api/providers.dart';
import '../auth/auth_controller.dart';
import '../theme.dart';
import '../widgets/admin_menu.dart';
import '../widgets/animations.dart';
import '../widgets/common.dart';
import '../widgets/location.dart';
import '../widgets/report_sheet.dart';

/// Matches the API's LOCATION_FUZZ_M: how far the public position may be from the real one.
const _fuzzRadiusM = 300.0;

class LostReportDetailScreen extends ConsumerWidget {
  const LostReportDetailScreen({super.key, required this.id, this.initial});

  final String id;
  final LostReport? initial; // from the list, shown while the fresh copy loads

  Future<void> _act(BuildContext context, WidgetRef ref, LostReport report, String action) async {
    final l10n = context.l10n;
    final api = ref.read(apiProvider);
    try {
      if (action.startsWith('admin:')) {
        final gone = await runAdminAction(
          context,
          ref,
          action,
          ReportTarget.lostReport,
          report.id,
          authorId: report.authorId,
        );
        if (gone && context.mounted) {
          context.pop();
        } else {
          ref.invalidate(lostReportProvider(id));
        }
        return;
      }
      if (action == 'report') {
        if (await reportContent(context, ref, ReportTarget.lostReport, report.id) == true && context.mounted) {
          context.pop(); // hidden: nothing left to see
        }
        return;
      }
      if (action == 'delete') {
        final ok = await confirm(context, l10n.deleteReportQuestion, l10n.delete);
        if (!ok) return;
        await api.deleteLostReport(report.id);
        if (context.mounted) context.pop();
        return;
      }
      if (action == 'found' && !await confirm(context, l10n.gotPetBackQuestion(report.name), l10n.closeCase)) {
        return;
      }
      await api.setReportStatus(report.id, ReportStatus.values.byName(action));
      ref
        ..invalidate(lostReportProvider(id))
        ..invalidate(myMatchesProvider);
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(lostReportProvider(id));
    final report = async.value ?? initial; // the list's copy shows at once, then the fresh one
    final isAdmin = ref.watch(meProvider).value?.isAdmin ?? false;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        leading: const _RoundBack(),
        actions: [
          if (report case final r?)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: CircleAvatar(
                backgroundColor: Colors.black38,
                child: PopupMenuButton<String>(
                  icon: const Icon(LucideIcons.ellipsisVertical, color: Colors.white),
                  onSelected: (action) => _act(context, ref, r, action),
                  tooltip: l10n.more,
                  itemBuilder: (_) => [
                    if (!r.isMine) PopupMenuItem(value: 'report', child: Text(l10n.report)),
                    if (r.isMine) ...[
                      if (r.status != ReportStatus.found) PopupMenuItem(value: 'found', child: Text(l10n.markFound)),
                      if (r.status != ReportStatus.closed)
                        PopupMenuItem(value: 'closed', child: Text(l10n.closeReport)),
                      if (r.status != ReportStatus.open) PopupMenuItem(value: 'open', child: Text(l10n.reopenReport)),
                      PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
                    ],
                    if (isAdmin) ...adminMenuItems(l10n, hidden: r.hidden, mine: r.isMine, authorId: r.authorId),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: switch ((report, async)) {
        (final LostReport value, _) => RefreshIndicator(
          onRefresh: () => ref.refresh(lostReportProvider(id).future),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              PhotoGallery(value.photos, showStatus: value.isMine, heroTag: 'lost-photo-${value.id}'),
              Transform.translate(
                offset: const Offset(0, -24), // the sheet overlaps the photo
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (value.hidden) ...[
                        Note(l10n.hiddenNotice, tone: Tone.neutral, icon: LucideIcons.eyeOff),
                        const SizedBox(height: 12),
                      ],
                      FadeSlideIn(
                        child: Row(
                          children: [
                            Expanded(child: Text(value.name, style: Theme.of(context).textTheme.headlineMedium)),
                            StatusPill(
                              statusLabel(l10n, value.status),
                              tone: reportStatusTone(value.status),
                              icon: reportStatusIcon(value.status),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      FadeSlideIn(
                        index: 1,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Column(
                              children: [
                                InfoRow(LucideIcons.pawPrint, speciesLabel(l10n, value.species)),
                                InfoRow(LucideIcons.clock, l10n.lastSeenOn(formatDateTime(context, value.lastSeenAt))),
                                if (value.description != null) InfoRow(LucideIcons.textAlignStart, value.description!),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (value.isMine && value.status == ReportStatus.open) ...[
                        const SizedBox(height: 12),
                        FadeSlideIn(
                          index: 2,
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(backgroundColor: Brand.green, foregroundColor: Brand.ink),
                              onPressed: () => _act(context, ref, value, 'found'),
                              icon: const Icon(LucideIcons.house),
                              label: Text(l10n.gotPetBack(value.name)),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      FadeSlideIn(
                        index: 3,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: LocationPreview(
                            value.lastSeen,
                            approximateRadiusM: value.locationIsApproximate ? _fuzzRadiusM : null,
                          ),
                        ),
                      ),
                      if (value.locationIsApproximate)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(l10n.approximateArea, style: Theme.of(context).textTheme.bodySmall),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        (_, AsyncError(:final error)) => ErrorView(error: error, onRetry: () => ref.invalidate(lostReportProvider(id))),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

/// A back button that stays readable on top of a photo.
class _RoundBack extends StatelessWidget {
  const _RoundBack();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(8),
    child: CircleAvatar(
      backgroundColor: Colors.black38,
      child: BackButton(color: Colors.white, onPressed: () => Navigator.maybePop(context)),
    ),
  );
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
