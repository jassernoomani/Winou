import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/models.dart';
import '../api/providers.dart';
import '../auth/auth_controller.dart';
import '../theme.dart';
import '../widgets/animations.dart';
import '../widgets/common.dart';

/// Tabs: matches for my lost pets, my lost reports, my sightings.
class MyActivityScreen extends ConsumerWidget {
  const MyActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.myActivity),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              tooltip: l10n.signOut,
              onPressed: () => ref.read(authProvider.notifier).logout(),
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.tabMatches),
              Tab(text: l10n.tabMyLostPets),
              Tab(text: l10n.tabMySightings),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _AsyncList<Match>(
              provider: myMatchesProvider,
              empty: l10n.noMatches,
              emptyIcon: Icons.image_search_rounded,
              itemBuilder: (context, m) => ListTile(
                leading: _Thumb(m.sightingPhotoUrl),
                title: Text(l10n.possibleMatchFor(m.lostReportName)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      if (m.reportStatus != ReportStatus.open)
                        StatusPill(
                          statusLabel(l10n, m.reportStatus),
                          tone: reportStatusTone(m.reportStatus),
                          icon: reportStatusIcon(m.reportStatus),
                        )
                      else if (m.status == MatchStatus.confirmed)
                        StatusPill(l10n.matchStatusConfirmed, tone: Tone.found, icon: Icons.check_rounded)
                      else
                        StatusPill('${(m.score * 100).round()}%', tone: Tone.info, icon: Icons.auto_awesome),
                      const SizedBox(width: 8),
                      Flexible(child: Text(timeAgo(l10n, m.sighting.seenAt), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/matches/${m.id}', extra: m),
              ),
            ),
            _AsyncList<LostReport>(
              provider: myLostReportsProvider,
              empty: l10n.noLostReports,
              emptyIcon: Icons.campaign_rounded,
              itemBuilder: (context, r) => ListTile(
                leading: _Thumb(r.photos.firstOrNull?.url),
                title: Text(r.name),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      StatusPill(
                        statusLabel(l10n, r.status),
                        tone: reportStatusTone(r.status),
                        icon: reportStatusIcon(r.status),
                      ),
                      const SizedBox(width: 8),
                      Flexible(child: Text(timeAgo(l10n, r.lastSeenAt), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _openAndRefresh(context, ref, '/lost/${r.id}', myLostReportsProvider),
              ),
            ),
            _AsyncList<Sighting>(
              provider: mySightingsProvider,
              empty: l10n.noSightings,
              emptyIcon: Icons.photo_camera_rounded,
              itemBuilder: (context, s) => ListTile(
                leading: _Thumb(s.photos.firstOrNull?.url),
                title: Text(
                  s.isStray
                      ? l10n.strayOf(speciesLabel(l10n, s.species))
                      : l10n.sightingOf(speciesLabel(l10n, s.species)),
                ),
                subtitle: Text(timeAgo(l10n, s.seenAt)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _openAndRefresh(context, ref, '/sightings/${s.id}', mySightingsProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAndRefresh(
    BuildContext context,
    WidgetRef ref,
    String location,
    FutureProvider<Object?> provider,
  ) async {
    await context.push(location);
    ref.invalidate(provider); // may have been edited or deleted
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb(this.url);

  final String? url;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: SizedBox.square(dimension: 56, child: NetworkPhoto(url)),
  );
}

class _AsyncList<T> extends ConsumerWidget {
  const _AsyncList({required this.provider, required this.empty, required this.emptyIcon, required this.itemBuilder});

  final FutureProvider<List<T>> provider;
  final String empty;
  final IconData emptyIcon;
  final Widget Function(BuildContext, T) itemBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(provider)) {
      AsyncData(:final value) => RefreshIndicator(
        onRefresh: () => ref.refresh(provider.future),
        child: value.isEmpty
            ? ListView(
                children: [
                  FadeSlideIn(
                    child: EmptyState(icon: emptyIcon, text: empty),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                itemCount: value.length,
                itemBuilder: (context, i) => FadeSlideIn(
                  index: i,
                  child: Card(clipBehavior: Clip.antiAlias, child: itemBuilder(context, value[i])),
                ),
              ),
      ),
      AsyncError(:final error) => ErrorView(error: error, onRetry: () => ref.invalidate(provider)),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}
