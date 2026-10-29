import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

import '../config.dart';
import 'models.dart';

/// An API error with the message to show the user.
class ApiException implements Exception {
  ApiException(this.message, {this.code, this.status});

  final String message;
  final String? code; // e.g. "no_animal_detected", "rate_limited"
  final int? status;

  @override
  String toString() => message;
}

/// Thin wrapper over the Winou API. One method per endpoint.
class WinouApi {
  WinouApi({required String? Function() token, required void Function() onUnauthorized})
    : _dio = Dio(
        BaseOptions(
          baseUrl: Config.apiUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 60),
          listFormat: ListFormat.multi, // type=lost&type=stray, as the API expects
        ),
      ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.baseUrl = Config.apiUrl; // may have been changed in the app since
          final value = token();
          if (value != null) options.headers['Authorization'] = 'Bearer $value';
          handler.next(options);
        },
        onError: (error, handler) {
          if (error.response?.statusCode == 401 && token() != null) onUnauthorized();
          handler.reject(error.copyWith(error: _toApiException(error)));
        },
      ),
    );
  }

  final Dio _dio;

  Future<T> _call<T>(Future<Response> Function() request, T Function(dynamic data) parse) async {
    try {
      return parse((await request()).data);
    } on DioException catch (e) {
      throw e.error is ApiException ? e.error as ApiException : _toApiException(e);
    }
  }

  // --- auth ---

  Future<String> login(String email, String password) => _call(
    () => _dio.post(
      '/auth/login',
      data: {'username': email, 'password': password},
      options: Options(contentType: Headers.formUrlEncodedContentType),
    ),
    (data) => data['access_token'],
  );

  Future<String> register(String email, String password, String displayName) => _call(
    () => _dio.post('/auth/register', data: {'email': email, 'password': password, 'display_name': displayName}),
    (data) => data['access_token'],
  );

  Future<User> me() => _call(() => _dio.get('/me'), (data) => User.fromJson(data));

  Future<void> updateMe({String? fcmToken}) => _call(() => _dio.patch('/me', data: {'fcm_token': fcmToken}), (_) {});

  // --- map ---

  Future<List<MapItem>> map({
    required double west,
    required double south,
    required double east,
    required double north,
    required Set<MapItemType> types,
    Set<Species> species = const {},
    Set<Condition> conditions = const {},
    DateTime? since,
  }) => _call(
    () => _dio.get(
      '/map',
      queryParameters: {
        'bbox': [west, south, east, north].map((v) => v.toStringAsFixed(5)).join(','),
        'type': [for (final t in types) t.api],
        if (species.isNotEmpty) 'species': [for (final s in species) s.api],
        if (conditions.isNotEmpty) 'condition': [for (final c in conditions) c.api],
        if (since != null) 'since': since.toUtc().toIso8601String(),
      },
    ),
    (data) => [for (final item in data['items']) MapItem.fromJson(item)],
  );

  // --- lost reports ---

  Future<LostReport> createLostReport({
    required String name,
    required Species species,
    String? description,
    required LatLng lastSeen,
    required DateTime lastSeenAt,
  }) => _call(
    () => _dio.post(
      '/lost-reports',
      data: {
        'name': name,
        'species': species.api,
        if (description != null && description.isNotEmpty) 'description': description,
        'last_seen': locationJson(lastSeen),
        'last_seen_at': lastSeenAt.toUtc().toIso8601String(),
      },
    ),
    (data) => LostReport.fromJson(data),
  );

  Future<LostReport> lostReport(String id) =>
      _call(() => _dio.get('/lost-reports/$id'), (data) => LostReport.fromJson(data));

  /// Open reports, most recently seen first. With [near], only those within [radiusKm].
  Future<List<LostReport>> lostReports({
    LatLng? near,
    double radiusKm = 25,
    Species? species,
    int limit = 20,
    int offset = 0,
  }) => _call(
    () => _dio.get(
      '/lost-reports',
      queryParameters: {
        if (near != null) ...{'lat': near.latitude, 'lon': near.longitude, 'radius_km': radiusKm},
        'species': ?species?.api,
        'limit': limit,
        'offset': offset,
      },
    ),
    (data) => [for (final r in data) LostReport.fromJson(r)],
  );

  Future<List<LostReport>> myLostReports() =>
      _call(() => _dio.get('/me/lost-reports'), (data) => [for (final r in data) LostReport.fromJson(r)]);

  Future<LostReport> setReportStatus(String id, ReportStatus status) =>
      _call(() => _dio.patch('/lost-reports/$id', data: {'status': status.api}), (data) => LostReport.fromJson(data));

  Future<void> deleteLostReport(String id) => _call(() => _dio.delete('/lost-reports/$id'), (_) {});

  // --- sightings ---

  Future<Sighting> createSighting({
    required Species species,
    required LatLng location,
    required DateTime seenAt,
    required Condition condition,
    required bool isStray,
    String? note,
  }) => _call(
    () => _dio.post(
      '/sightings',
      data: {
        'species': species.api,
        'location': locationJson(location),
        'seen_at': seenAt.toUtc().toIso8601String(),
        'condition': condition.api,
        'is_stray': isStray,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    ),
    (data) => Sighting.fromJson(data),
  );

  Future<Sighting> sighting(String id) => _call(() => _dio.get('/sightings/$id'), (data) => Sighting.fromJson(data));

  Future<List<Sighting>> mySightings() =>
      _call(() => _dio.get('/me/sightings'), (data) => [for (final s in data) Sighting.fromJson(s)]);

  Future<void> deleteSighting(String id) => _call(() => _dio.delete('/sightings/$id'), (_) {});

  Future<Sighting> setStrayStatus(String id, StrayStatus status) => _call(
    () => _dio.patch('/sightings/$id/stray-status', data: {'status': status.api}),
    (data) => Sighting.fromJson(data),
  );

  // --- photos ---

  /// [ownerPath] is "/lost-reports/{id}" or "/sightings/{id}".
  Future<Photo> uploadPhoto(String ownerPath, String filePath, PhotoSource source) => _call(
    () async => _dio.post(
      '$ownerPath/photos',
      data: FormData.fromMap({'file': await MultipartFile.fromFile(filePath), 'source': source.api}),
    ),
    (data) => Photo.fromJson(data),
  );

  Future<Photo> photo(String id) => _call(() => _dio.get('/photos/$id'), (data) => Photo.fromJson(data));

  Future<void> deletePhoto(String id) => _call(() => _dio.delete('/photos/$id'), (_) {});

  /// Waits until the worker has processed the photo (usually a few seconds).
  Future<Photo> waitForPhoto(String id, {Duration timeout = const Duration(minutes: 2)}) async {
    final deadline = DateTime.now().add(timeout);
    while (true) {
      final current = await photo(id);
      if (!current.isProcessing || DateTime.now().isAfter(deadline)) return current;
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  // --- matches ---

  Future<List<Match>> myMatches() =>
      _call(() => _dio.get('/me/matches'), (data) => [for (final m in data) Match.fromJson(m)]);

  /// Confirm ("that's my pet"), reject, or undo a rejection with [MatchStatus.pending].
  Future<Match> setMatchStatus(String id, MatchStatus status) =>
      _call(() => _dio.patch('/matches/$id', data: {'status': status.api}), (data) => Match.fromJson(data));

  // --- messages ---

  /// The conversation with the match's finder, created on first use (owner only).
  Future<Conversation> startConversation(String matchId) =>
      _call(() => _dio.post('/matches/$matchId/conversation'), (data) => Conversation.fromJson(data));

  Future<List<Conversation>> conversations() =>
      _call(() => _dio.get('/conversations'), (data) => [for (final c in data) Conversation.fromJson(c)]);

  Future<Conversation> conversation(String id) =>
      _call(() => _dio.get('/conversations/$id'), (data) => Conversation.fromJson(data));

  /// Oldest first. The newest page also marks the conversation read.
  Future<List<ChatMessage>> messages(String conversationId, {DateTime? before}) => _call(
    () => _dio.get(
      '/conversations/$conversationId/messages',
      queryParameters: {if (before != null) 'before': before.toUtc().toIso8601String()},
    ),
    (data) => [for (final m in data) ChatMessage.fromJson(m)],
  );

  Future<ChatMessage> sendMessage(String conversationId, String body) => _call(
    () => _dio.post('/conversations/$conversationId/messages', data: {'body': body}),
    (data) => ChatMessage.fromJson(data),
  );

  // --- associations ---

  /// The user's latest request, or null if they never sent one.
  Future<AssociationRequest?> myAssociationRequest() => _call(
    () => _dio.get('/me/association-request'),
    (data) => data is Map<String, dynamic> ? AssociationRequest.fromJson(data) : null,
  );

  Future<AssociationRequest> requestAssociation({
    required String organisation,
    required String city,
    required String contact,
    String? note,
    required LatLng location,
  }) => _call(
    () => _dio.post(
      '/me/association-request',
      data: {
        'organisation': organisation,
        'city': city,
        'contact': contact,
        if (note != null && note.isNotEmpty) 'note': note,
        'location': locationJson(location),
      },
    ),
    (data) => AssociationRequest.fromJson(data),
  );

  // --- moderation ---

  /// Returns true when this report hid the content.
  Future<bool> report(ReportTarget type, String id, ReportReason reason, {String? note}) => _call(
    () => _dio.post(
      '/reports',
      data: {
        'target_type': type.api,
        'target_id': id,
        'reason': reason.api,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    ),
    (data) => data['hidden'] as bool,
  );

  // --- admin ---

  Future<List<AssociationRequest>> pendingAssociationRequests() => _call(
    () => _dio.get('/admin/association-requests'),
    (data) => [for (final r in data) AssociationRequest.fromJson(r)],
  );

  Future<void> decideAssociationRequest(String id, {required bool approve}) =>
      _call(() => _dio.post('/admin/association-requests/$id/${approve ? 'approve' : 'reject'}'), (_) {});

  Future<List<HiddenItem>> hiddenContent() =>
      _call(() => _dio.get('/admin/hidden'), (data) => [for (final h in data) HiddenItem.fromJson(h)]);

  Future<void> restoreHidden(ReportTarget type, String id) =>
      _call(() => _dio.post('/admin/hidden/${type.api}/$id/restore'), (_) {});

  Future<void> deleteHidden(ReportTarget type, String id) =>
      _call(() => _dio.delete('/admin/hidden/${type.api}/$id'), (_) {});
}

ApiException _toApiException(DioException error) {
  final response = error.response;
  if (response == null) {
    return ApiException('Cannot reach the server (${Config.apiUrl}).', code: 'network');
  }
  final detail = response.data is Map ? response.data['detail'] : null;
  return switch (detail) {
    {'message': String message, 'code': String code} => ApiException(message, code: code, status: response.statusCode),
    String message => ApiException(message, status: response.statusCode),
    // Validation errors: a list of {loc, msg}
    [{'msg': String message}, ...] => ApiException(message, code: 'validation', status: response.statusCode),
    _ => ApiException('Server error (${response.statusCode}).', status: response.statusCode),
  };
}
