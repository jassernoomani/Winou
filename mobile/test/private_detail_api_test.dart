import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:winou/api/api_client.dart';
import 'package:winou/api/models.dart';

/// Answers every request with the same lost report, and remembers what was sent.
class _Server implements HttpClientAdapter {
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancel) async {
    last = options;
    final report = {
      'id': 'luna',
      'name': 'Luna',
      'species': 'cat',
      'description': null,
      'last_seen': {'lat': 36.8, 'lon': 10.18},
      'location_is_approximate': false,
      'last_seen_at': '2026-11-01T10:00:00Z',
      'status': 'OPEN',
      'photos': [],
      'private_detail': 'A white star under her chin',
    };
    return ResponseBody.fromString(
      jsonEncode(report),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _Server server;
  late WinouApi api;
  const here = LatLng(36.8, 10.18);

  setUp(() {
    server = _Server();
    api = WinouApi(token: () => 'token', renew: () async => false, onUnauthorized: () {}, onBanned: (_) {})
      ..debugAdapter = server;
  });

  Map<String, dynamic> sent() => server.last!.data as Map<String, dynamic>;

  test('a new report carries the private detail, and reads it back', () async {
    final report = await api.createLostReport(
      name: 'Luna',
      species: Species.cat,
      lastSeen: here,
      lastSeenAt: DateTime(2026, 11, 1),
      privateDetail: 'A white star under her chin',
    );
    expect(sent()['private_detail'], 'A white star under her chin');
    expect(report.privateDetail, 'A white star under her chin');
  });

  test('left empty, it is not sent', () async {
    await api.createLostReport(name: 'Luna', species: Species.cat, lastSeen: here, lastSeenAt: DateTime(2026, 11, 1));
    expect(sent().containsKey('private_detail'), isFalse);
  });

  test('editing: an empty detail removes it, null leaves it', () async {
    await api.updateLostReport('luna', privateDetail: '');
    expect(sent()['private_detail'], '');
    await api.updateLostReport('luna', name: 'Luna');
    expect(sent().containsKey('private_detail'), isFalse);
  });

  test('a pet marked lost carries it too', () async {
    await api.markPetLost('p1', lastSeen: here, lastSeenAt: DateTime(2026, 11, 1), privateDetail: 'Blue collar');
    expect(server.last!.path, '/pets/p1/lost');
    expect(sent()['private_detail'], 'Blue collar');
  });
}
