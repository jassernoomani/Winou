import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:winou/api/api_client.dart';
import 'package:winou/api/models.dart';

/// Answers /photos/check and /search/by-photo like the API, and remembers what was asked.
class _Server implements HttpClientAdapter {
  RequestOptions? last;
  bool noAnimal = false;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancel) async {
    last = options;
    if (requestStream != null) await requestStream.drain<void>();
    final headers = {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    };
    if (noAnimal) {
      final error = {
        'detail': {'code': 'no_animal_detected', 'message': 'No cat or dog found.'},
      };
      return ResponseBody.fromString(jsonEncode(error), 422, headers: headers);
    }
    final body = options.path == '/photos/check'
        ? {'species': 'dog', 'confidence': 0.91}
        : {
            'species': 'cat',
            'confidence': 0.88,
            'results': [
              {
                'report': {
                  'id': 'luna',
                  'name': 'Luna',
                  'species': 'cat',
                  'description': null,
                  'last_seen': {'lat': 36.8, 'lon': 10.18},
                  'location_is_approximate': true,
                  'last_seen_at': '2026-11-01T10:00:00Z',
                  'status': 'OPEN',
                  'photos': [
                    {'id': 'p1', 'status': 'READY', 'url': '/photos/p1/image', 'crop_url': null},
                  ],
                },
                'score': 0.82,
                'likely': true,
                'matched_image_url': '/photos/p1/image',
              },
            ],
          };
    return ResponseBody.fromString(jsonEncode(body), 200, headers: headers);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _Server server;
  late WinouApi api;
  late String photo;

  setUp(() {
    server = _Server();
    api = WinouApi(token: () => 'token', renew: () async => false, onUnauthorized: () {}, onBanned: (_) {})
      ..debugAdapter = server;
    photo = File('../design/img/dog.png').absolute.path;
  });

  test('photo check', () async {
    final check = await api.checkPhoto(photo);
    expect(server.last!.path, '/photos/check');
    expect(check.species, Species.dog);
    expect(check.confidence, 0.91);
  });

  test('a photo without an animal is a coded error', () async {
    server.noAnimal = true;
    await expectLater(
      api.checkPhoto(photo),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'no_animal_detected')),
    );
  });

  test('search sends the place and the species, and reads the hits', () async {
    final result = await api.searchByPhoto(photo, const LatLng(36.8, 10.18), species: Species.cat);
    expect(server.last!.path, '/search/by-photo');
    expect(server.last!.queryParameters, {'lat': 36.8, 'lon': 10.18, 'species': 'cat'});
    expect(result.species, Species.cat);
    final hit = result.results.single;
    expect(hit.report.name, 'Luna');
    expect(hit.likely, isTrue);
    expect(hit.score, 0.82);
    expect(hit.matchedImageUrl, endsWith('/photos/p1/image'));
  });

  test('without a species, none is sent (the server detects it)', () async {
    await api.searchByPhoto(photo, const LatLng(36.8, 10.18));
    expect(server.last!.queryParameters.containsKey('species'), isFalse);
  });
}
