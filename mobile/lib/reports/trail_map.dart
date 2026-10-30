import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/models.dart';
import '../auth/auth_controller.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/location.dart';

final trailProvider = FutureProvider.autoDispose.family<List<TrailPoint>, String>(
  (ref, id) => ref.watch(apiProvider).trail(id),
);

/// The owner's map of where their pet may have been seen: where it went missing (the flag), then
/// each matched sighting, numbered oldest first. Nothing shows until there is a sighting.
class TrailSection extends ConsumerWidget {
  const TrailSection(this.report, {super.key});

  final LostReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final trail = ref.watch(trailProvider(report.id)).value;
    if (trail == null || trail.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(l10n.trailTitle(report.name), style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(l10n.trailHint(report.name), style: theme.textTheme.bodySmall),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: 240,
            child: FlutterMap(
              options: MapOptions(
                initialCameraFit: CameraFit.coordinates(
                  coordinates: [report.lastSeen, for (final p in trail) p.location],
                  padding: const EdgeInsets.all(44),
                  maxZoom: 16,
                ),
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
              ),
              children: [
                osmTiles(context),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [report.lastSeen, for (final p in trail) p.location],
                      color: Brand.blue.withValues(alpha: 0.7),
                      strokeWidth: 3,
                      pattern: StrokePattern.dashed(segments: const [8, 6]),
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: report.lastSeen,
                      width: 34,
                      height: 34,
                      child: const _Dot(
                        color: Brand.coral,
                        child: Icon(LucideIcons.flag, size: 16, color: Colors.white),
                      ),
                    ),
                    for (final (i, p) in trail.indexed)
                      Marker(
                        point: p.location,
                        width: 34,
                        height: 34,
                        child: GestureDetector(
                          onTap: () => context.push('/matches/${p.matchId}'),
                          child: _Dot(
                            color: _color(p),
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                osmAttribution(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final (i, p) in trail.indexed)
                ListTile(
                  dense: true,
                  leading: SizedBox.square(
                    dimension: 30,
                    child: _Dot(
                      color: _color(p),
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  title: Text(formatDateTime(context, p.seenAt)),
                  subtitle: Text(
                    [
                      p.status == MatchStatus.confirmed
                          ? l10n.trailConfirmed
                          : p.byFinder
                          ? l10n.trailReportedAsYours
                          : l10n.trailSimilar,
                      if (p.inCare) l10n.keptSafe,
                    ].join(' · '),
                  ),
                  trailing: const ForwardIcon(),
                  onTap: () => context.push('/matches/${p.matchId}'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static Color _color(TrailPoint p) => p.status == MatchStatus.confirmed || p.inCare ? Brand.green : Brand.blue;
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 2),
      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
    ),
    child: Center(child: child),
  );
}
