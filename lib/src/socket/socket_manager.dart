import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/chat_config.dart';
import '../models/chat_message.dart';

/// Manages WebSocket connections to the Frappe Chat server for real-time updates.
///
/// This class handles:
/// - Establishing and maintaining WebSocket connections
/// - Listening for incoming messages
/// - Listening for typing indicators
/// - Sending typing status updates
/// - Handling connection lifecycle
///
/// Example usage:
/// ```dart
/// final socketManager = FrappeSocketManager(config);
/// 
/// socketManager.onMessageReceived = (message) {
///   print('New message: ${message.content}');
/// };
/// 
/// socketManager.onTypingChanged = (isTyping) {
///   print('User is typing: $isTyping');
/// };
/// 
/// socketManager.connect('room-id');
/// ```
class FrappeSocketManager {
  /// The Socket.IO connection instance.
  late IO.Socket socket;
  
  /// The configuration containing server URL and authentication details.
  final FrappeChatConfig config;

  /// Callback invoked when a new message is received.
  ///
  /// Set this to handle incoming chat messages in real-time.
  Function(ChatMessage)? onMessageReceived;
  
  /// Callback invoked when typing status changes.
  ///
  /// Set this to update the UI when other users start or stop typing.
  Function(bool)? onTypingChanged;
  
  /// Callback invoked when chat data is updated.
  ///
  /// Set this to handle general chat updates from the server.
  Function(Map<String, dynamic>)? onChatUpdate;

  /// Creates a new [FrappeSocketManager] with the given [config].
  FrappeSocketManager(this.config);

  /// Establishes a WebSocket connection to the Frappe server for the specified [room].
  ///
  /// This method:
  /// 1. Creates a Socket.IO connection with authentication headers
  /// 2. Connects to the server
  /// 3. Sets up event listeners for messages, typing, and updates
  ///
  /// The connection is automatically authenticated using credentials from [config].
  void connect(String room) {
    socket = IO.io(
      config.socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    socket.io.options?['extraHeaders'] = {
      if (config.apiKey != null && config.apiSecret != null)
        'Authorization': 'token ${config.apiKey}:${config.apiSecret}'
      else if (config.cookieHeader != null)
        'Cookie': config.cookieHeader!
    };

    socket.connect();

    socket.onConnect((_) {
      debugPrint('Connected to Socket.IO');
      _setupListeners(room);
    });

    socket.onDisconnect((_) => debugPrint('Disconnected from Socket.IO'));
    socket.onError((data) => debugPrint('Socket Error: $data'));
  }

  /// Sets up event listeners for the specified [room].
  ///
  /// Listens for:
  /// - New messages on the room channel
  /// - Typing indicators on the "room:typing" channel
  /// - General chat updates on "latest_chat_updates"
  void _setupListeners(String room) {
    // Listen for new messages
    socket.on(room, (data) {
      if (data != null && onMessageReceived != null) {
        try {
          final message = ChatMessage.fromJson(Map<String, dynamic>.from(data));
          onMessageReceived!(message);
        } catch (e) {
          debugPrint("Error parsing message: $e");
        }
      }
    });

    // Listen for typing events
    socket.on("$room:typing", (data) {
      if (data != null && onTypingChanged != null) {
        // data = { "room": room, "user": user, "is_typing": "false/true", ... }
        // We can parse 'is_typing'
        bool isTyping = data['is_typing'].toString().toLowerCase() == 'true';
        onTypingChanged!(isTyping);
      }
    });

    // Listen for chat updates
    socket.on("latest_chat_updates", (data) {
      if (data != null && onChatUpdate != null) {
        onChatUpdate!(Map<String, dynamic>.from(data));
      }
    });
  }

  /// Sends a typing status update to the server.
  ///
  /// Emits a typing event for the specified [room] and [user].
  /// Set [isTyping] to true when the user starts typing and false when they stop.
  ///
  /// Note: This emits a socket event. Depending on your Frappe configuration,
  /// you might also need to call the REST API endpoint via [FrappeApiService.setTyping].
  void sendTyping(String room, String user, bool isTyping) {
    if (socket.connected) {
      socket.emit('doc_events', {
        'doctype': 'Chat Room',
        'docname': room,
        'cmd': 'set_typing',
        'room': room,
        'user': user,
        'is_typing': isTyping,
        'is_guest': false, // Todo: make configurable
      });
      // Note: Frappe chat might expect a specific POST call to set_typing endpoint which then emits the event,
      // OR it might listen to a socket event.
      // Based on the python code `api/message.py`, `set_typing` is a whitelisted function.
      // So we should probably call the API instead of emitting socket event directly if that's how it's designed.
      // BUT, usually socket implementations allow emitting directly if configured.
      // For now, we will add an API method for typing in the ApiService and call it from the UI or here.
    }
  }

  /// Disconnects the WebSocket connection.
  ///
  /// Call this when the chat screen is disposed to properly clean up resources.
  void disconnect() {
    socket.disconnect();
  }
}
