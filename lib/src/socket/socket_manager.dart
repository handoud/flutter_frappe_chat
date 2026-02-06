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
  IO.Socket? socket;

  /// The configuration containing server URL and authentication details.
  final FrappeChatConfig config;

  /// Callback invoked when a new message is received.
  ///
  /// Set this to handle incoming chat messages in real-time.
  Function(ChatMessage)? onMessageReceived;

  /// Callback invoked when typing status changes.
  ///
  /// Set this to update the UI when other users start or stop typing.
  /// Passes [isTyping] status and the [user] who is typing.
  Function(bool, String)? onTypingChanged;

  /// Callback invoked when chat data is updated.
  ///
  /// Set this to handle general chat updates from the server.
  Function(Map<String, dynamic>)? onChatUpdate;

  /// Callback invoked when a message is updated (e.g. marked as seen).
  Function(ChatMessage)? onMessageUpdated;

  /// Creates a new [FrappeSocketManager] with the given [config].
  FrappeSocketManager(this.config);

  /// Establishes a WebSocket connection to the Frappe server.
  ///
  /// If [room] is provided, it automatically subscribes to that room.
  void connect({String? room}) {
    if (socket?.connected == true) {
      if (room != null) subscribeToRoom(room);
      return;
    }

    socket = IO.io(
      config.socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    socket!.io.options?['extraHeaders'] = {
      if (config.apiKey != null && config.apiSecret != null)
        'Authorization': 'token ${config.apiKey}:${config.apiSecret}'
      else if (config.cookieHeader != null)
        'Cookie': config.cookieHeader!
    };

    socket!.connect();

    socket!.onConnect((_) {
      debugPrint('Connected to Socket.IO');
      if (room != null) {
        subscribeToRoom(room);
      }
    });

    socket!.onDisconnect((_) => debugPrint('Disconnected from Socket.IO'));
    socket!.onError((data) => debugPrint('Socket Error: $data'));
  }

  /// Subscribes to a specific room's events.
  void subscribeToRoom(String room) {
    debugPrint("🔌 FrappeSocketManager: Subscribing to room: $room");
    if (socket == null) {
      debugPrint("⚠️ FrappeSocketManager: Socket is null, cannot subscribe.");
      return;
    }

    // Listen for new messages
    socket!.on(room, (data) {
      debugPrint(
          "📩 FrappeSocketManager: Received event on room '$room': $data");
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
    socket!.on("$room:typing", (data) {
      if (data != null && onTypingChanged != null) {
        bool isTyping = data['is_typing'].toString().toLowerCase() == 'true';
        String user = data['user']?.toString() ?? 'Unknown';
        onTypingChanged!(isTyping, user);
      }
    });

    // Listen for message updates (e.g. read receipts)
    // We listen to both 'doc_update' and custom 'message_update' just in case
    void handleUpdate(data) {
      debugPrint(
          "📩 FrappeSocketManager: Received update on room '$room': $data");
      if (data != null && onMessageUpdated != null) {
        try {
          // check if it's a Chat Message
          if (data['doctype'] == 'Chat Message' || data['message'] != null) {
            final msgData = data['doc'] ?? data['message'] ?? data;
            final message =
                ChatMessage.fromJson(Map<String, dynamic>.from(msgData));
            onMessageUpdated!(message);
          }
        } catch (e) {
          debugPrint("Error parsing message update: $e");
        }
      }
    }

    socket!.on("doc_update", handleUpdate);
    socket!.on("message_update", handleUpdate);
  }

  /// Unsubscribes from a specific room.
  void unsubscribeFromRoom(String room) {
    debugPrint("Unsubscribing from room: $room");
    socket?.off(room);
    socket?.off("$room:typing");
    socket?.off("doc_update");
    socket?.off("message_update");
  }

  /// Sets up event listeners for the specified [room].
  /// Kept for internal usage or backward compatibility if needed.
  void _setupListeners(String room) {
    subscribeToRoom(room);

    // Listen for chat updates (Global?)
    socket?.on("latest_chat_updates", (data) {
      if (data != null && onChatUpdate != null) {
        onChatUpdate!(Map<String, dynamic>.from(data));
      }
    });
  }

  /// Sends a typing status update to the server.
  void sendTyping(String room, String user, bool isTyping) {
    if (socket?.connected == true) {
      socket!.emit('doc_events', {
        'doctype': 'Chat Room',
        'docname': room,
        'cmd': 'set_typing',
        'room': room,
        'user': user,
        'is_typing': isTyping,
      });
    }
  }

  /// Disconnects the WebSocket connection.
  void disconnect() {
    socket?.disconnect();
  }

  /// Listens to ALL incoming events on the socket.
  ///
  /// This is useful for debugging or global filtering (e.g. tracking mentions).
  /// [callback] receives the event name and the data payload.
  void listenToAllEvents(Function(String event, dynamic data) callback) {
    if (socket == null) return;
    socket!.onAny((event, data) {
      callback(event, data);
    });
  }
}
