import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:winou/api/models.dart';
import 'package:winou/config.dart';

void main() {
  test('parses a lost report as returned by the API', () {
    final report = LostReport.fromJson({
      'id': 'r1',
      'name': 'Mimi',
      'species': 'cat',
      'description': null,
      'last_seen': {'lat': 36.8, 'lon': 10.18},
      'location_is_approximate': true,
      'last_seen_at': '2026-10-20T17:00:00Z',
      'status': 'OPEN',
      'photos': [
        {
          'id': 'p1',
          'status': 'NO_ANIMAL',
          'detected_species': null,
          'url': '/photos/p1/image',
          'crop_url': null,
          'created_at': '2026-10-20T17:05:00Z',
        },
      ],
      'created_at': '2026-10-20T17:05:00Z',
    });
    expect(report.species, Species.cat);
    expect(report.status, ReportStatus.open);
    expect(report.isMine, isFalse);
    expect(report.lastSeen.latitude, 36.8);
    expect(report.photos.single.url, '${Config.apiUrl}/photos/p1/image');
    expect(report.photos.single.isProcessing, isFalse);
  });

  test('parses map items with API enum values', () {
    final item = MapItem.fromJson({
      'type': 'stray',
      'id': 's1',
      'species': 'dog',
      'location': {'lat': 36.8, 'lon': 10.2},
      'date': '2026-10-25T08:00:00Z',
      'name': null,
      'condition': 'NEEDS_HELP',
      'photo_url': null,
    });
    expect(item.type, MapItemType.stray);
    expect(item.condition, Condition.needsHelp);
    expect(item.photoUrl, isNull);
  });

  test('serialises a location the way the API expects', () {
    expect(locationJson(const LatLng(36.8, 10.2)), {'lat': 36.8, 'lon': 10.2});
  });
}
