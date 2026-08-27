import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../models/chat_config.dart';
import '../models/chat_message.dart';
import '../models/chat_theme.dart';

/// Maintains the Socket.IO connection to Frappe's realtime service.
///
/// Frappe's realtime server is stricter than a plain Socket.IO server, and two
/// of its checks reject a naive client outright:
///
/// * **The namespace must be the site name.** Handlers are registered on
///   `io.of(/^\/.*$/)` and the auth middleware refuses anything else with
///   `Invalid namespace`. [FrappeChatConfig.socketUrl] appends it for you.
/// * **`Origin` must match `Host`.** Native Dart clients send no `Origin`
///   header, so the middleware sees `undefined` and refuses with
///   `Invalid origin`. This class sends one.
///
/// Both failures arrive on `connect_error`, which is surfaced through
/// [connectionStatus] rather than being swallowed.
///
/// ```dart
/// final socket = FrappeSocketManager(config)
///   ..onMessageReceived = (message) => print(message.content);
///
/// socket.connectionStatus.addListener(() {
///   print(socket.connectionStatus.value);
/// });
///
/// socket.connect(room: 'room-id');
/// ```
class FrappeSocketManager {
  /// The underlying socket, exposed for advanced use.
  io.Socket? socket;

  /// Connection settings.
  final FrappeChatConfig config;

  /// Called for each message received in the subscribed room.
  void Function(ChatMessage message)? onMessageReceived;

  /// Called when someone starts or stops typing. Receives the typing flag and
  /// the user's display name.
  void Function(bool isTyping, String user)? onTypingChanged;

  /// Called for `latest_chat_updates`, which Frappe Chat publishes for room
  /// list previews and unread badges.
  void Function(Map<String, dynamic> update)? onChatUpdate;

  /// The current realtime connection state, including the failure reason.
  ///
  /// Drive your connection indicator from this — never from the fact that
  /// [connect] was called.
  final ValueNotifier<ChatConnectionStatus> connectionStatus =
      ValueNotifier(const ChatConnectionStatus(ChatConnectionState.disconnected));

  String? _room;
  bool _disposed = false;

  FrappeSocketManager(this.config);

  /// Whether the socket is currently connected.
  bool get isConnected => socket?.connected == true;

  /// Connects and, when [room] is given, subscribes to it.
  ///
  /// Safe to call repeatedly: an existing connection is reused and only the
  /// room subscription is refreshed.
  void connect({String? room}) {
    if (_disposed) return;
    _room = room ?? _room;

    if (socket != null) {
      if (isConnected && _room != null) _subscribe(_room!);
      return;
    }

    connectionStatus.value =
        const ChatConnectionStatus(ChatConnectionState.connecting);

    final headers = <String, String>{
      // Frappe compares Origin against Host and refuses a mismatch. A native
      // client sends neither, so both must be set explicitly.
      'Origin': config.origin,
      // Needed by multi-tenant benches to resolve the site before auth runs.
      'x-frappe-site-name': config.resolvedSiteName,
      ...config.authHeaders,
    };

    socket = io.io(
      config.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setExtraHeaders(headers)
          .enableReconnection()
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(10000)
          .disableAutoConnect()
          .build(),
    );

    socket!
      ..onConnect((_) {
        debugPrint('flutter_frappe_chat: connected to ${config.socketUrl}');
        connectionStatus.value =
            const ChatConnectionStatus(ChatConnectionState.connected);
        if (_room != null) _subscribe(_room!);
      })
      ..onDisconnect((_) {
        connectionStatus.value =
            const ChatConnectionStatus(ChatConnectionState.disconnected);
      })
      ..onConnectError(_handleConnectError)
      ..onError(_handleConnectError);

    socket!.connect();
  }

  void _handleConnectError(dynamic error) {
    final reason = _describe(error);
    debugPrint('flutter_frappe_chat: connection failed — $reason');

    if (reason.contains('Invalid namespace')) {
      debugPrint(
        'flutter_frappe_chat: the Socket.IO namespace must equal the Frappe '
        'site name. Connecting to "${config.socketUrl}". If the site name '
        'differs from the host, set FrappeChatConfig.siteName.',
      );
    } else if (reason.contains('Invalid origin')) {
      debugPrint(
        'flutter_frappe_chat: Frappe rejected the Origin header '
        '"${config.origin}". It must match the host serving the realtime '
        'service.',
      );
    } else if (reason.contains('Unauthorized')) {
      debugPrint(
        'flutter_frappe_chat: authentication failed. Check the sid or the '
        'API key and secret.',
      );
    }

    connectionStatus.value =
        ChatConnectionStatus(ChatConnectionState.failed, reason);
  }

  static String _describe(dynamic error) {
    if (error == null) return 'unknown error';
    if (error is Map) return error['message']?.toString() ?? error.toString();
    return error.toString();
  }

  /// Subscribes to a room, replacing any previous subscription.
  void subscribeToRoom(String room) {
    _room = room;
    if (socket == null) {
      debugPrint('flutter_frappe_chat: not connected; call connect() first');
      return;
    }
    _subscribe(room);
  }

  void _subscribe(String room) {
    // Socket.IO's `on` appends listeners rather than replacing them, and
    // onConnect fires again after every automatic reconnect. Without this
    // removal each reconnect would duplicate every incoming message.
    _removeListeners(room);

    socket!.on(room, (data) {
      if (data == null || onMessageReceived == null) return;
      try {
        onMessageReceived!(ChatMessage.fromJson(data));
      } catch (e) {
        debugPrint('flutter_frappe_chat: could not parse message — $e');
      }
    });

    socket!.on('$room:typing', (data) {
      if (data is! Map || onTypingChanged == null) return;
      final isTyping = data['is_typing'].toString().toLowerCase() == 'true';
      onTypingChanged!(isTyping, data['user']?.toString() ?? 'Someone');
    });

    socket!.on('latest_chat_updates', (data) {
      if (data is! Map || onChatUpdate == null) return;
      onChatUpdate!(Map<String, dynamic>.from(data));
    });
  }

  void _removeListeners(String room) {
    socket?.off(room);
    socket?.off('$room:typing');
    socket?.off('latest_chat_updates');
  }

  /// Unsubscribes from a room.
  void unsubscribeFromRoom(String room) {
    _removeListeners(room);
    if (_room == room) _room = null;
  }

  /// Subscribes to realtime updates for a specific document.
  ///
  /// Frappe only delivers `doc_update` events to subscribers of that document's
  /// room, so this call is required before such events arrive.
  void subscribeToDoc(String doctype, String docname) {
    socket?.emit('doc_subscribe', [doctype, docname]);
  }

  /// Unsubscribes from a document's updates.
  void unsubscribeFromDoc(String doctype, String docname) {
    socket?.emit('doc_unsubscribe', [doctype, docname]);
  }

  /// Listens to every event, for debugging.
  void listenToAllEvents(void Function(String event, dynamic data) callback) {
    socket?.onAny((event, data) => callback(event, data));
  }

  /// Disconnects without tearing down the manager.
  void disconnect() {
    if (_room != null) _removeListeners(_room!);
    socket?.disconnect();
    connectionStatus.value =
        const ChatConnectionStatus(ChatConnectionState.disconnected);
  }

  /// Releases the socket and every listener.
  ///
  /// Always call this from your widget's `dispose`: without it the callbacks
  /// keep the disposed State object alive.
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    onMessageReceived = null;
    onTypingChanged = null;
    onChatUpdate = null;

    if (_room != null) _removeListeners(_room!);
    socket?.dispose();
    socket = null;

    connectionStatus.dispose();
  }
}
