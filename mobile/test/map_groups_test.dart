import 'package:flutter_test/flutter_test.dart';
import 'package:winou/api/models.dart';
import 'package:winou/map/map_screen.dart';

MapItem _at(String id, double lat, double lon) => MapItem.fromJson({
  'type': 'sighting',
  'id': id,
  'species': 'cat',
  'location': {'lat': lat, 'lon': lon},
  'date': '2026-10-30T10:00:00Z',
  'name': null,
  'condition': 'HEALTHY',
  'photo_url': null,
});

void main() {
  // Two sightings 150 m apart in Tunis, a third 5 km away
  final items = [_at('a', 36.8065, 10.1815), _at('b', 36.8078, 10.1820), _at('c', 36.8515, 10.1815)];

  test('places close together share a marker when zoomed out', () {
    final groups = groupMarkers(items, 13);
    expect(
      groups.map((g) => g.map((i) => i.id).toSet()),
      containsAll([
        {'a', 'b'},
        {'c'},
      ]),
    );
  });

  test('zoomed in, every place has its own marker', () {
    expect(groupMarkers(items, 18), hasLength(3));
  });

  test('every place is in exactly one group', () {
    for (final zoom in [3, 8, 13, 16, 19]) {
      expect(groupMarkers(items, zoom).expand((g) => g), hasLength(items.length));
    }
  });
}
