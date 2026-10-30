import 'dart:ui' show PlatformDispatcher;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:latlong2/latlong.dart';

import '../config.dart';
import 'models.dart';

/// An API error with the message to show the user.
class ApiException implements Exception {
  ApiException(this.message, {this.code, this.status, this.detail});

  final String message;
  final String? code; // e.g. "no_animal_detected", "rate_limited"
  final int? status;
  final Map<String, dynamic>? detail; // the whole error, for codes with more fields (e.g. "banned")

  @override
  String toString() => message;
}

/// What signing in returns: a short-lived access token, and the refresh token that renews it.
typedef SessionTokens = ({String access, String? refresh});

SessionTokens _tokens(dynamic data) => (access: data['access_token'], refresh: data['refresh_token']);

/// Thin wrapper over the Winou API. One method per endpoint.
class WinouApi {
  /// [renew] trades the refresh token for new tokens after a 401; false if the session is over.
  WinouApi({
    required String? Function() token,
    required Future<bool> Function() renew,
    required void Function() onUnauthorized,
    required void Function(Ban ban) onBanned,
    void Function(bool answered)? onServer,
  }) : _dio = Dio(_options),
       _plain = Dio(_options) {
    _plain.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) => handler.next(_toServer(options))));
    _dio.interceptors.add(
      InterceptorsWrapper(
        onResponse: (response, handler) {
          onServer?.call(true);
          handler.next(response);
        },
        onRequest: (options, handler) {
          _toServer(options);
          final value = token();
          if (value != null) options.headers['Authorization'] = 'Bearer $value';
          handler.next(options);
        },
        onError: (error, handler) async {
          onServer?.call(error.response != null); // no answer at all: the server can't be reached
          final request = error.requestOptions;
          if (error.response?.statusCode == 401 && token() != null) {
            // The access token expired: renew it once, then send the request again
            if (request.extra['renewed'] != true && await renew()) {
              request.extra['renewed'] = true;
              request.headers['Authorization'] = 'Bearer ${token()}';
              if (request.data case final FormData form) request.data = form.clone(); // a form is sent once
              try {
                return handler.resolve(await _dio.fetch(request));
              } on DioException catch (e) {
                return handler.reject(e);
              }
            }
            onUnauthorized();
          }
          final exception = _toApiException(error);
          // Banned by an admin: on any request, or when signing in
          if (exception.code == 'banned') onBanned(Ban.fromJson(exception.detail!));
          handler.reject(error.copyWith(error: exception));
        },
      ),
    );
  }

  static final _options = BaseOptions(
    baseUrl: Config.apiUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 60),
    listFormat: ListFormat.multi, // type=lost&type=stray, as the API expects
  );

  static RequestOptions _toServer(RequestOptions options) => options
    ..baseUrl = Config
        .apiUrl // may have been changed in the app since
    ..headers['Accept-Language'] = PlatformDispatcher.instance.locale.languageCode; // emails in the phone's language

  final Dio _dio;
  final Dio _plain; // without the token or renewal: for the session's own calls

  /// Tests answer requests themselves.
  @visibleForTesting
  set debugAdapter(HttpClientAdapter adapter) => _dio.httpClientAdapter = _plain.httpClientAdapter = adapter;

  Future<T> _call<T>(Future<Response> Function() request, T Function(dynamic data) parse) async {
    try {
      return parse((await request()).data);
    } on DioException catch (e) {
      throw e.error is ApiException ? e.error as ApiException : _toApiException(e);
    }
  }

  // --- auth ---

  Future<SessionTokens> login(String email, String password) => _call(
    () => _dio.post(
      '/auth/login',
      data: {'username': email, 'password': password},
      options: Options(contentType: Headers.formUrlEncodedContentType),
    ),
    _tokens,
  );

  Future<SessionTokens> register(String email, String password, String displayName) => _call(
    () => _dio.post('/auth/register', data: {'email': email, 'password': password, 'display_name': displayName}),
    _tokens,
  );

  /// Continue with Google: [idToken] from Google Sign-In.
  Future<SessionTokens> google(String idToken) =>
      _call(() => _dio.post('/auth/google', data: {'id_token': idToken}), _tokens);

  /// Forgot password: emails a code (the answer is the same whether the email has an account or not).
  Future<void> requestPasswordReset(String email) =>
      _call(() => _plain.post('/auth/password-reset', data: {'email': email}), (_) {});

  /// The code and a new password: signs in.
  Future<SessionTokens> confirmPasswordReset(String email, String code, String newPassword) => _call(
    () =>
        _plain.post('/auth/password-reset/confirm', data: {'email': email, 'code': code, 'new_password': newPassword}),
    _tokens,
  );

  Future<void> requestEmailVerification() => _call(() => _dio.post('/me/email/verification'), (_) {});

  Future<User> confirmEmailVerification(String code) =>
      _call(() => _dio.post('/me/email/verification/confirm', data: {'code': code}), (data) => User.fromJson(data));

  /// New tokens for a refresh token, which stops working.
  Future<SessionTokens> refreshSession(String refreshToken) =>
      _call(() => _plain.post('/auth/refresh', data: {'refresh_token': refreshToken}), _tokens);

  Future<void> endSession(String refreshToken) =>
      _call(() => _plain.post('/auth/logout', data: {'refresh_token': refreshToken}), (_) {});

  /// Signs every other phone out; returns this phone's new tokens. No [current]: the first password
  /// of an account made with Google.
  Future<SessionTokens> changePassword(String? current, String next) =>
      _call(() => _dio.post('/me/password', data: {'current_password': current, 'new_password': next}), _tokens);

  Future<void> signOutEverywhere() => _call(() => _dio.post('/me/sign-out-everywhere'), (_) {});

  Future<void> deleteAccount(String? password) => _call(() => _dio.delete('/me', data: {'password': password}), (_) {});

  Future<User> rename(String displayName) =>
      _call(() => _dio.patch('/me', data: {'display_name': displayName}), (data) => User.fromJson(data));

  Future<User> me() => _call(() => _dio.get('/me'), (data) => User.fromJson(data));

  Future<void> updateMe({String? fcmToken}) => _call(() => _dio.patch('/me', data: {'fcm_token': fcmToken}), (_) {});

  // --- alert areas ---

  /// null when the user watches no area.
  Future<AlertArea?> alertArea() =>
      _call(() => _dio.get('/me/alert-area'), (data) => data is Map<String, dynamic> ? AlertArea.fromJson(data) : null);

  Future<AlertArea> setAlertArea({
    required LatLng location,
    required double radiusKm,
    required bool lost,
    required bool help,
  }) => _call(
    () => _dio.put(
      '/me/alert-area',
      data: {'location': locationJson(location), 'radius_km': radiusKm.roundToDouble(), 'lost': lost, 'help': help},
    ),
    (data) => AlertArea.fromJson(data),
  );

  Future<void> clearAlertArea() => _call(() => _dio.delete('/me/alert-area'), (_) {});

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
    String? lostReportId,
  }) => _call(
    () => _dio.post(
      '/sightings',
      data: {
        'lost_report_id': ?lostReportId,
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

  /// Reported, not hidden yet: the most reported first.
  Future<List<HiddenItem>> reportedContent() =>
      _call(() => _dio.get('/admin/reported'), (data) => [for (final h in data) HiddenItem.fromJson(h)]);

  Future<void> hideContent(ReportTarget type, String id) =>
      _call(() => _dio.post('/admin/content/${type.api}/$id/hide'), (_) {});

  Future<void> dismissReports(ReportTarget type, String id) =>
      _call(() => _dio.post('/admin/content/${type.api}/$id/dismiss'), (_) {});

  Future<void> deleteContent(ReportTarget type, String id) =>
      _call(() => _dio.delete('/admin/content/${type.api}/$id'), (_) {});

  Future<List<AdminUser>> adminUsers({String query = '', bool bannedOnly = false}) => _call(
    () => _dio.get('/admin/users', queryParameters: {'q': query, 'banned': bannedOnly, 'limit': 100}),
    (data) => [for (final u in data) AdminUser.fromJson(u)],
  );

  Future<AdminUserDetail> adminUser(String id) =>
      _call(() => _dio.get('/admin/users/$id'), (data) => AdminUserDetail.fromJson(data));

  /// No [days]: for good.
  Future<void> banUser(String id, {int? days, String? reason}) => _call(
    () => _dio.post(
      '/admin/users/$id/ban',
      data: {'days': days, if (reason != null && reason.isNotEmpty) 'reason': reason},
    ),
    (_) {},
  );

  Future<void> unbanUser(String id) => _call(() => _dio.post('/admin/users/$id/unban'), (_) {});

  Future<AdminSummary> adminSummary() => _call(() => _dio.get('/admin/summary'), (data) => AdminSummary.fromJson(data));

  Future<AdminStats> adminStats() => _call(() => _dio.get('/admin/stats'), (data) => AdminStats.fromJson(data));

  /// What admins did, newest first.
  Future<List<AdminActionEntry>> adminActions({int offset = 0}) => _call(
    () => _dio.get('/admin/actions', queryParameters: {'limit': 100, 'offset': offset}),
    (data) => [for (final a in data) AdminActionEntry.fromJson(a)],
  );

  Future<void> revokeAssociation(String id) => _call(() => _dio.delete('/admin/users/$id/association'), (_) {});
}

ApiException _toApiException(DioException error) {
  final response = error.response;
  if (response == null) {
    return ApiException('Cannot reach the server (${Config.apiUrl}).', code: 'network');
  }
  final detail = response.data is Map ? response.data['detail'] : null;
  return switch (detail) {
    {'message': String message, 'code': String code} => ApiException(
      message,
      code: code,
      status: response.statusCode,
      detail: Map<String, dynamic>.from(detail),
    ),
    String message => ApiException(message, status: response.statusCode),
    // Validation errors: a list of {loc, msg}
    [{'msg': String message}, ...] => ApiException(message, code: 'validation', status: response.statusCode),
    _ => ApiException('Server error (${response.statusCode}).', status: response.statusCode),
  };
}
