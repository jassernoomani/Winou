import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/models.dart';
import '../api/providers.dart';
import '../auth/auth_controller.dart';
import '../reports/lost_report_detail_screen.dart' show confirm;
import '../sightings/sighting_detail_screen.dart' show SightingInfo;
import '../theme.dart';
import '../widgets/animations.dart';
import '../widgets/common.dart';
import '../widgets/photo_viewer.dart';

/// Your lost pet's photo next to the sighting photo that matched it. Two steps close the case:
/// "that's my pet" (tells the finder, the search goes on), then "I got my pet back".
class MatchDetailScreen extends ConsumerStatefulWidget {
  const MatchDetailScreen({super.key, required this.id, this.match});

  final String id;
  final Match? match; // passed from the list; loaded otherwise (e.g. from a notification)

  @override
  ConsumerState<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends ConsumerState<MatchDetailScreen> {
  Match? _updated; // after an action here
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setStatus(Match match, MatchStatus status) => _run(() async {
    final api = ref.read(apiProvider);
    final updated = await api.setMatchStatus(match.id, status);
    ref.invalidate(myMatchesProvider);
    if (!mounted) return;
    if (status != MatchStatus.rejected) {
      setState(() => _updated = updated);
      return;
    }
    final l10n = context.l10n;
    final container = ProviderScope.containerOf(context, listen: false); // outlives this screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.matchHidden),
        duration: const Duration(seconds: 8),
        persist: false,
        action: SnackBarAction(
          label: l10n.undo,
          onPressed: () async {
            await api.setMatchStatus(match.id, MatchStatus.pending);
            container.invalidate(myMatchesProvider);
          },
        ),
      ),
    );
    context.pop();
  });

  Future<void> _petBack(Match match) async {
    final l10n = context.l10n;
    if (!await confirm(context, l10n.gotPetBackQuestion(match.lostReportName), l10n.closeCase)) return;
    await _run(() async {
      await ref.read(apiProvider).setReportStatus(match.lostReportId, ReportStatus.found);
      final all = await ref.refresh(myMatchesProvider.future);
      if (mounted) setState(() => _updated = all.where((m) => m.id == match.id).firstOrNull ?? _updated);
    });
  }

  Future<void> _openConversation(Match match) => _run(() async {
    final conversation = await ref.read(apiProvider).startConversation(match.id);
    if (mounted) await context.push('/conversations/${conversation.id}');
    ref.invalidate(myMatchesProvider);
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final given = _updated ?? widget.match;
    final loaded = given != null
        ? AsyncData(given)
        : ref.watch(myMatchesProvider).whenData((all) => all.where((m) => m.id == widget.id).firstOrNull);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.possibleMatch)),
      body: switch (loaded) {
        AsyncData(value: final m?) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FadeSlideIn(
              child: Text(l10n.possibleMatchFor(m.lostReportName), style: Theme.of(context).textTheme.headlineSmall),
            ),
            const SizedBox(height: 12),
            // The guide's match card: the score is a signal, not a certainty
            FadeSlideIn(
              index: 1,
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    spacing: 16,
                    children: [
                      // A finder's match has a score only once the model compared its photo
                      if (m.score > 0)
                        SimilarityRing(m.score, size: 96)
                      else
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: context.tokens.tone(Tone.found).$1),
                          child: Icon(LucideIcons.eye, size: 40, color: context.tokens.tone(Tone.found).$2),
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 6,
                          children: [
                            Text(
                              m.byFinder ? l10n.finderMatchTitle(m.lostReportName) : l10n.possibleVisualMatch,
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, height: 1.2),
                            ),
                            Text(
                              m.byFinder ? l10n.finderMatchBody : l10n.notConfirmedIdentity,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FadeSlideIn(
              index: 2,
              child: Row(
                children: [
                  Expanded(child: _LabeledPhoto(l10n.yourPhoto, m.lostPhotoUrl)),
                  const SizedBox(width: 10),
                  Expanded(child: _LabeledPhoto(l10n.sightingPhoto, m.sightingPhotoUrl)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FadeSlideIn(
              index: 2,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                switchInCurve: Curves.easeOutCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SizeTransition(sizeFactor: animation, alignment: Alignment.topCenter, child: child),
                ),
                child: Column(
                  key: ValueKey((m.status, m.reportStatus, m.conversationId != null)),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _decision(context, m),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FadeSlideIn(index: 3, child: SightingInfo(m.sighting)),
          ],
        ),
        AsyncData() => Center(child: Text(l10n.matchNotFound)),
        AsyncError(:final error) => ErrorView(error: error, onRetry: () => ref.invalidate(myMatchesProvider)),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  List<Widget> _decision(BuildContext context, Match m) {
    final l10n = context.l10n;
    final caseOpen = m.reportStatus == ReportStatus.open;
    final chat = OutlinedButton.icon(
      onPressed: _busy ? null : () => _openConversation(m),
      icon: const Icon(LucideIcons.messageCircle),
      label: Text(m.conversationId == null ? l10n.messageFinder : l10n.openConversation),
    );
    return [
      if (!caseOpen)
        Note(l10n.petBackHome(m.lostReportName), tone: Tone.found, icon: LucideIcons.house)
      else if (m.status == MatchStatus.confirmed)
        Note(l10n.matchConfirmedInfo(m.lostReportName), tone: Tone.found, icon: LucideIcons.circleCheck)
      else
        Note(m.byFinder ? l10n.finderMatchTip : l10n.matchExplanation, tone: Tone.info, icon: LucideIcons.lightbulb),
      const SizedBox(height: 12),
      if (caseOpen && m.status == MatchStatus.pending) ...[
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
                onPressed: _busy ? null : () => _setStatus(m, MatchStatus.rejected),
                child: Text(l10n.notMyPet),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
                onPressed: _busy ? null : () => _setStatus(m, MatchStatus.confirmed),
                icon: const Icon(LucideIcons.heart),
                label: Text(l10n.thatsMyPet),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
      if (caseOpen && m.status == MatchStatus.confirmed) ...[
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: Brand.green, foregroundColor: Brand.ink),
          onPressed: _busy ? null : () => _petBack(m),
          icon: const Icon(LucideIcons.house),
          label: Text(l10n.gotPetBack(m.lostReportName)),
        ),
        const SizedBox(height: 8),
      ],
      chat,
    ];
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
          borderRadius: BorderRadius.circular(20),
          child: AspectRatio(aspectRatio: 1, child: TappablePhoto(url)),
        ),
      ],
    );
  }
}
