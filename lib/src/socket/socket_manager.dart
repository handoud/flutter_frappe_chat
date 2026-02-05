import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/chat_config.dart';
import '../models/chat_message.dart';

class FrappeSocketManager {
  late IO.Socket socket;
  final FrappeChatConfig config;

  // Callbacks
  Function(ChatMessage)? onMessageReceived;
  Function(bool)? onTypingChanged;
  Function(Map<String, dynamic>)? onChatUpdate;

  FrappeSocketManager(this.config);

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
        'Authorization': 'token ${config.apiKey}:${config.apiSecret}',
    };

    socket.connect();

    socket.onConnect((_) {
      debugPrint('Connected to Socket.IO');
      _setupListeners(room);
    });

    socket.onDisconnect((_) => debugPrint('Disconnected from Socket.IO'));
    socket.onError((data) => debugPrint('Socket Error: $data'));
  }

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

  void disconnect() {
    socket.disconnect();
  }
}
