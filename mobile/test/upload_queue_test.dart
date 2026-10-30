import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winou/api/api_client.dart';
import 'package:winou/api/models.dart';
import 'package:winou/auth/auth_controller.dart';
import 'package:winou/uploads.dart';

/// A server that is down (no answer), refuses photos, or takes them.
class _Server implements HttpClientAdapter {
  String mode = 'down';
  final received = <String>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancel) async {
    if (requestStream != null) await requestStream.drain<void>();
    if (mode == 'down') {
      throw DioException.connectionError(requestOptions: options, reason: 'unreachable');
    }
    received.add(options.path);
    final refused = mode == 'refuses';
    return ResponseBody.fromString(
      jsonEncode(
        refused
            ? {
                'detail': {'code': 'too_many_photos', 'message': 'Too many photos.'},
              }
            : {'id': 'p1', 'status': 'PENDING', 'url': '/photos/p1/image', 'crop_url': null},
      ),
      refused ? 422 : 201,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _SignedIn extends AuthController {
  @override
  AuthState build() => const AuthState(token: 'token');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory files;
  late _Server server;
  late ProviderContainer container;

  ProviderContainer start() {
    final api = WinouApi(token: () => 'token', renew: () async => false, onUnauthorized: () {}, onBanned: (_) {})
      ..debugAdapter = server;
    return ProviderContainer(overrides: [authProvider.overrideWith(_SignedIn.new), apiProvider.overrideWithValue(api)]);
  }

  Future<String> photo() async {
    final file = File('${files.path}/picked-${DateTime.now().microsecondsSinceEpoch}.jpg')..writeAsBytesSync([1, 2, 3]);
    return file.path;
  }

  setUp(() {
    files = Directory.systemTemp.createTempSync('winou-queue');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => files.path,
    );
    SharedPreferences.setMockInitialValues({});
    server = _Server();
    container = start();
  });

  tearDown(() => container.dispose());

  test('a photo waits while the server is down, and goes once it is back', () async {
    final queue = container.read(uploadQueueProvider.notifier);
    await queue.add('/lost-reports/luna', await photo(), PhotoSource.camera);
    await queue.send();
    expect(container.read(uploadQueueProvider), hasLength(1));
    final kept = container.read(uploadQueueProvider).single.file;
    expect(File(kept).existsSync(), isTrue); // a copy: the picker's file may be cleaned up

    server.mode = 'up';
    await queue.send();
    expect(container.read(uploadQueueProvider), isEmpty);
    expect(server.received, ['/lost-reports/luna/photos']);
    expect(File(kept).existsSync(), isFalse);
  });

  test('a photo the server refuses is not tried again', () async {
    server.mode = 'refuses';
    final queue = container.read(uploadQueueProvider.notifier);
    await queue.add('/sightings/s1', await photo(), PhotoSource.gallery);
    await queue.send();
    expect(container.read(uploadQueueProvider), isEmpty);
  });

  test('photos still waiting are there after the app restarts', () async {
    await container.read(uploadQueueProvider.notifier).add('/lost-reports/luna', await photo(), PhotoSource.camera);
    container.dispose();

    server.mode = 'up';
    container = start();
    container.read(uploadQueueProvider); // loads, then sends
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(server.received, ['/lost-reports/luna/photos']);
    expect(container.read(uploadQueueProvider), isEmpty);
  });
}
