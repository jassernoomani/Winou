import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/models.dart';
import '../api/providers.dart';
import '../auth/auth_controller.dart';
import '../theme.dart';
import '../widgets/animations.dart';
import '../widgets/common.dart';
import '../widgets/location.dart';

const _pageSize = 20;

/// Home screen: open lost reports, most recently seen first, near the user by default.
/// The map is one tap away in the app bar.
class LostFeedScreen extends ConsumerStatefulWidget {
  const LostFeedScreen({super.key});

  @override
  ConsumerState<LostFeedScreen> createState() => _LostFeedScreenState();
}

class _LostFeedScreenState extends ConsumerState<LostFeedScreen> {
  final _scroll = ScrollController();
  List<LostReport> _reports = [];
  bool _loading = false;
  bool _hasMore = true;
  Object? _error;
  int _request = 0; // ignore answers to outdated requests

  LatLng? _position;
  bool _nearMe = true;
  Species? _species; // null = all

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 400) _loadMore();
    });
    _locateThenLoad();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _locateThenLoad() async {
    setState(() => _loading = true);
    final position = await currentPosition();
    if (!mounted) return;
    _position = position == null ? null : toLatLng(position);
    await _reload();
  }

  Future<void> _reload() async {
    _reports = [];
    _hasMore = true;
    _error = null;
    await _fetch();
  }

  Future<void> _loadMore() async {
    if (!_loading && _hasMore && _error == null) await _fetch();
  }

  Future<void> _fetch() async {
    final request = ++_request;
    setState(() => _loading = true);
    try {
      final page = await ref
          .read(apiProvider)
          .lostReports(near: _nearMe ? _position : null, species: _species, limit: _pageSize, offset: _reports.length);
      if (!mounted || request != _request) return;
      setState(() {
        _reports = [..._reports, ...page];
        _hasMore = page.length == _pageSize;
      });
    } catch (e) {
      if (mounted && request == _request) setState(() => _error = e);
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _setNearMe(bool nearMe) async {
    setState(() => _nearMe = nearMe);
    if (nearMe && _position == null) {
      await _locateThenLoad(); // location may have been turned on since
    } else {
      await _reload();
    }
  }

  Future<void> _open(String location, {Object? extra}) async {
    await pushChain(context, location, extra: extra);
    if (!mounted) return;
    ref.invalidate(conversationsProvider); // unread count
    _reload(); // something may have been created, edited or deleted
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _reload,
        edgeOffset: 160,
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _header(context)),
            SliverToBoxAdapter(child: _filters(context)),
            ..._list(context),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FadeSlideIn(
            index: 4,
            offset: const Offset(0.3, 0),
            child: GradientFab(
              gradient: Brand.lostGradient,
              icon: LucideIcons.megaphone,
              label: l10n.reportLostPet,
              onPressed: () => _open('/lost/new'),
            ),
          ),
          const SizedBox(height: 12),
          FadeSlideIn(
            index: 6,
            offset: const Offset(0.3, 0),
            child: GradientFab(
              gradient: Brand.sightingGradient,
              icon: LucideIcons.camera,
              label: l10n.iSawAnAnimal,
              onPressed: () => _open('/sightings/new'),
            ),
          ),
        ],
      ),
    );
  }

  /// Blue header: title, actions and how many pets are missing.
  Widget _header(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    return Container(
      decoration: const BoxDecoration(
        gradient: Brand.gradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 8, 12, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppLogo(size: 36),
              const SizedBox(width: 10),
              const Expanded(child: Wordmark(size: 26, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 20),
          Text(l10n.helpBringThemHome, style: text.headlineSmall?.copyWith(color: Colors.white)),
          const SizedBox(height: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              (_loading || _error != null) && _reports.isEmpty
                  ? ' '
                  : _hasMore
                  ? l10n.missingCountMore(_reports.length)
                  : l10n.missingCount(_reports.length),
              key: ValueKey(_reports.length),
              style: text.bodyLarge?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filters(BuildContext context) {
    final l10n = context.l10n;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        spacing: 8,
        children: [
          ChoiceChip(
            avatar: const Icon(LucideIcons.navigation, size: 18),
            label: Text(l10n.nearMe),
            selected: _nearMe,
            onSelected: (_) => _setNearMe(true),
          ),
          ChoiceChip(
            avatar: const Icon(LucideIcons.globe, size: 18),
            label: Text(l10n.everywhere),
            selected: !_nearMe,
            onSelected: (_) => _setNearMe(false),
          ),
          const SizedBox(height: 24, child: VerticalDivider()),
          for (final species in [null, Species.dog, Species.cat])
            ChoiceChip(
              label: Text(species == null ? l10n.allSpecies : speciesLabel(l10n, species)),
              selected: _species == species,
              onSelected: (_) {
                setState(() => _species = species);
                _reload();
              },
            ),
        ],
      ),
    );
  }

  List<Widget> _list(BuildContext context) {
    final l10n = context.l10n;
    Widget message(IconData icon, String text) => SliverToBoxAdapter(
      child: FadeSlideIn(
        child: EmptyState(icon: icon, text: text),
      ),
    );

    if (_error != null && _reports.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: ErrorView(error: _error!, onRetry: _reload),
        ),
      ];
    }
    if (_reports.isEmpty) {
      if (_loading) {
        return [
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
            sliver: SliverToBoxAdapter(child: Column(children: [_SkeletonCard(), _SkeletonCard()])),
          ),
        ];
      }
      if (_nearMe && _position == null) return [message(LucideIcons.mapPinOff, l10n.locationOffForNearby)];
      return [message(LucideIcons.heart, _nearMe ? l10n.noMissingPetsNearby : l10n.noMissingPets)];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 160), // room for the buttons
        sliver: SliverList.builder(
          itemCount: _reports.length + (_hasMore ? 1 : 0),
          itemBuilder: (context, i) => i == _reports.length
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              : FadeSlideIn(
                  key: ValueKey(_reports[i].id),
                  index: i,
                  child: _ReportCard(
                    _reports[i],
                    from: _position,
                    onTap: () => _open('/lost/${_reports[i].id}', extra: _reports[i]),
                  ),
                ),
        ),
      ),
    ];
  }
}

/// A pet card's outline while the list loads, gently pulsing.
class _SkeletonCard extends StatefulWidget {
  const _SkeletonCard();

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    Widget bar(double widthFactor) => FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        height: 10,
        decoration: BoxDecoration(color: tokens.tonal, borderRadius: BorderRadius.circular(5)),
      ),
    );
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.55).animate(_controller),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: tokens.card, borderRadius: BorderRadius.circular(24)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 120, color: tokens.tonal),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(spacing: 10, children: [bar(0.6), bar(0.4), bar(0.85)]),
            ),
          ],
        ),
      ),
    );
  }
}

/// The guide's pet card: photo first, then name and status, where and when, and a few words.
class _ReportCard extends StatelessWidget {
  const _ReportCard(this.report, {required this.from, required this.onTap});

  final LostReport report;
  final LatLng? from;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final km = from == null ? null : const Distance().as(LengthUnit.Meter, from!, report.lastSeen) / 1000;
    Widget meta(IconData icon, String text) => Row(
      spacing: 6,
      children: [
        Icon(icon, size: 16, color: tokens.muted),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 13, color: tokens.muted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(color: tokens.card, borderRadius: BorderRadius.circular(24), boxShadow: cardShadow),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 168,
                  child: Hero(tag: 'lost-photo-${report.id}', child: NetworkPhoto(report.photos.firstOrNull?.url)),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 10,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              report.name,
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatusPill(
                            statusLabel(l10n, report.status),
                            tone: reportStatusTone(report.status),
                            icon: reportStatusIcon(report.status),
                          ),
                        ],
                      ),
                      meta(
                        LucideIcons.mapPin,
                        [
                          speciesLabel(l10n, report.species),
                          if (km != null) l10n.kmAway(km < 1 ? '< 1' : km.toStringAsFixed(km < 10 ? 1 : 0)),
                        ].join(' · '),
                      ),
                      meta(LucideIcons.clock, l10n.seenAgo(timeAgo(l10n, report.lastSeenAt))),
                      if (report.description case final description? when description.trim().isNotEmpty)
                        Text(
                          description.trim(),
                          textDirection: textDirectionOf(description),
                          style: const TextStyle(fontSize: 14, height: 1.4),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
