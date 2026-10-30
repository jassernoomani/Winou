// Renders app screens without a backend, phone or plugins, to compare them with the Figma designs
// (design/winou-screens.html). See screens_test.dart for how to run it.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winou/api/api_client.dart';
import 'package:winou/api/models.dart';
import 'package:winou/auth/auth_controller.dart';
import 'package:winou/config.dart';
import 'package:winou/l10n/app_localizations.dart';
import 'package:winou/theme.dart';

/// The real fonts (Nunito, Material and Lucide icons) instead of the test font's boxes.
Future<void> loadFonts() async {
  final manifest = json.decode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final family in manifest) {
    final loader = FontLoader(family['family']);
    for (final font in family['fonts']) {
      loader.addFont(rootBundle.load(font['asset']));
    }
    await loader.load();
  }
}

/// Photos and map tiles come from local files: any URL with "cat" or "dog" in it is that photo,
/// anything else is a plain street-map tile.
class FakeHttp extends HttpOverrides {
  final _cat = File('../design/img/cat.png').readAsBytesSync();
  final _dog = File('../design/img/dog.png').readAsBytesSync();
  final _tile = File('tool/screenshots/tile.png').readAsBytesSync();

  List<int> bytesFor(Uri url) => url.path.contains('cat')
      ? _cat
      : url.path.contains('dog')
      ? _dog
      : _tile;

  @override
  HttpClient createHttpClient(SecurityContext? context) => _Client(this);
}

class _Client implements HttpClient {
  _Client(this._http);

  final FakeHttp _http;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _Request(_http.bytesFor(url));

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async => _Request(_http.bytesFor(url));

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => invocation.isSetter ? null : super.noSuchMethod(invocation);
}

class _Request implements HttpClientRequest {
  _Request(this._bytes);

  final List<int> _bytes;

  @override
  final HttpHeaders headers = _Headers();

  @override
  Future addStream(Stream<List<int>> stream) => stream.drain();

  @override
  Future<HttpClientResponse> close() async => _Response(_bytes);

  @override
  Future<HttpClientResponse> get done => close();

  @override
  void abort([Object? exception, StackTrace? stackTrace]) {} // tiles scrolled away

  @override
  dynamic noSuchMethod(Invocation invocation) => invocation.isSetter ? null : super.noSuchMethod(invocation);
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(this._bytes);

  final List<int> _bytes;

  @override
  int get statusCode => 200;

  @override
  String get reasonPhrase => 'OK';

  @override
  int get contentLength => _bytes.length;

  @override
  HttpClientResponseCompressionState get compressionState => HttpClientResponseCompressionState.notCompressed;

  @override
  HttpHeaders get headers => _Headers();

  @override
  bool get isRedirect => false;

  @override
  bool get persistentConnection => false;

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream.value(_bytes).listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Headers implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) => null; // headers are ignored
}

/// Plugins answer as on a phone: location is on (Tunis), the camera returns the dog photo.
void mockPlugins() {
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final cache = Directory.systemTemp.createTempSync('winou-screens').path; // the map's tile cache
  messenger.setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), (_) async => cache);
  // No stored sign-in: screens that read the auth state see a signed-out user
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (_) async => null,
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('flutter.baseflow.com/geolocator'),
    (call) async => switch (call.method) {
      'isLocationServiceEnabled' => true,
      'checkPermission' || 'requestPermission' => 2, // while in use
      'getCurrentPosition' => {
        'latitude': Config.defaultLat,
        'longitude': Config.defaultLon,
        'accuracy': 12.0,
        'altitude': 0.0,
        'altitude_accuracy': 0.0,
        'heading': 0.0,
        'heading_accuracy': 0.0,
        'speed': 0.0,
        'speed_accuracy': 0.0,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'is_mocked': false,
      },
      _ => null,
    },
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/image_picker'),
    (call) async => File('../design/img/dog.png').absolute.path,
  );
}

// --- Sample data, as the API returns it ---

String _ago(Duration d) => DateTime.now().subtract(d).toUtc().toIso8601String();

Map<String, dynamic> _photo(String animal) => {
  'id': 'p-$animal',
  'status': 'READY',
  'url': '/files/$animal.jpg',
  'crop_url': null,
};

Map<String, dynamic> lostJson({
  String id = 'luna',
  String name = 'Luna',
  String species = 'cat',
  String status = 'OPEN',
  bool mine = false,
  String? description = 'Shy grey tabby, green eyes, small notch in the left ear.',
  Duration seen = const Duration(hours: 2),
  int? reward,
  bool? microchipped,
  String? phone,
}) => {
  'reward_tnd': reward,
  'microchipped': microchipped,
  'contact_phone': phone,
  'id': id,
  'name': name,
  'species': species,
  'description': description,
  'last_seen': {'lat': Config.defaultLat + 0.004, 'lon': Config.defaultLon - 0.006},
  'location_is_approximate': !mine,
  'last_seen_at': _ago(seen),
  'status': status,
  'photos': [_photo(species == 'dog' ? 'dog' : 'cat')],
  'author_id': mine ? null : 'u4', // admins only
};

Map<String, dynamic> sightingJson({
  String id = 's1',
  String species = 'cat',
  String condition = 'HEALTHY',
  bool stray = false,
  bool mine = false,
  Duration seen = const Duration(hours: 2),
  String strayStatus = 'AROUND',
  String? helpedBy,
  bool hidden = false,
}) => {
  'id': id,
  'species': species,
  'location': {'lat': Config.defaultLat + 0.002, 'lon': Config.defaultLon + 0.003},
  'seen_at': _ago(seen),
  'condition': condition,
  'note': 'Near the bakery, friendly',
  'is_stray': stray,
  'stray_status': strayStatus,
  'stray_status_at': stray ? _ago(const Duration(days: 1)) : null,
  'helped_by': helpedBy,
  'mine': mine,
  'photos': [_photo(species == 'dog' ? 'dog' : 'cat')],
  'hidden': hidden,
};

Map<String, dynamic> adminUserJson({
  String id = 'u1',
  String name = 'Karim',
  String email = 'karim.b@example.com',
  String role = 'USER',
  String? association,
  Duration? bannedFor,
  String? banReason,
  int lost = 0,
  int sightings = 0,
  int reports = 0,
  Duration joined = const Duration(days: 40),
}) => {
  'id': id,
  'email': email,
  'display_name': name,
  'role': role,
  'association_name': association,
  'created_at': _ago(joined),
  'banned_until': bannedFor == null ? null : DateTime.now().add(bannedFor).toUtc().toIso8601String(),
  'ban_reason': banReason,
  'lost_reports': lost,
  'sightings': sightings,
  'reports_received': reports,
};

final sampleUsers = [
  adminUserJson(
    name: 'Karim',
    bannedFor: const Duration(days: 6, hours: 20),
    banReason: 'Selling animals in sightings',
    sightings: 4,
    reports: 7,
  ),
  adminUserJson(
    id: 'u2',
    name: 'Yasmine',
    email: 'yasmine@demo.winou',
    role: 'ADMIN',
    lost: 1,
    joined: Duration(days: 90),
  ),
  adminUserJson(
    id: 'u3',
    name: 'Refuge de Tunis',
    email: 'contact@refuge-tunis.tn',
    role: 'ASSOCIATION',
    association: 'Refuge de Tunis',
    sightings: 12,
    joined: Duration(days: 30),
  ),
  adminUserJson(id: 'u4', name: 'Amira', email: 'amira.k@example.com', lost: 2, sightings: 3, reports: 1),
  adminUserJson(id: 'u5', name: 'Sami', email: 'sami@example.com', lost: 1, sightings: 1, joined: Duration(days: 2)),
];

Map<String, dynamic> matchJson({
  String id = 'm1',
  String name = 'Luna',
  double score = 0.84,
  String status = 'PENDING',
  String reportStatus = 'OPEN',
  String species = 'cat',
  String? conversation,
  Duration seen = const Duration(hours: 2),
  bool byFinder = false,
}) => {
  'id': id,
  'lost_report_id': name.toLowerCase(),
  'lost_report_name': name,
  'score': score,
  'source': byFinder ? 'FINDER' : 'MODEL',
  'status': status,
  'sighting': sightingJson(species: species, seen: seen),
  'lost_photo_url': '/files/$species-lost.jpg',
  'sighting_photo_url': '/files/$species.jpg',
  'report_status': reportStatus,
  'conversation_id': conversation,
  'created_at': _ago(seen),
};

Map<String, dynamic> messageJson(
  String id,
  String body, {
  required bool mine,
  required Duration ago,
  bool hidden = false,
}) => {'id': id, 'body': body, 'mine': mine, 'hidden': hidden, 'created_at': _ago(ago)};

Map<String, dynamic> conversationJson({
  String id = 'c1',
  String other = 'Sami',
  String pet = 'Luna',
  String species = 'cat',
  String reportStatus = 'OPEN',
  Map<String, dynamic>? last,
  int unread = 0,
  String? association,
}) => {
  'id': id,
  'lost_report_id': pet.toLowerCase(),
  'pet_name': pet,
  'report_status': reportStatus,
  'match_id': 'm1',
  'sighting_photo_url': '/files/$species.jpg',
  'my_role': 'owner',
  'other_name': other,
  'other_association': association,
  'last_message': last,
  'unread': unread,
  'created_at': _ago(const Duration(days: 1)),
};

Map<String, dynamic> associationRequestJson({
  String organisation = 'Refuge de Tunis',
  String city = 'Tunis',
  String user = 'Amira',
  String status = 'PENDING',
}) => {
  'id': 'r-$organisation',
  'organisation': organisation,
  'city': city,
  'contact': '+216 20 123 456 · facebook.com/refugetunis',
  'note': 'We take in about 40 dogs a year and work with two vets in La Marsa.',
  'location': {'lat': Config.defaultLat, 'lon': Config.defaultLon},
  'status': status,
  'user_name': user,
  'user_email': '${user.toLowerCase()}@example.com',
  'created_at': _ago(const Duration(hours: 5)),
  'decided_at': null,
};

final sampleChat = [
  messageJson(
    '1',
    'Hi! Is she still there? She has a notch in her left ear.',
    mine: true,
    ago: const Duration(minutes: 40),
  ),
  messageJson(
    '2',
    "Yes, she's sleeping under the blue car next to the bakery. I can see the notch.",
    mine: false,
    ago: const Duration(minutes: 38),
  ),
  messageJson('3', "That's her! I'm 10 minutes away.", mine: true, ago: const Duration(minutes: 37)),
  messageJson('4', "I'll stay here and keep an eye on her.", mine: false, ago: const Duration(minutes: 36)),
];

/// The API with canned answers. [hang] never answers (loading states), [fail] answers with a
/// network error. Lists default to the sample data; pass [] for empty states.
class FakeApi implements WinouApi {
  FakeApi({
    this.hang = false,
    this.fail = false,
    List<Map<String, dynamic>>? lost,
    List<Map<String, dynamic>>? mine,
    List<Map<String, dynamic>>? sightings,
    List<Map<String, dynamic>>? matches,
    List<Map<String, dynamic>>? conversations,
    List<Map<String, dynamic>>? messages,
    List<Map<String, dynamic>>? mapItems,
    Map<String, dynamic>? sighting,
    this.role = 'USER',
    this.associationName,
    this.request,
  }) : sightingData = sighting ?? sightingJson(species: 'dog', mine: true, seen: Duration.zero),
       lost =
           lost ??
           [
             lostJson(),
             lostJson(
               id: 'rocky',
               name: 'Rocky',
               species: 'dog',
               description: 'Sandy terrier mix, red collar, very friendly.',
               seen: const Duration(days: 1),
             ),
           ],
       mine = mine ?? [lostJson(mine: true)],
       sightings = sightings ?? [sightingJson(mine: true)],
       matches =
           matches ??
           [
             matchJson(),
             matchJson(id: 'm2', status: 'CONFIRMED', seen: const Duration(days: 1)),
             matchJson(id: 'm3', name: 'Rocky', species: 'dog', score: 0.71, seen: const Duration(days: 3)),
           ],
       chats =
           conversations ??
           [
             conversationJson(
               last: messageJson(
                 '9',
                 "She's under the blue car near the bakery",
                 mine: false,
                 ago: const Duration(minutes: 2),
               ),
               unread: 2,
             ),
             conversationJson(
               id: 'c2',
               other: 'Amira',
               pet: 'Rocky',
               species: 'dog',
               last: messageJson('8', 'Thank you so much!', mine: true, ago: const Duration(days: 1)),
             ),
             conversationJson(
               id: 'c3',
               other: 'Youssef',
               pet: 'Mimi',
               reportStatus: 'FOUND',
               last: messageJson('7', 'Mimi is home, thanks again', mine: false, ago: const Duration(days: 9)),
             ),
           ],
       chatMessages = messages ?? sampleChat,
       mapItems = mapItems ?? _sampleMap;

  final bool hang;
  final bool fail;
  final Map<String, dynamic> sightingData;
  final String role;
  final String? associationName;
  final Map<String, dynamic>? request; // the user's association request
  final List<Map<String, dynamic>> lost, mine, sightings, matches, chats, chatMessages, mapItems;

  static final _sampleMap = [
    for (final (type, dLat, dLon, condition) in [
      ('lost', 0.006, 0.004, null),
      ('lost', 0.003, -0.006, null),
      ('sighting', 0.0, 0.002, 'HEALTHY'),
      ('sighting', -0.008, -0.004, 'HEALTHY'),
      ('stray', -0.003, -0.009, 'HEALTHY'),
      ('stray', -0.004, 0.003, 'INJURED'),
    ])
      {
        'type': type,
        'id': '$type$dLat',
        'species': 'cat',
        'location': {'lat': Config.defaultLat + dLat, 'lon': Config.defaultLon + dLon},
        'date': _ago(const Duration(hours: 2)),
        'name': type == 'lost' ? 'Luna' : null,
        'condition': condition,
        'photo_url': '/files/cat.jpg',
      },
  ];

  Future<T> _answer<T>(T Function() value) {
    if (hang) return Completer<T>().future;
    if (fail) return Future.error(ApiException('Cannot reach the server.', code: 'network'));
    return Future.value(value());
  }

  @override
  Future<List<LostReport>> lostReports({
    dynamic near,
    double radiusKm = 25,
    Species? species,
    int limit = 20,
    int offset = 0,
  }) => _answer(() => offset > 0 ? [] : [for (final r in lost) LostReport.fromJson(r)]);

  @override
  Future<LostReport> lostReport(String id) =>
      _answer(() => LostReport.fromJson([...mine, ...lost].firstWhere((r) => r['id'] == id)));

  @override
  Future<List<LostReport>> myLostReports() => _answer(() => [for (final r in mine) LostReport.fromJson(r)]);

  @override
  Future<List<Sighting>> mySightings() => _answer(() => [for (final s in sightings) Sighting.fromJson(s)]);

  @override
  Future<Sighting> sighting(String id) => _answer(() => Sighting.fromJson(sightingData));

  @override
  Future<User> me() => _answer(
    () => User.fromJson({
      'id': 'me',
      'email': 'sami@example.com',
      'display_name': 'Sami',
      'role': role,
      'association_name': associationName,
    }),
  );

  @override
  Future<AssociationRequest?> myAssociationRequest() =>
      _answer(() => request == null ? null : AssociationRequest.fromJson(request!));

  @override
  Future<List<AssociationRequest>> pendingAssociationRequests() => _answer(
    () => [
      AssociationRequest.fromJson(associationRequestJson()),
      AssociationRequest.fromJson(
        associationRequestJson(organisation: 'Les Amis des Chats', city: 'Sousse', user: 'Leila'),
      ),
    ],
  );

  @override
  Future<List<HiddenItem>> hiddenContent() => _answer(
    () => [
      HiddenItem.fromJson({
        'target_type': 'SIGHTING',
        'target_id': 'h1',
        'title': 'dog',
        'text': 'Selling puppies, call me',
        'photo_url': '/files/dog.jpg',
        'hidden_at': _ago(const Duration(hours: 3)),
        'reports': 3,
        'reasons': ['SPAM', 'FAKE'],
        'notes': ['This is an ad, not a sighting'],
        'author_id': 'u1',
        'author_name': 'Karim',
      }),
      HiddenItem.fromJson({
        'target_type': 'MESSAGE',
        'target_id': 'h2',
        'title': 'Karim',
        'text': 'Send me money first and I will bring her back',
        'photo_url': null,
        'hidden_at': _ago(const Duration(days: 1)),
        'reports': 1,
        'reasons': ['DANGEROUS'],
        'notes': [],
        'author_id': 'u1',
        'author_name': 'Karim',
      }),
    ],
  );

  @override
  Future<List<HiddenItem>> reportedContent() => _answer(
    () => [
      HiddenItem.fromJson({
        'target_type': 'LOST_REPORT',
        'target_id': 'rocky',
        'title': 'Rocky',
        'text': 'Reward 500 DT, send the money first and I tell you where he is',
        'photo_url': '/files/dog.jpg',
        'hidden_at': null,
        'reports': 2,
        'reasons': ['FAKE', 'DANGEROUS'],
        'notes': ['Asks for money up front'],
        'author_id': 'u4',
        'author_name': 'Amira',
        'last_reported_at': _ago(const Duration(minutes: 25)),
      }),
      HiddenItem.fromJson({
        'target_type': 'SIGHTING',
        'target_id': 's2',
        'title': 'cat',
        'text': 'Near the bakery, friendly',
        'photo_url': '/files/cat.jpg',
        'hidden_at': null,
        'reports': 1,
        'reasons': ['OTHER'],
        'notes': [],
        'author_id': 'u5',
        'author_name': 'Sami',
        'last_reported_at': _ago(const Duration(hours: 6)),
      }),
    ],
  );

  @override
  Future<List<AdminUser>> adminUsers({String query = '', bool bannedOnly = false}) => _answer(
    () => [
      for (final u in sampleUsers)
        if (!bannedOnly || u['banned_until'] != null) AdminUser.fromJson(u),
    ],
  );

  @override
  Future<AdminUserDetail> adminUser(String id) => _answer(
    () => AdminUserDetail.fromJson({
      'user': sampleUsers.firstWhere((u) => u['id'] == id),
      'lost_reports': [],
      'sightings': [
        sightingJson(species: 'dog', hidden: true, seen: const Duration(hours: 5)),
        sightingJson(id: 's2', species: 'dog', seen: const Duration(days: 2)),
      ],
      'history': [
        {
          'id': 'a1',
          'action': 'BAN_USER',
          'target_type': 'USER',
          'target_id': id,
          'admin_name': 'Yasmine',
          'user_name': 'Karim',
          'note': '7 days: Selling animals in sightings',
          'created_at': _ago(const Duration(hours: 4)),
        },
        {
          'id': 'a2',
          'action': 'DELETE_CONTENT',
          'target_type': 'SIGHTING',
          'target_id': 's0',
          'admin_name': 'Yasmine',
          'user_name': 'Karim',
          'note': null,
          'created_at': _ago(const Duration(hours: 4, minutes: 2)),
        },
      ],
    }),
  );

  @override
  Future<Inbox> notifications() => _answer(
    () => Inbox.fromJson({
      'unread': 2,
      'items': [
        for (final (i, (title, titleArgs, bodyKey, bodyArgs, body, type, read, ago)) in [
          ('match_title', <String>[], 'match_body', ['Luna'], null, 'match', false, const Duration(minutes: 12)),
          (
            'message_title',
            ['Sami', 'Luna'],
            null,
            <String>[],
            "She's under the blue car near the bakery",
            'message',
            false,
            const Duration(hours: 1),
          ),
          (
            'nearby_lost_title',
            <String>[],
            'nearby_lost_dog_body',
            ['Rocky'],
            null,
            'lost',
            true,
            const Duration(hours: 9),
          ),
          ('found_title', ['Mimi'], 'found_body', ['Mimi'], null, 'found', true, const Duration(days: 3)),
        ].indexed)
          {
            'id': 'n$i',
            'title_key': title,
            'title_args': titleArgs,
            'body_key': bodyKey,
            'body_args': bodyArgs,
            'body': body,
            'data': {'type': type},
            'created_at': _ago(ago),
            'read': read,
          },
      ],
    }),
  );

  @override
  Future<void> markNotificationsRead() => _answer(() {});

  @override
  Future<AlertArea?> alertArea() => _answer(
    () => AlertArea.fromJson({
      'location': {'lat': Config.defaultLat, 'lon': Config.defaultLon},
      'radius_km': 5,
      'lost': true,
      'help': false,
    }),
  );

  @override
  Future<void> requestPasswordReset(String email) => _answer(() {});

  @override
  Future<void> requestEmailVerification() => _answer(() {});

  @override
  Future<AdminSummary> adminSummary() =>
      _answer(() => AdminSummary.fromJson({'reported': 2, 'requests': 2, 'hidden': 2}));

  @override
  Future<AdminStats> adminStats() => _answer(() {
    final monday = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
    const lost = [3, 5, 4, 6, 8, 7, 9, 6, 10, 12, 9, 11];
    const seen = [6, 9, 8, 12, 14, 13, 17, 15, 19, 22, 20, 24];
    const home = [1, 1, 2, 2, 3, 4, 3, 5, 4, 6, 7, 6];
    return AdminStats.fromJson({
      'users': 214,
      'new_users_this_week': 18,
      'open_lost_reports': 27,
      'lost_reports_total': 96,
      'reunited': 44,
      'reunion_rate': 44 / 96,
      'sightings': 341,
      'strays_on_map': 58,
      'matches_confirmed': 51,
      'associations': 4,
      'stray_helped_by_associations': 23,
      'weeks': [
        for (var i = 0; i < 12; i++)
          {
            'week_start': monday.subtract(Duration(days: 7 * (11 - i))).toUtc().toIso8601String(),
            'lost_reports': lost[i],
            'sightings': seen[i],
            'reunited': home[i],
          },
      ],
    });
  });

  @override
  Future<List<AdminActionEntry>> adminActions({int offset = 0}) => _answer(
    () => [
      for (final (i, (action, type, user, note, ago)) in [
        ('BAN_USER', 'USER', 'Karim', '7 days: Selling animals in sightings', const Duration(hours: 4)),
        ('DELETE_CONTENT', 'SIGHTING', 'Karim', null, const Duration(hours: 4, minutes: 2)),
        ('APPROVE_ASSOCIATION', 'ASSOCIATION_REQUEST', 'Refuge de Tunis', 'Refuge de Tunis', const Duration(days: 1)),
        ('DISMISS_REPORTS', 'LOST_REPORT', 'Amira', '1 reports', const Duration(days: 2)),
        ('HIDE_CONTENT', 'LOST_REPORT', 'Sami', null, const Duration(days: 3)),
      ].indexed)
        AdminActionEntry.fromJson({
          'id': 'a$i',
          'action': action,
          'target_type': type,
          'target_id': 't$i',
          'admin_name': 'Yasmine',
          'user_id': 'u1',
          'user_name': user,
          'note': note,
          'created_at': _ago(ago),
        }),
    ],
  );

  @override
  Future<List<Match>> myMatches() => _answer(() => [for (final m in matches) Match.fromJson(m)]);

  @override
  Future<List<Conversation>> conversations() => _answer(() => [for (final c in chats) Conversation.fromJson(c)]);

  @override
  Future<Conversation> conversation(String id) =>
      _answer(() => Conversation.fromJson(chats.firstWhere((c) => c['id'] == id)));

  @override
  Future<List<ChatMessage>> messages(String conversationId, {DateTime? before}) =>
      _answer(() => before != null ? [] : [for (final m in chatMessages) ChatMessage.fromJson(m)]);

  @override
  Future<List<MapItem>> map({
    required double west,
    required double south,
    required double east,
    required double north,
    required Set<MapItemType> types,
    Set<Species> species = const {},
    Set<Condition> conditions = const {},
    DateTime? since,
  }) => _answer(() => [for (final i in mapItems) MapItem.fromJson(i)]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Phone size from the designs: 360 x 800, with a status bar.
void phoneSize(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(720, 1600)
    ..devicePixelRatio = 2
    ..padding = const FakeViewPadding(top: 48);
  addTearDown(tester.view.reset);
}

final screenshotKey = GlobalKey();

/// The app's theme around [screen], pushed on top of a blank page so it has a back button.
Widget app(Widget screen, {required Brightness brightness, required FakeApi api, Locale locale = const Locale('en')}) =>
    ProviderScope(
      overrides: [apiProvider.overrideWithValue(api)],
      child: RepaintBoundary(
        key: screenshotKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: winouTheme(brightness),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _PushOnStart(screen),
        ),
      ),
    );

class _PushOnStart extends StatefulWidget {
  const _PushOnStart(this.screen);

  final Widget screen;

  @override
  State<_PushOnStart> createState() => _PushOnStartState();
}

class _PushOnStartState extends State<_PushOnStart> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => Navigator.of(context).push(PageRouteBuilder(pageBuilder: (_, _, _) => widget.screen)),
    );
  }

  @override
  Widget build(BuildContext context) => const Scaffold();
}

/// Lets real work finish (image decoding, API futures) and animations run to their end.
Future<void> settle(WidgetTester tester, {int rounds = 6}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 60)));
    await tester.pump(const Duration(milliseconds: 400));
  }
}
