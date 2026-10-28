/// Build-time configuration, passed with --dart-define (see mobile/README.md).
class Config {
  /// Base URL of the Winou API. On a phone this is the laptop's LAN address.
  static const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:8080');

  /// Where the map opens before the GPS answers: Tunis.
  static const defaultLat = 36.8065;
  static const defaultLon = 10.1815;
}
