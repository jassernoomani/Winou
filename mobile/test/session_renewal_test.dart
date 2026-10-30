import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winou/api/api_client.dart';
import 'package:winou/api/models.dart';

/// A server whose access tokens expire: "old" gets 401, "new" works.
class _Server implements HttpClientAdapter {
  final requests = <String>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancel) async {
    final auth = options.headers['Authorization'];
    requests.add('${options.path} $auth');
    if (requestStream != null) await requestStream.drain<void>(); // a form body is read like on a real server
    if (auth != 'Bearer new') {
      return ResponseBody.fromString(
        jsonEncode({'detail': 'Invalid or expired token'}),
        401,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    final photo = {'id': 'p1', 'status': 'PENDING', 'url': '/photos/p1/image', 'crop_url': null};
    final me = {'id': 'me', 'email': 'sami@example.com', 'display_name': 'Sami', 'role': 'USER'};
    return ResponseBody.fromString(
      jsonEncode(options.path.endsWith('/photos') ? photo : me),
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
  late String? token;
  late _Server server;
  late int renewals;
  late int signedOut;

  WinouApi api({required bool renewWorks}) {
    final client = WinouApi(
      token: () => token,
      renew: () async {
        renewals++;
        if (renewWorks) token = 'new';
        return renewWorks;
      },
      onUnauthorized: () => signedOut++,
      onBanned: (_) {},
    );
    client.debugAdapter = server;
    return client;
  }

  setUp(() {
    token = 'old';
    server = _Server();
    renewals = 0;
    signedOut = 0;
  });

  test('an expired access token is renewed and the request sent again', () async {
    final user = await api(renewWorks: true).me();

    expect(user.displayName, 'Sami');
    expect(renewals, 1);
    expect(signedOut, 0);
    expect(server.requests, ['/me Bearer old', '/me Bearer new']);
  });

  test('a photo upload is sent again after a renewal', () async {
    final file = File('${Directory.systemTemp.createTempSync('winou').path}/cat.jpg')..writeAsBytesSync([1, 2, 3]);

    final photo = await api(renewWorks: true).uploadPhoto('/lost-reports/luna', file.path, PhotoSource.camera);

    expect(photo.id, 'p1');
    expect(server.requests, ['/lost-reports/luna/photos Bearer old', '/lost-reports/luna/photos Bearer new']);
  });

  test('when the session is over too, the user is signed out', () async {
    await expectLater(api(renewWorks: false).me(), throwsA(isA<ApiException>()));

    expect(renewals, 1);
    expect(signedOut, 1);
    expect(server.requests, ['/me Bearer old']);
  });

  test('a request is renewed once, not in a loop', () async {
    final client = WinouApi(
      token: () => token,
      renew: () async {
        renewals++;
        return true; // says yes, but the token stays refused
      },
      onUnauthorized: () => signedOut++,
      onBanned: (_) {},
    )..debugAdapter = server;

    await expectLater(client.me(), throwsA(isA<ApiException>()));

    expect(renewals, 1);
    expect(signedOut, 1);
    expect(server.requests, hasLength(2));
  });
}
