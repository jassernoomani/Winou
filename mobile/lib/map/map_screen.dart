import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/models.dart';
import '../auth/auth_controller.dart';
import '../l10n/app_localizations.dart';
import '../sightings/adoption.dart' show callNumber;
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
  bool _showPlaces = false; // vets and shelters, from OpenStreetMap
  List<Place> _places = [];
  bool _loading = false;
  int _zoom = 13; // whole zoom level the markers are grouped at
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
    if (_showPlaces) _loadPlaces();
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

  /// Alongside the map's items (its own request): a slow answer here never holds the markers back.
  Future<void> _loadPlaces() async {
    final bounds = _map.camera.visibleBounds;
    try {
      final places = await ref
          .read(apiProvider)
          .places(
            west: bounds.west.clamp(-180, 180),
            south: bounds.south.clamp(-90, 90),
            east: bounds.east.clamp(-180, 180),
            north: bounds.north.clamp(-90, 90),
          );
      if (mounted && _showPlaces) setState(() => _places = places);
    } catch (_) {
      // The layer is a convenience: the map works without it
    }
  }

  void _togglePlaces() {
    setState(() {
      _showPlaces = !_showPlaces;
      if (!_showPlaces) _places = [];
    });
    if (_showPlaces) _loadPlaces();
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
          IconButton(
            icon: const Icon(LucideIcons.heartHandshake),
            tooltip: l10n.forAdoption,
            onPressed: () => _open('/adoption'),
          ),
          IconButton(icon: const Icon(LucideIcons.list), tooltip: l10n.listOnMap, onPressed: _listVisible),
          IconButton(icon: const Icon(LucideIcons.slidersHorizontal), tooltip: l10n.filters, onPressed: _editFilters),
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
          onPositionChanged: (camera, _) {
            _scheduleLoad();
            // Markers regroup when the zoom level changes, not while panning
            if (camera.zoom.floor() != _zoom) setState(() => _zoom = camera.zoom.floor());
          },
        ),
        children: [
          osmTiles(context),
          if (_places.isNotEmpty)
            MarkerLayer(
              markers: [
                for (final place in _places)
                  Marker(
                    key: ValueKey('place-${place.id}'),
                    point: place.location,
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: () => showModalBottomSheet<void>(context: context, builder: (_) => PlaceSheet(place)),
                      child: PlaceMarker(place.kind),
                    ),
                  ),
              ],
            ),
          MarkerLayer(
            markers: [
              for (final group in groupMarkers(_items, _zoom))
                if (group.length == 1)
                  Marker(
                    key: ValueKey('${group.single.type.api}-${group.single.id}'),
                    point: group.single.location,
                    width: 60,
                    height: 60,
                    child: GestureDetector(
                      onTap: () => _preview(group.single),
                      // Markers pop in as the area loads
                      child: FadeSlideIn(
                        key: ValueKey(group.single.id),
                        offset: const Offset(0, 0.3),
                        scale: 0.4,
                        duration: const Duration(milliseconds: 350),
                        child: _MarkerIcon(group.single),
                      ),
                    ),
                  )
                else
                  Marker(
                    key: ValueKey('group-${group.map((i) => i.id).join()}'),
                    point: _middle(group),
                    width: 64,
                    height: 64,
                    child: GestureDetector(
                      onTap: () => _openGroup(group),
                      child: FadeSlideIn(
                        offset: Offset.zero,
                        scale: 0.4,
                        duration: const Duration(milliseconds: 350),
                        child: _GroupIcon(group),
                      ),
                    ),
                  ),
            ],
          ),
          osmAttribution(),
          // The vets and shelters layer, on or off
          Align(
            alignment: AlignmentDirectional.topStart,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: FilterChip(
                avatar: const Icon(LucideIcons.stethoscope, size: 18, color: PlaceMarker.vetColor),
                showCheckmark: false,
                label: Text(l10n.vetsAndShelters),
                selected: _showPlaces,
                onSelected: (_) => _togglePlaces(),
                elevation: 2,
              ),
            ),
          ),
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

  static LatLng _middle(List<MapItem> items) => LatLng(
    items.map((i) => i.location.latitude).reduce((a, b) => a + b) / items.length,
    items.map((i) => i.location.longitude).reduce((a, b) => a + b) / items.length,
  );

  /// A group: zoom in until it splits; if its places are (nearly) the same, list them instead.
  void _openGroup(List<MapItem> items) {
    final lats = items.map((i) => i.location.latitude);
    final lons = items.map((i) => i.location.longitude);
    final spread = [lats.reduce(math.max) - lats.reduce(math.min), lons.reduce(math.max) - lons.reduce(math.min)];
    if (spread.reduce(math.max) < 0.0003 || _map.camera.zoom >= 17.5) {
      _list(items, context.l10n.placesHere(items.length));
      return;
    }
    _map.fitCamera(
      CameraFit.coordinates(
        coordinates: [for (final i in items) i.location],
        padding: const EdgeInsets.all(80),
        maxZoom: 18,
      ),
    );
  }

  /// "List what's here": everything in the visible area, nearest to the middle first.
  void _listVisible() {
    final camera = _map.camera;
    const distance = Distance();
    final visible = [
      for (final item in _items)
        if (camera.visibleBounds.contains(item.location)) item,
    ]..sort((a, b) => distance(camera.center, a.location).compareTo(distance(camera.center, b.location)));
    _list(visible, context.l10n.placesHere(visible.length));
  }

  void _list(List<MapItem> items, String title) {
    final l10n = context.l10n;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        maxChildSize: 0.92,
        builder: (context, scroll) => items.isEmpty
            ? ListView(
                controller: scroll,
                children: [EmptyState(icon: LucideIcons.mapPinOff, text: l10n.nothingHere)],
              )
            : ListView.builder(
                controller: scroll,
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: items.length + 1,
                itemBuilder: (context, i) => i == 0
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
                      )
                    : _itemTile(items[i - 1], () {
                        Navigator.pop(sheet);
                        final item = items[i - 1];
                        _open(item.type == MapItemType.lost ? '/lost/${item.id}' : '/sightings/${item.id}');
                      }),
              ),
      ),
    );
  }

  void _preview(MapItem item) {
    showModalBottomSheet(
      context: context,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _itemTile(item, () {
            Navigator.pop(sheet);
            _open(item.type == MapItemType.lost ? '/lost/${item.id}' : '/sightings/${item.id}');
          }),
        ),
      ),
    );
  }

  /// One place: photo, type as on the legend, what it is, when.
  Widget _itemTile(MapItem item, VoidCallback onTap) {
    final l10n = context.l10n;
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(20, 4, 16, 4),
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
              _Dot(item.inCare ? Brand.green : markerStyle(item.type).$1),
              Text(
                item.inCare ? l10n.keptSafe : _typeLabel(l10n, item.type),
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
          Text(switch (item.type) {
            MapItemType.lost => l10n.lostNamed(item.name ?? ''),
            MapItemType.sighting => l10n.sightingOf(speciesLabel(l10n, item.species)),
            MapItemType.stray => item.name ?? l10n.strayOf(speciesLabel(l10n, item.species)), // its nickname
          }),
        ],
      ),
      subtitle: Text(
        [
          l10n.seenAgo(timeAgo(l10n, item.date)),
          if (item.condition != null && item.condition != Condition.healthy) conditionLabel(l10n, item.condition!),
        ].join(' · '),
      ),
      trailing: const ForwardIcon(),
      onTap: onTap,
    );
  }
}

/// Places whose markers would overlap at [zoom], grouped: a fixed grid of 56 px cells in web-map
/// pixels, so groups don't change while panning, only when zooming.
List<List<MapItem>> groupMarkers(List<MapItem> items, int zoom) {
  final scale = 256 * math.pow(2, zoom);
  final cells = <(int, int), List<MapItem>>{};
  for (final item in items) {
    final lat = item.location.latitude * math.pi / 180;
    final x = (item.location.longitude + 180) / 360 * scale;
    final y = (1 - math.log(math.tan(lat) + 1 / math.cos(lat)) / math.pi) / 2 * scale;
    cells.putIfAbsent((x ~/ 56, y ~/ 56), () => []).add(item);
  }
  return cells.values.toList();
}

/// A group of places: how many, in the brand's blue; red-ringed if one of them needs help.
/// A vet (teal stethoscope) or a shelter (violet house), smaller than the animals' markers.
class PlaceMarker extends StatelessWidget {
  const PlaceMarker(this.kind, {super.key});

  static const vetColor = Color(0xFF0D9488);
  static const shelterColor = Color(0xFF7C3AED);

  final PlaceKind kind;

  @override
  Widget build(BuildContext context) {
    final color = kind == PlaceKind.vet ? vetColor : shelterColor;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2.5),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Icon(kind == PlaceKind.vet ? LucideIcons.stethoscope : LucideIcons.house, size: 20, color: color),
    );
  }
}

/// A vet or shelter: name, opening hours, call, directions.
class PlaceSheet extends StatelessWidget {
  const PlaceSheet(this.place, {super.key});

  final Place place;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final kind = place.kind == PlaceKind.vet ? l10n.placeVet : l10n.placeShelter;
    final at = '${place.location.latitude},${place.location.longitude}';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Row(
              spacing: 12,
              children: [
                SizedBox.square(dimension: 44, child: PlaceMarker(place.kind)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name ?? kind,
                        textDirection: textDirectionOf(place.name ?? kind),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (place.name != null) Text(kind, style: TextStyle(color: context.tokens.muted)),
                    ],
                  ),
                ),
              ],
            ),
            if (place.openingHours case final hours?) Text(l10n.openingHours(hours)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (place.phone case final phone?)
                  FilledButton.icon(
                    onPressed: () => callNumber(phone),
                    icon: const Icon(LucideIcons.phone, size: 18),
                    label: Text(l10n.call),
                  ),
                OutlinedButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$at'),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(LucideIcons.navigation, size: 18),
                  label: Text(l10n.directions),
                ),
              ],
            ),
            Text('© OpenStreetMap', style: TextStyle(fontSize: 11, color: context.tokens.muted)),
          ],
        ),
      ),
    );
  }
}

class _GroupIcon extends StatelessWidget {
  const _GroupIcon(this.items);

  final List<MapItem> items;

  @override
  Widget build(BuildContext context) {
    final urgent = items.any((i) => i.condition != null && i.condition != Condition.healthy);
    final size = 38.0 + math.min(items.length, 30) / 30 * 14; // bigger groups look bigger
    final circle = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: Brand.gradient,
        shape: BoxShape.circle,
        border: Border.all(color: urgent ? Brand.red : Colors.white, width: 3),
        boxShadow: const [BoxShadow(blurRadius: 6, color: Color(0x33101D36), offset: Offset(0, 2))],
      ),
      child: Text(
        items.length > 99 ? '99+' : '${items.length}',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
      ),
    );
    return Center(
      child: Semantics(
        label: context.l10n.placesHere(items.length),
        child: urgent ? Pulse(color: Brand.red, size: 64, child: circle) : circle,
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
    final (color, icon) = injured
        ? (Brand.red, LucideIcons.plus)
        : item.inCare
        ? (Brand.green, LucideIcons.house)
        : markerStyle(item.type);
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
