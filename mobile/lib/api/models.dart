// Plain data classes for the API's JSON. Field names follow the API (see /docs).
import 'package:latlong2/latlong.dart';

import '../config.dart';

/// Enums whose JSON value differs from the Dart name.
mixin ApiEnum on Enum {
  String get api;
}

T _enum<T extends ApiEnum>(List<T> values, String value) => values.firstWhere((v) => v.api == value);

enum Species with ApiEnum {
  cat('cat'),
  dog('dog'),
  other('other');

  const Species(this.api);
  @override
  final String api;
}

enum Condition with ApiEnum {
  healthy('HEALTHY'),
  injured('INJURED'),
  needsHelp('NEEDS_HELP');

  const Condition(this.api);
  @override
  final String api;
}

enum ReportStatus with ApiEnum {
  open('OPEN'),
  found('FOUND'),
  closed('CLOSED');

  const ReportStatus(this.api);
  @override
  final String api;
}

enum MatchStatus with ApiEnum {
  pending('PENDING'),
  confirmed('CONFIRMED'),
  rejected('REJECTED');

  const MatchStatus(this.api);
  @override
  final String api;
}

/// Where a photo came from. Sent with uploads; the API keeps it for moderation only.
enum PhotoSource with ApiEnum {
  camera('CAMERA'),
  gallery('GALLERY');

  const PhotoSource(this.api);
  @override
  final String api;
}

/// What became of a stray. Anyone can update it; "around" also keeps it on the map.
enum StrayStatus with ApiEnum {
  around('AROUND'),
  helped('HELPED'),
  gone('GONE');

  const StrayStatus(this.api);
  @override
  final String api;
}

enum Role with ApiEnum {
  user('USER'),
  association('ASSOCIATION'),
  admin('ADMIN');

  const Role(this.api);
  @override
  final String api;
}

enum RequestStatus with ApiEnum {
  pending('PENDING'),
  approved('APPROVED'),
  rejected('REJECTED');

  const RequestStatus(this.api);
  @override
  final String api;
}

/// What can be reported with the "Report" button.
enum ReportTarget with ApiEnum {
  lostReport('LOST_REPORT'),
  sighting('SIGHTING'),
  message('MESSAGE');

  const ReportTarget(this.api);
  @override
  final String api;
}

enum ReportReason with ApiEnum {
  spam('SPAM'),
  inappropriate('INAPPROPRIATE'),
  fake('FAKE'),
  dangerous('DANGEROUS'),
  other('OTHER');

  const ReportReason(this.api);
  @override
  final String api;
}

enum MapItemType with ApiEnum {
  lost('lost'),
  sighting('sighting'),
  stray('stray');

  const MapItemType(this.api);
  @override
  final String api;
}

LatLng _location(Map<String, dynamic> json) => LatLng((json['lat'] as num).toDouble(), (json['lon'] as num).toDouble());

Map<String, double> locationJson(LatLng point) => {'lat': point.latitude, 'lon': point.longitude};

DateTime _date(String value) => DateTime.parse(value).toLocal();

DateTime? _optionalDate(String? value) => value == null ? null : _date(value);

/// Photo URLs from the API are relative.
String? absoluteUrl(String? path) => path == null ? null : '${Config.apiUrl}$path';

class User {
  User.fromJson(Map<String, dynamic> json)
    : id = json['id'],
      email = json['email'],
      displayName = json['display_name'],
      role = _enum(Role.values, json['role']),
      associationName = json['association_name'];

  final String id;
  final String email;
  final String displayName;
  final Role role;
  final String? associationName; // set once an admin approved their association

  bool get isAdmin => role == Role.admin;
}

class Photo {
  Photo.fromJson(Map<String, dynamic> json)
    : id = json['id'],
      status = json['status'],
      url = absoluteUrl(json['url'])!,
      cropUrl = absoluteUrl(json['crop_url']);

  final String id;
  final String status; // PENDING, PROCESSING, READY, NO_ANIMAL, SKIPPED, FAILED
  final String url;
  final String? cropUrl;

  bool get isProcessing => status == 'PENDING' || status == 'PROCESSING';
}

class LostReport {
  LostReport.fromJson(Map<String, dynamic> json)
    : id = json['id'],
      name = json['name'],
      species = _enum(Species.values, json['species']),
      description = json['description'],
      lastSeen = _location(json['last_seen']),
      locationIsApproximate = json['location_is_approximate'],
      lastSeenAt = _date(json['last_seen_at']),
      status = _enum(ReportStatus.values, json['status']),
      photos = [for (final p in json['photos']) Photo.fromJson(p)],
      hidden = json['hidden'] ?? false;

  final String id;
  final String name;
  final Species species;
  final String? description;
  final LatLng lastSeen;
  final bool locationIsApproximate; // true unless it's your report
  final DateTime lastSeenAt;
  final ReportStatus status;
  final List<Photo> photos;
  final bool hidden; // reported by several people: only the owner sees it

  bool get isMine => !locationIsApproximate;
}

class Sighting {
  Sighting.fromJson(Map<String, dynamic> json)
    : id = json['id'],
      species = _enum(Species.values, json['species']),
      location = _location(json['location']),
      seenAt = _date(json['seen_at']),
      condition = _enum(Condition.values, json['condition']),
      note = json['note'],
      isStray = json['is_stray'],
      strayStatus = _enum(StrayStatus.values, json['stray_status'] ?? 'AROUND'),
      strayStatusAt = _optionalDate(json['stray_status_at']),
      helpedBy = json['helped_by'],
      isMine = json['mine'],
      photos = [for (final p in json['photos']) Photo.fromJson(p)],
      hidden = json['hidden'] ?? false;

  final String id;
  final Species species;
  final LatLng location;
  final DateTime seenAt;
  final Condition condition;
  final String? note;
  final bool isStray;
  final StrayStatus strayStatus;
  final DateTime? strayStatusAt;
  final String? helpedBy; // the association that helped this stray
  final bool isMine;
  final List<Photo> photos;
  final bool hidden;

  bool get needsHelp => condition != Condition.healthy;
}

class MapItem {
  MapItem.fromJson(Map<String, dynamic> json)
    : type = _enum(MapItemType.values, json['type']),
      id = json['id'],
      species = _enum(Species.values, json['species']),
      location = _location(json['location']),
      date = _date(json['date']),
      name = json['name'],
      condition = json['condition'] == null ? null : _enum(Condition.values, json['condition']),
      photoUrl = absoluteUrl(json['photo_url']);

  final MapItemType type;
  final String id;
  final Species species;
  final LatLng location;
  final DateTime date;
  final String? name;
  final Condition? condition;
  final String? photoUrl;
}

class Match {
  Match.fromJson(Map<String, dynamic> json)
    : id = json['id'],
      lostReportId = json['lost_report_id'],
      lostReportName = json['lost_report_name'],
      score = (json['score'] as num).toDouble(),
      status = _enum(MatchStatus.values, json['status']),
      sighting = Sighting.fromJson(json['sighting']),
      lostPhotoUrl = absoluteUrl(json['lost_photo_url']),
      sightingPhotoUrl = absoluteUrl(json['sighting_photo_url']),
      reportStatus = _enum(ReportStatus.values, json['report_status']),
      conversationId = json['conversation_id'],
      createdAt = _date(json['created_at']);

  final String id;
  final String lostReportId;
  final String lostReportName;
  final double score;
  final MatchStatus status;
  final Sighting sighting;
  final String? lostPhotoUrl;
  final String? sightingPhotoUrl;
  final ReportStatus reportStatus;
  final String? conversationId; // null until the owner starts one
  final DateTime createdAt;
}

class ChatMessage {
  ChatMessage.fromJson(Map<String, dynamic> json)
    : id = json['id'],
      body = json['body'],
      mine = json['mine'],
      hidden = json['hidden'] ?? false,
      createdAt = _date(json['created_at']);

  final String id;
  final String body;
  final bool mine;
  final bool hidden; // reported: the other person no longer sees it
  final DateTime createdAt;
}

/// A conversation as one participant sees it: [otherName] is the person they talk to.
class Conversation {
  Conversation.fromJson(Map<String, dynamic> json)
    : id = json['id'],
      lostReportId = json['lost_report_id'],
      petName = json['pet_name'],
      reportStatus = _enum(ReportStatus.values, json['report_status']),
      matchId = json['match_id'],
      sightingPhotoUrl = absoluteUrl(json['sighting_photo_url']),
      isOwner = json['my_role'] == 'owner',
      otherName = json['other_name'],
      otherAssociation = json['other_association'],
      lastMessage = json['last_message'] == null ? null : ChatMessage.fromJson(json['last_message']),
      unread = json['unread'],
      createdAt = _date(json['created_at']);

  final String id;
  final String lostReportId;
  final String petName;
  final ReportStatus reportStatus;
  final String? matchId;
  final String? sightingPhotoUrl;
  final bool isOwner; // false: I'm the finder
  final String otherName;
  final String? otherAssociation; // the association they speak for, if any
  final ChatMessage? lastMessage;
  final int unread;
  final DateTime createdAt;

  bool get caseClosed => reportStatus != ReportStatus.open;
}

/// A request to be shown as an association. user_name and user_email are for the admin.
class AssociationRequest {
  AssociationRequest.fromJson(Map<String, dynamic> json)
    : id = json['id'],
      organisation = json['organisation'],
      city = json['city'],
      contact = json['contact'],
      note = json['note'],
      status = _enum(RequestStatus.values, json['status']),
      userName = json['user_name'],
      userEmail = json['user_email'],
      createdAt = _date(json['created_at']);

  final String id;
  final String organisation;
  final String city;
  final String contact;
  final String? note;
  final RequestStatus status;
  final String? userName;
  final String? userEmail;
  final DateTime createdAt;
}

/// Content hidden after reports, for the admin to restore or delete.
class HiddenItem {
  HiddenItem.fromJson(Map<String, dynamic> json)
    : type = _enum(ReportTarget.values, json['target_type']),
      id = json['target_id'],
      title = json['title'],
      text = json['text'],
      photoUrl = absoluteUrl(json['photo_url']),
      hiddenAt = _date(json['hidden_at']),
      reports = json['reports'],
      reasons = [for (final r in json['reasons']) _enum(ReportReason.values, r)],
      notes = [for (final n in json['notes']) n as String];

  final ReportTarget type;
  final String id;
  final String? title; // pet name, species, or the sender's name
  final String? text;
  final String? photoUrl;
  final DateTime hiddenAt;
  final int reports;
  final List<ReportReason> reasons;
  final List<String> notes;
}
