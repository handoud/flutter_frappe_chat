/// A Flutter package for integrating Frappe Chat into Flutter applications.
///
/// This library provides a complete chat solution with real-time messaging via WebSockets,
/// file uploads, audio recording, and a customizable UI. It connects to Frappe's chat API
/// and provides widgets for displaying chat interfaces.
///
/// Example usage:
/// ```dart
/// final config = FrappeChatConfig(
///   baseUrl: 'https://your-frappe-site.com',
///   apiKey: 'your_api_key',
///   apiSecret: 'your_api_secret',
/// );
///
/// Navigator.push(
///   context,
///   MaterialPageRoute(
///     builder: (context) => ChatScreen(
///       config: config,
///       room: 'room-id',
///       sender: 'username',
///       senderEmail: 'user@example.com',
///     ),
///   ),
/// );
/// ```
library flutter_frappe_chat;

export 'src/api/frappe_api.dart';
export 'src/socket/socket_manager.dart';
export 'src/screens/chat_screen.dart';
export 'src/models/chat_message.dart';
export 'src/models/chat_config.dart';
