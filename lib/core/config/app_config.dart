/// Build-time configuration. Nothing secret is stored in source code.
///
/// Run with:
///   flutter run --dart-define=AUDIUS_API_KEY=your_key
///
/// Only the API key belongs in a mobile app. The Audius *bearer token* is
/// backend-only and must never be shipped in the app.
class AppConfig {
  static const String appName = 'PulseMusic';

  /// Free key from https://api.audius.co/plans (optional, gives better limits).
  static const String apiKey = String.fromEnvironment('AUDIUS_API_KEY');

  static const String _primary = String.fromEnvironment(
    'AUDIUS_BASE_URL',
    defaultValue: 'https://api.audius.co/v1',
  );

  /// Optional second host used if the primary is unreachable.
  static const String _fallback = String.fromEnvironment('AUDIUS_FALLBACK_URL');

  /// Optional Jamendo client id (free at https://devportal.jamendo.com/).
  /// When empty, Jamendo is switched off and Audius is the only source.
  /// Jamendo's free API tier is for non-commercial apps only.
  static const String jamendoClientId = String.fromEnvironment('JAMENDO_CLIENT_ID');
  static bool get jamendoEnabled => jamendoClientId.isNotEmpty;

  static List<String> get hosts => [
        _primary,
        if (_fallback.isNotEmpty && _fallback != _primary) _fallback,
      ];
}
