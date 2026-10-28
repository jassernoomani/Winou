import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../api/models.dart';
import '../auth/auth_controller.dart';
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

  Future<void> _open(String location) async {
    await pushChain(context, location);
    if (mounted) _reload(); // something may have been created, edited or deleted
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.missingPets),
        actions: [
          IconButton(icon: const Icon(Icons.map_outlined), tooltip: l10n.map, onPressed: () => _open('/map')),
          IconButton(icon: const Icon(Icons.person_outline), tooltip: l10n.myActivity, onPressed: () => _open('/me')),
        ],
      ),
      body: Column(
        children: [
          _filters(context),
          if (_loading && _reports.isEmpty) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: RefreshIndicator(onRefresh: _reload, child: _list(context)),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'lost',
            onPressed: () => _open('/lost/new'),
            icon: const Icon(Icons.campaign_outlined),
            label: Text(l10n.reportLostPet),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
            foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'sighting',
            onPressed: () => _open('/sightings/new'),
            icon: const Icon(Icons.photo_camera),
            label: Text(l10n.iSawAnAnimal),
          ),
        ],
      ),
    );
  }

  Widget _filters(BuildContext context) {
    final l10n = context.l10n;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        spacing: 8,
        children: [
          ChoiceChip(
            avatar: const Icon(Icons.near_me_outlined, size: 18),
            label: Text(l10n.nearMe),
            selected: _nearMe,
            onSelected: (_) => _setNearMe(true),
          ),
          ChoiceChip(label: Text(l10n.everywhere), selected: !_nearMe, onSelected: (_) => _setNearMe(false)),
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

  Widget _list(BuildContext context) {
    final l10n = context.l10n;
    Widget message(String text) => ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(32),
          child: Text(text, textAlign: TextAlign.center),
        ),
      ],
    );

    if (_error != null && _reports.isEmpty) {
      return ListView(
        children: [ErrorView(error: _error!, onRetry: _reload)],
      );
    }
    if (_reports.isEmpty) {
      if (_loading) return ListView();
      if (_nearMe && _position == null) return message(l10n.locationOffForNearby);
      return message(_nearMe ? l10n.noMissingPetsNearby : l10n.noMissingPets);
    }
    return ListView.builder(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 160), // room for the buttons
      itemCount: _reports.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, i) => i == _reports.length
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          : _ReportCard(_reports[i], from: _position, onTap: () => _open('/lost/${_reports[i].id}')),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard(this.report, {required this.from, required this.onTap});

  final LostReport report;
  final LatLng? from;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final km = from == null ? null : const Distance().as(LengthUnit.Meter, from!, report.lastSeen) / 1000;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            SizedBox.square(dimension: 104, child: NetworkPhoto(report.photos.firstOrNull?.url)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(report.name, style: text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(speciesLabel(l10n, report.species), style: text.bodyMedium),
                  const SizedBox(height: 4),
                  Text(
                    [
                      l10n.lastSeenOn(formatDateTime(context, report.lastSeenAt)),
                      if (km != null) l10n.kmAway(km < 1 ? '< 1' : km.toStringAsFixed(km < 10 ? 1 : 0)),
                    ].join(' · '),
                    style: text.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.chevron_right)),
          ],
        ),
      ),
    );
  }
}
