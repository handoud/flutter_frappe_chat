/// Connection and behaviour settings for a Frappe Chat server.
///
/// Authenticate with either an API key pair or a session id:
///
/// ```dart
/// // Token auth
/// final config = FrappeChatConfig(
///   baseUrl: 'https://erp.example.com',
///   apiKey: 'key',
///   apiSecret: 'secret',
/// );
///
/// // Session auth (e.g. from flutter_next_auth)
/// final config = FrappeChatConfig(
///   baseUrl: 'https://erp.example.com',
///   sid: await flutternext.getStoredSid(),
/// );
/// ```
class FrappeChatConfig {
  /// The site root, e.g. `https://erp.example.com`. Trailing slashes are
  /// stripped.
  final String baseUrl;

  /// API secret for token authentication.
  final String? apiSecret;

  /// API key for token authentication.
  final String? apiKey;

  /// A complete cookie string, e.g. `"sid=abc123"`.
  final String? cookie;

  /// The session id. Sent as `sid=...` when [cookie] is not set.
  final String? sid;

  /// CSRF token, required only when reusing a session created in a browser.
  ///
  /// Sessions created through `/api/method/login` carry no CSRF token — Frappe
  /// generates one lazily when a desk or website page is rendered — so this is
  /// usually unnecessary.
  final String? csrfToken;

  /// The Frappe **site name**, used as the Socket.IO namespace.
  ///
  /// Frappe's realtime server accepts arbitrary namespaces and then rejects any
  /// that does not match the site name, so connecting to the bare host always
  /// fails. Defaults to the host in [baseUrl], which is correct for almost
  /// every deployment. Set it explicitly for multi-tenant setups or a local
  /// bench where the site name differs from the host (e.g. `mysite.localhost`).
  final String? siteName;

  /// Full override for the WebSocket URL, including the namespace.
  ///
  /// Only needed when the realtime service is on a different host or port.
  /// When set, [siteName] is ignored.
  final String? socketUrlOverride;

  /// Request timeout for HTTP calls.
  final Duration timeout;

  /// Whether uploaded attachments are private.
  ///
  /// Frappe serves `/files/` to **anyone with the URL, with no authentication**,
  /// while `/private/files/` requires a session. Defaults to false to preserve
  /// the behaviour of earlier versions and because the bundled viewers
  /// (image, audio, PDF) cannot send credentials.
  ///
  /// Set this to true for confidential chats and render attachments yourself
  /// with [authHeaders] attached.
  final bool privateAttachments;

  /// How many messages to request per page.
  ///
  /// The stock `chat.api.message.get_all` ignores pagination and returns the
  /// entire room history, so this only takes effect against a server that
  /// accepts `limit_start` / `limit_page_length` — see
  /// [FrappeApiService.getMessages].
  final int pageSize;

  FrappeChatConfig({
    required String baseUrl,
    this.apiSecret,
    this.apiKey,
    this.cookie,
    this.sid,
    this.csrfToken,
    this.siteName,
    this.socketUrlOverride,
    this.timeout = const Duration(seconds: 30),
    this.privateAttachments = false,
    this.pageSize = 50,
  }) : baseUrl = _normalize(baseUrl);

  static String _normalize(String url) {
    var normalized = url.trim();
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  /// Whether API key/secret authentication is configured.
  bool get usesTokenAuth =>
      (apiKey?.isNotEmpty ?? false) && (apiSecret?.isNotEmpty ?? false);

  /// The scheme and host of [baseUrl], e.g. `https://erp.example.com`.
  ///
  /// Frappe's realtime middleware compares the `Origin` header against the
  /// `Host` header and refuses the connection when they differ. Native clients
  /// send no `Origin` at all, so [FrappeSocketManager] sends this one.
  String get origin => Uri.parse(baseUrl).origin;

  /// The resolved site name used as the Socket.IO namespace.
  String get resolvedSiteName => siteName ?? Uri.parse(baseUrl).host;

  /// The Socket.IO URL, including the mandatory site namespace.
  ///
  /// Frappe registers its realtime handlers on `io.of(/^\/.*$/)` and the
  /// authentication middleware rejects any namespace that is not the site name.
  /// Connecting to the bare [baseUrl] therefore always fails with
  /// `Invalid namespace`.
  String get socketUrl => socketUrlOverride ?? '$baseUrl/$resolvedSiteName';

  /// The `Cookie` header for session authentication, or null.
  String? get cookieHeader {
    if (cookie != null && cookie!.isNotEmpty) return cookie;
    if (sid != null && sid!.isNotEmpty) return 'sid=$sid';
    return null;
  }

  /// Headers that authenticate a request, for HTTP calls and for fetching
  /// private attachments in your own widgets.
  Map<String, String> get authHeaders {
    final headers = <String, String>{};

    if (usesTokenAuth) {
      headers['Authorization'] = 'token $apiKey:$apiSecret';
    } else {
      final cookie = cookieHeader;
      if (cookie != null) headers['Cookie'] = cookie;
    }

    if (csrfToken != null) headers['X-Frappe-CSRF-Token'] = csrfToken!;
    return headers;
  }

  /// Returns a copy with the given fields replaced.
  ///
  /// Useful when the session id rotates, for example after a password change.
  FrappeChatConfig copyWith({
    String? baseUrl,
    String? apiKey,
    String? apiSecret,
    String? cookie,
    String? sid,
    String? csrfToken,
    String? siteName,
    String? socketUrlOverride,
    Duration? timeout,
    bool? privateAttachments,
    int? pageSize,
  }) {
    return FrappeChatConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      apiSecret: apiSecret ?? this.apiSecret,
      cookie: cookie ?? this.cookie,
      sid: sid ?? this.sid,
      csrfToken: csrfToken ?? this.csrfToken,
      siteName: siteName ?? this.siteName,
      socketUrlOverride: socketUrlOverride ?? this.socketUrlOverride,
      timeout: timeout ?? this.timeout,
      privateAttachments: privateAttachments ?? this.privateAttachments,
      pageSize: pageSize ?? this.pageSize,
    );
  }
}
