/// Central configuration for all remote sync + data-collection features.
///
/// Everything here is *inert by default*: if a URL/token is empty, the
/// corresponding feature simply queues locally and does nothing over the
/// network. Fill these in (or override at build time with --dart-define) to
/// activate cloud sync and the training-data upload pipeline.
///
/// SECURITY NOTE: Any value shipped in the app binary can be extracted from
/// the APK/IPA. The Turso token below grants read/write to the shared sync
/// database, so it is only appropriate for a personal / small-group app, not
/// for public distribution. Rows are partitioned per-user so each device only
/// ever reads back its own data.
class SyncConfig {
  // ---------------------------------------------------------------------------
  // TURSO (structured data sync — meals, weight, supplements, profile, goals)
  // ---------------------------------------------------------------------------

  /// Turso database URL. Use the HTTPS form (the client also accepts the
  /// libsql:// / turso:// form and upgrades it to https automatically).
  /// Example: https://your-db-yourorg.turso.io
  static const String tursoUrl = String.fromEnvironment(
    'TURSO_URL',
    defaultValue: '',
  );

  /// Turso auth token (Bearer). Create with: `turso db tokens create <db>`.
  static const String tursoAuthToken = String.fromEnvironment(
    'TURSO_AUTH_TOKEN',
    defaultValue: '',
  );

  static bool get tursoEnabled =>
      tursoUrl.isNotEmpty && tursoAuthToken.isNotEmpty;

  // ---------------------------------------------------------------------------
  // TRAINING-DATA ENDPOINT (private laptop server — meal image + AI analysis)
  // ---------------------------------------------------------------------------

  /// Base URL of your private training-data collector, e.g.
  /// http://192.168.1.42:8080  (no trailing slash). The client POSTs to
  /// `{trainingEndpointBaseUrl}/upload` as multipart/form-data.
  static const String trainingEndpointBaseUrl = String.fromEnvironment(
    'TRAINING_ENDPOINT',
    defaultValue: '',
  );

  /// Optional bearer token for the training endpoint. Empty = no auth header.
  static const String trainingEndpointToken = String.fromEnvironment(
    'TRAINING_TOKEN',
    defaultValue: '',
  );

  static bool get trainingEndpointConfigured =>
      trainingEndpointBaseUrl.isNotEmpty;

  static String get trainingUploadUrl {
    final base = trainingEndpointBaseUrl.endsWith('/')
        ? trainingEndpointBaseUrl.substring(0, trainingEndpointBaseUrl.length - 1)
        : trainingEndpointBaseUrl;
    return '$base/upload';
  }

  /// Health/reachability probe path used to decide whether to attempt uploads.
  static String get trainingHealthUrl {
    final base = trainingEndpointBaseUrl.endsWith('/')
        ? trainingEndpointBaseUrl.substring(0, trainingEndpointBaseUrl.length - 1)
        : trainingEndpointBaseUrl;
    return '$base/health';
  }
}
