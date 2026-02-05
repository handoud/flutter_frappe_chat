class FrappeChatConfig {
  final String baseUrl;
  final String? apiSecret;
  final String? apiKey;
  final String? cookie; // e.g., "sid=..."
  final String? sid; // Just the session ID
  final bool verifyInsecure;

  FrappeChatConfig({
    required this.baseUrl,
    this.apiSecret,
    this.apiKey,
    this.cookie,
    this.sid,
    this.verifyInsecure = false,
  });

  String get socketUrl => baseUrl;

  String? get cookieHeader {
    if (cookie != null) return cookie;
    if (sid != null) return "sid=$sid";
    return null;
  }
}
