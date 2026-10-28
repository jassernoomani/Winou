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

/// Where a photo came from. Sent with uploads; the API keeps it for moderation only.
enum PhotoSource with ApiEnum {
  camera('CAMERA'),
  gallery('GALLERY');

  const PhotoSource(this.api);
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

/// Photo URLs from the API are relative.
String? absoluteUrl(String? path) => path == null ? null : '${Config.apiUrl}$path';

class User {
  User.fromJson(Map<String, dynamic> json) : id = json['id'], email = json['email'], displayName = json['display_name'];

  final String id;
  final String email;
  final String displayName;
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
      photos = [for (final p in json['photos']) Photo.fromJson(p)];

  final String id;
  final String name;
  final Species species;
  final String? description;
  final LatLng lastSeen;
  final bool locationIsApproximate; // true unless it's your report
  final DateTime lastSeenAt;
  final ReportStatus status;
  final List<Photo> photos;

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
      isMine = json['mine'],
      photos = [for (final p in json['photos']) Photo.fromJson(p)];

  final String id;
  final Species species;
  final LatLng location;
  final DateTime seenAt;
  final Condition condition;
  final String? note;
  final bool isStray;
  final bool isMine;
  final List<Photo> photos;
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
      status = json['status'],
      sighting = Sighting.fromJson(json['sighting']),
      lostPhotoUrl = absoluteUrl(json['lost_photo_url']),
      sightingPhotoUrl = absoluteUrl(json['sighting_photo_url']),
      createdAt = _date(json['created_at']);

  final String id;
  final String lostReportId;
  final String lostReportName;
  final double score;
  final String status;
  final Sighting sighting;
  final String? lostPhotoUrl;
  final String? sightingPhotoUrl;
  final DateTime createdAt;
}
