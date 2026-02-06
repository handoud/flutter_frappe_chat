/// Configuration class for connecting to a Frappe Chat server.
///
/// This class holds all the necessary connection details including URL and authentication
/// credentials. You can authenticate using either API keys or session cookies.
///
/// Example:
/// ```dart
/// // Using API keys
/// final config = FrappeChatConfig(
///   baseUrl: 'https://your-frappe-site.com',
///   apiKey: 'your_api_key',
///   apiSecret: 'your_api_secret',
/// );
///
/// // Using session ID
/// final config = FrappeChatConfig(
///   baseUrl: 'https://your-frappe-site.com',
///   sid: 'your_session_id',
/// );
/// ```
class FrappeChatConfig {
  /// The base URL of the Frappe site (e.g., 'https://example.erpnext.com').
  final String baseUrl;

  /// The API secret for token-based authentication.
  ///
  /// Use this in combination with [apiKey] for secure API access.
  final String? apiSecret;

  /// The API key for token-based authentication.
  ///
  /// Use this in combination with [apiSecret] for secure API access.
  final String? apiKey;

  /// The complete cookie string (e.g., "sid=...").
  ///
  /// Use this for session-based authentication. Either provide the complete cookie
  /// string here or just the session ID in [sid].
  final String? cookie;

  /// The session ID for cookie-based authentication.
  ///
  /// This will be formatted as "sid=..." when sent in requests.
  final String? sid;

  /// Whether to skip SSL certificate verification.
  ///
  /// Set to true only for development environments with self-signed certificates.
  /// Defaults to false for security.
  final bool verifyInsecure;

  /// Creates a new [FrappeChatConfig] instance.
  ///
  /// The [baseUrl] is required. For authentication, provide either:
  /// - Both [apiKey] and [apiSecret] for token-based auth, or
  /// - [cookie] or [sid] for session-based auth.
  FrappeChatConfig({
    required this.baseUrl,
    this.apiSecret,
    this.apiKey,
    this.cookie,
    this.sid,
    this.verifyInsecure = false,
    this.socketUrlOverride,
  });

  /// Optional override for the WebSocket URL.
  ///
  /// If provided, this will be used instead of [baseUrl] for socket connections.
  /// Useful when the socket server is on a different URL or path (e.g. "https://site.com/site_name").
  final String? socketUrlOverride;

  /// Returns the WebSocket URL for real-time connections.
  ///
  /// Returns [socketUrlOverride] if set, otherwise [baseUrl].
  String get socketUrl => socketUrlOverride ?? baseUrl;

  /// Returns the formatted cookie header string for HTTP requests.
  ///
  /// Returns the [cookie] if provided, otherwise formats [sid] as "sid=...",
  /// or null if neither is available.
  String? get cookieHeader {
    if (cookie != null) return cookie;
    if (sid != null) return "sid=$sid";
    return null;
  }
}
