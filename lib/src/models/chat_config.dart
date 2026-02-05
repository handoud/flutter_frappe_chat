class FrappeChatConfig {
  final String baseUrl;
  final String? apiSecret;
  final String? apiKey;
  final bool verifyInsecure;

  FrappeChatConfig({
    required this.baseUrl,
    this.apiSecret,
    this.apiKey,
    this.verifyInsecure = false,
  });

  String get socketUrl => baseUrl;
}
