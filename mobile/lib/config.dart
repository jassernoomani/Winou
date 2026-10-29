/// Build-time configuration, passed with --dart-define (see mobile/README.md).
class Config {
  /// The API address the app is built with. On a phone this is the laptop's address.
  static const defaultApiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:8080');

  /// The API address in use: the build's default, or the one saved in the app (widgets/server_settings.dart),
  /// so one build works on any network the laptop and phone share.
  static String apiUrl = defaultApiUrl;

  /// Where the map opens before the GPS answers: Tunis.
  static const defaultLat = 36.8065;
  static const defaultLon = 10.1815;
}
