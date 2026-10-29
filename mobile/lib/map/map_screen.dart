import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/models.dart';
import '../auth/auth_controller.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';
import '../widgets/animations.dart';
import '../widgets/common.dart';
import '../widgets/location.dart';

/// What the map shows. [sinceDays] null = any date.
class MapFilters {
  const MapFilters({
    this.types = const {MapItemType.lost, MapItemType.sighting, MapItemType.stray},
    this.species = const {},
    this.conditions = const {},
    this.sinceDays = 30,
  });

  final Set<MapItemType> types;
  final Set<Species> species; // empty = all
  final Set<Condition> conditions; // empty = all
  final int? sinceDays;

  MapFilters copyWith({
    Set<MapItemType>? types,
    Set<Species>? species,
    Set<Condition>? conditions,
    int? Function()? sinceDays,
  }) => MapFilters(
    types: types ?? this.types,
    species: species ?? this.species,
    conditions: conditions ?? this.conditions,
    sinceDays: sinceDays != null ? sinceDays() : this.sinceDays,
  );
}

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _map = MapController();
  MapFilters _filters = const MapFilters();
  List<MapItem> _items = [];
  bool _loading = false;
  Timer? _debounce;
  int _request = 0; // ignore answers to outdated requests

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _centerOnMe({double zoom = 15}) async {
    final position = await currentPosition();
    if (position != null && mounted) _map.move(toLatLng(position), zoom);
  }

  void _scheduleLoad() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  Future<void> _load() async {
    if (_filters.types.isEmpty) {
      setState(() => _items = []);
      return;
    }
    final bounds = _map.camera.visibleBounds;
    final request = ++_request;
    setState(() => _loading = true);
    try {
      final items = await ref
          .read(apiProvider)
          .map(
            west: bounds.west.clamp(-180, 180),
            south: bounds.south.clamp(-90, 90),
            east: bounds.east.clamp(-180, 180),
            north: bounds.north.clamp(-90, 90),
            types: _filters.types,
            species: _filters.species,
            conditions: _filters.conditions,
            since: _filters.sinceDays == null ? null : DateTime.now().subtract(Duration(days: _filters.sinceDays!)),
          );
      int urgency(MapItem item) => item.condition == null || item.condition == Condition.healthy ? 0 : 1;
      items.sort((a, b) => urgency(a).compareTo(urgency(b))); // stable: newest-first within each group
      if (mounted && request == _request) setState(() => _items = items);
    } catch (e) {
      if (mounted && request == _request) showError(context, e);
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _editFilters() async {
    final result = await showModalBottomSheet<MapFilters>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FilterSheet(initial: _filters),
    );
    if (result != null) {
      setState(() => _filters = result);
      _load();
    }
  }

  Future<void> _open(String location) async {
    await pushChain(context, location);
    _load(); // something may have been created, edited or deleted
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.map),
        bottom: _loading
            ? const PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator(minHeight: 2))
            : null,
        actions: [
          IconButton(icon: const Icon(LucideIcons.slidersHorizontal), tooltip: l10n.filters, onPressed: _editFilters),
          IconButton(icon: const Icon(LucideIcons.user), tooltip: l10n.myActivity, onPressed: () => _open('/me')),
        ],
      ),
      body: FlutterMap(
        mapController: _map,
        options: MapOptions(
          initialCenter: defaultCenter,
          initialZoom: 13,
          onMapReady: () {
            _load();
            _centerOnMe(zoom: 14); // the camera can only move once the map is ready
          },
          onPositionChanged: (_, _) => _scheduleLoad(),
        ),
        children: [
          osmTiles(context),
          MarkerLayer(
            markers: [
              for (final item in _items)
                Marker(
                  key: ValueKey('${item.type.api}-${item.id}'),
                  point: item.location,
                  width: 60,
                  height: 60,
                  child: GestureDetector(
                    onTap: () => _preview(item),
                    // Markers pop in as the area loads
                    child: FadeSlideIn(
                      key: ValueKey(item.id),
                      offset: const Offset(0, 0.3),
                      scale: 0.4,
                      duration: const Duration(milliseconds: 350),
                      child: _MarkerIcon(item),
                    ),
                  ),
                ),
            ],
          ),
          osmAttribution(),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // The guide's "my location" button: a white circle with a soft shadow
          DecoratedBox(
            decoration: const BoxDecoration(shape: BoxShape.circle, boxShadow: cardShadow),
            child: IconButton(
              tooltip: l10n.myLocation,
              onPressed: _centerOnMe,
              style: IconButton.styleFrom(
                backgroundColor: context.tokens.card,
                foregroundColor: context.tokens.accent,
                fixedSize: const Size.square(48),
              ),
              icon: const Icon(LucideIcons.locateFixed),
            ),
          ),
          const SizedBox(height: 12),
          GradientFab(
            gradient: Brand.lostGradient,
            icon: LucideIcons.megaphone,
            label: l10n.reportLostPet,
            onPressed: () => _open('/lost/new'),
          ),
          const SizedBox(height: 12),
          GradientFab(
            gradient: Brand.sightingGradient,
            icon: LucideIcons.camera,
            label: l10n.iSawAnAnimal,
            onPressed: () => _open('/sightings/new'),
          ),
        ],
      ),
    );
  }

  void _preview(MapItem item) {
    final l10n = context.l10n;
    showModalBottomSheet(
      context: context,
      builder: (sheet) => SafeArea(
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 16, 16),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox.square(dimension: 72, child: NetworkPhoto(item.photoUrl)),
          ),
          // The type as on the map legend, then what it is
          title: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [
              Row(
                spacing: 6,
                children: [
                  _Dot(markerStyle(item.type).$1),
                  Text(_typeLabel(l10n, item.type), style: Theme.of(context).textTheme.labelMedium),
                ],
              ),
              Text(switch (item.type) {
                MapItemType.lost => l10n.lostNamed(item.name ?? ''),
                MapItemType.sighting => l10n.sightingOf(speciesLabel(l10n, item.species)),
                MapItemType.stray => l10n.strayOf(speciesLabel(l10n, item.species)),
              }),
            ],
          ),
          subtitle: Text(
            [
              l10n.seenAgo(timeAgo(l10n, item.date)),
              if (item.condition != null && item.condition != Condition.healthy) conditionLabel(l10n, item.condition!),
            ].join(' · '),
          ),
          trailing: const Icon(LucideIcons.chevronRight),
          onTap: () {
            Navigator.pop(sheet);
            _open(item.type == MapItemType.lost ? '/lost/${item.id}' : '/sightings/${item.id}');
          },
        ),
      ),
    );
  }
}

/// The guide's map marker: a 34px circle in the type's colour, 1.5px ink outline, 18px ink glyph,
/// inside a 60px tap area. Injured animals get the red marker with a plus and pulsing rings.
class _MarkerIcon extends StatelessWidget {
  const _MarkerIcon(this.item);

  final MapItem item;

  @override
  Widget build(BuildContext context) {
    final injured = item.condition == Condition.injured;
    final (color, icon) = injured ? (Brand.red, LucideIcons.plus) : markerStyle(item.type);
    final dot = Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Brand.ink, width: 1.5),
        boxShadow: const [BoxShadow(blurRadius: 6, color: Color(0x33101D36), offset: Offset(0, 2))],
      ),
      child: Icon(icon, color: Brand.ink, size: 18),
    );
    // Injured or in need of help: red rings pulse around the marker
    final urgent = injured || item.condition == Condition.needsHelp;
    return Center(
      child: urgent ? Pulse(color: Brand.red, size: 60, child: dot) : dot,
    );
  }
}

String _typeLabel(AppLocalizations l10n, MapItemType type, {bool plural = false}) => switch (type) {
  MapItemType.lost => plural ? l10n.typeLost : l10n.typeLostOne,
  MapItemType.sighting => l10n.typeSighting,
  MapItemType.stray => l10n.typeStray,
};

/// A type's colour as a small dot, like the markers.
class _Dot extends StatelessWidget {
  const _Dot(this.color, {this.size = 8});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// Marker colour and glyph per type, the same as everywhere in the app.
(Color, IconData) markerStyle(MapItemType type) => switch (type) {
  MapItemType.lost => (Brand.coral, LucideIcons.search),
  MapItemType.sighting => (Brand.blue, LucideIcons.eye),
  MapItemType.stray => (Brand.amber, LucideIcons.pawPrint),
};

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial});

  final MapFilters initial;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late MapFilters _f = widget.initial;

  Set<T> _toggle<T>(Set<T> set, T value, bool on) => on ? {...set, value} : ({...set}..remove(value));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = Theme.of(context).textTheme.titleSmall;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.filters, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(l10n.filterShow, style: title),
            Wrap(
              spacing: 8,
              children: [
                for (final type in MapItemType.values)
                  FilterChip(
                    avatar: Center(child: _Dot(markerStyle(type).$1, size: 10)),
                    showCheckmark: false, // the coloured dot doubles as the map legend
                    label: Text(_typeLabel(l10n, type, plural: true)),
                    selected: _f.types.contains(type),
                    onSelected: (on) => setState(() => _f = _f.copyWith(types: _toggle(_f.types, type, on))),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(l10n.filterSpecies, style: title),
            Wrap(
              spacing: 8,
              children: [
                for (final species in Species.values)
                  FilterChip(
                    label: Text(speciesLabel(l10n, species)),
                    selected: _f.species.contains(species),
                    onSelected: (on) => setState(() => _f = _f.copyWith(species: _toggle(_f.species, species, on))),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(l10n.filterCondition, style: title),
            Wrap(
              spacing: 8,
              children: [
                for (final condition in Condition.values)
                  FilterChip(
                    label: Text(conditionLabel(l10n, condition)),
                    selected: _f.conditions.contains(condition),
                    onSelected: (on) =>
                        setState(() => _f = _f.copyWith(conditions: _toggle(_f.conditions, condition, on))),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(l10n.filterPeriod, style: title),
            Wrap(
              spacing: 8,
              children: [
                for (final days in [7, 30, 90, null])
                  ChoiceChip(
                    label: Text(days == null ? l10n.periodAny : l10n.periodDays(days)),
                    selected: _f.sinceDays == days,
                    onSelected: (_) => setState(() => _f = _f.copyWith(sinceDays: () => days)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: () => Navigator.pop(context, _f), child: Text(l10n.apply)),
            ),
          ],
        ),
      ),
    );
  }
}
