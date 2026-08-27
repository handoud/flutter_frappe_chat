import 'dart:async';
import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';

import '../api/frappe_api.dart';
import '../models/chat_config.dart';
import '../models/chat_message.dart';
import '../models/chat_theme.dart';
import '../socket/socket_manager.dart';
import '../utils/file_io.dart';
import '../widgets/attachment_sheet.dart';
import '../widgets/message_bubble.dart';
import '../widgets/recording_input.dart';
import '../widgets/typing_indicator.dart';

/// A ready-made chat screen for a Frappe Chat room.
///
/// Handles history loading, realtime updates, attachments, voice notes and
/// typing indicators. Pass a [theme] to match your app, or build your own UI on
/// [FrappeApiService] and [FrappeSocketManager] directly.
///
/// ```dart
/// Navigator.push(context, MaterialPageRoute(
///   builder: (_) => ChatScreen(
///     config: config,
///     room: 'room-id',
///     sender: 'Jane Doe',
///     senderEmail: 'jane@example.com',
///     chatPartnerName: 'Support',
///     theme: FrappeChatTheme.fromTheme(Theme.of(context)),
///   ),
/// ));
/// ```
class ChatScreen extends StatefulWidget {
  /// Connection settings.
  final FrappeChatConfig config;

  /// The Chat Room document name.
  final String room;

  /// The current user's display name, stored as the message sender.
  final String sender;

  /// The current user's email, used for room membership checks.
  final String senderEmail;

  /// Title shown in the app bar. Defaults to "Chat".
  final String? chatPartnerName;

  /// Colours and shapes.
  final FrappeChatTheme theme;

  /// Asset path of the incoming-message sound.
  ///
  /// Defaults to the sound bundled with this package. Pass null to stay silent.
  final String? notificationSoundPath;

  /// Extra app bar actions, appended after the connection indicator.
  final List<Widget> actions;

  /// Whether to show read-receipt ticks.
  ///
  /// Off by default: the stock `Chat Message` DocType has no `seen` field, so
  /// the tick could never change state.
  final bool showReadReceipts;

  /// Called when something fails. Defaults to showing a `SnackBar`.
  final void Function(String message)? onError;

  /// The sound bundled with this package.
  static const String packagedNotificationSound =
      'packages/flutter_frappe_chat/assets/sounds/message.mp3';

  const ChatScreen({
    super.key,
    required this.config,
    required this.room,
    required this.sender,
    required this.senderEmail,
    this.chatPartnerName,
    this.theme = const FrappeChatTheme(),
    this.notificationSoundPath = packagedNotificationSound,
    this.actions = const [],
    this.showReadReceipts = false,
    this.onError,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final FrappeApiService _api = FrappeApiService(widget.config);
  late final FrappeSocketManager _socket = FrappeSocketManager(widget.config);

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<ChatMessage> _messages = [];
  final Set<String> _seenKeys = {};

  /// Messages that arrived over the socket before the history finished loading.
  ///
  /// Without this buffer the history assignment would discard them.
  final List<ChatMessage> _pending = [];

  final FlutterSoundPlayer _soundPlayer = FlutterSoundPlayer();
  bool _soundReady = false;

  bool _isLoading = true;
  bool _historyLoaded = false;
  bool _isRecording = false;
  bool _isSending = false;
  String? _typingUser;

  Timer? _typingStopTimer;
  Timer? _typingThrottle;
  bool _typingSent = false;

  @override
  void initState() {
    super.initState();
    _connectSocket();
    _loadMessages();
    _initSound();
  }

  @override
  void dispose() {
    _typingThrottle?.cancel();
    _typingStopTimer?.cancel();

    if (_typingSent) {
      // Best effort: tell the room we stopped typing before leaving.
      _api.setTyping(widget.room, widget.sender, false);
    }

    _socket.dispose();
    _api.dispose();
    _textController.dispose();
    _scrollController.dispose();
    if (_soundReady) _soundPlayer.closePlayer();
    super.dispose();
  }

  // ------------------------------------------------------------------ loading

  Future<void> _loadMessages() async {
    try {
      final raw = await _api.getMessages(widget.room, widget.senderEmail);
      if (!mounted) return;

      setState(() {
        _addAll(raw.map(ChatMessage.fromJson));
        // Anything that arrived while the request was in flight.
        _addAll(_pending);
        _pending.clear();
        _historyLoaded = true;
        _isLoading = false;
      });

      unawaited(_api.markRoomAsRead(widget.room));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _reportError('$e');
    }
  }

  /// Appends messages, skipping any already present.
  ///
  /// Messages are matched on [ChatMessage.localKey] because the stock server
  /// sends no document id.
  void _addAll(Iterable<ChatMessage> incoming) {
    for (final message in incoming) {
      if (_seenKeys.add(message.localKey)) _messages.add(message);
    }
  }

  bool _isMine(ChatMessage message) => message.isFrom(
        email: widget.senderEmail,
        displayName: widget.sender,
      );

  // ------------------------------------------------------------------- socket

  void _connectSocket() {
    _socket
      ..onMessageReceived = _onMessageReceived
      ..onTypingChanged = _onTypingChanged
      ..connect(room: widget.room);
  }

  void _onMessageReceived(ChatMessage message) {
    if (!mounted) return;

    if (!_historyLoaded) {
      _pending.add(message);
      return;
    }

    final isNew = !_seenKeys.contains(message.localKey);
    if (!isNew) return;

    setState(() => _addAll([message]));

    if (!_isMine(message)) {
      _playSound();
      unawaited(_api.markRoomAsRead(widget.room));
    }
  }

  void _onTypingChanged(bool isTyping, String user) {
    if (!mounted) return;
    // Ignore the echo of our own typing status.
    if (user == widget.sender) return;

    setState(() => _typingUser = isTyping ? user : null);
  }

  // ------------------------------------------------------------------- typing

  void _onTextChanged(String text) {
    final isTyping = text.trim().isNotEmpty;

    _typingStopTimer?.cancel();

    if (!isTyping) {
      _sendTyping(false);
      return;
    }

    // Throttle: one call every two seconds while the user keeps typing, rather
    // than one per keystroke.
    if (!_typingSent || _typingThrottle == null || !_typingThrottle!.isActive) {
      _sendTyping(true);
      _typingThrottle = Timer(const Duration(seconds: 2), () {});
    }

    _typingStopTimer =
        Timer(const Duration(seconds: 3), () => _sendTyping(false));
  }

  void _sendTyping(bool isTyping) {
    if (_typingSent == isTyping) return;
    _typingSent = isTyping;
    unawaited(_api.setTyping(widget.room, widget.sender, isTyping));
  }

  // -------------------------------------------------------------------- sound

  Future<void> _initSound() async {
    if (widget.notificationSoundPath == null) return;
    try {
      await _soundPlayer.openPlayer();
      if (mounted) _soundReady = true;
    } catch (e) {
      debugPrint('flutter_frappe_chat: could not open the sound player — $e');
    }
  }

  Future<void> _playSound() async {
    final assetPath = widget.notificationSoundPath;
    if (assetPath == null || !_soundReady) return;

    try {
      // flutter_sound plays from a file, so the asset is copied to a temp file
      // once and reused.
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/${assetPath.split('/').last}');

      if (!await file.exists()) {
        final data = await rootBundle.load(assetPath);
        await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
      }

      await _soundPlayer.startPlayer(fromURI: file.path, codec: Codec.mp3);
    } catch (e) {
      debugPrint('flutter_frappe_chat: could not play the sound — $e');
    }
  }

  // ------------------------------------------------------------------ sending

  Future<void> _sendText() async {
    final content = _textController.text.trim();
    if (content.isEmpty || _isSending) return;

    _textController.clear();
    _sendTyping(false);
    await _send(content: content);
  }

  Future<void> _sendAttachment(PickedAttachment attachment) async {
    try {
      final url = await _api.uploadFileBytes(
        fileName: attachment.name,
        bytes: attachment.bytes,
      );
      await _send(content: url);
    } catch (e) {
      _reportError('$e');
    }
  }

  Future<void> _sendRecording(String path) async {
    try {
      final file = await readFileForUpload(path);
      await _sendAttachment((name: file.name, bytes: file.bytes));
    } catch (e) {
      _reportError('Could not read the recording: $e');
    }
  }

  Future<void> _send({required String content}) async {
    setState(() => _isSending = true);
    try {
      await _api.sendMessage(
        widget.room,
        content,
        widget.sender,
        widget.senderEmail,
      );
    } catch (e) {
      _reportError('$e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _reportError(String message) {
    if (widget.onError != null) {
      widget.onError!(message);
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // ---------------------------------------------------------------------- ui

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.appBarBackground,
        foregroundColor: theme.appBarForeground,
        title: Text(widget.chatPartnerName ?? 'Chat'),
        actions: [
          ValueListenableBuilder<ChatConnectionStatus>(
            valueListenable: _socket.connectionStatus,
            builder: (context, status, _) => _ConnectionDot(status: status),
          ),
          ...widget.actions,
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          if (_isRecording)
            RecordingInput(
              theme: theme,
              onStop: (path) {
                setState(() => _isRecording = false);
                _sendRecording(path);
              },
              onCancel: () => setState(() => _isRecording = false),
            )
          else
            _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_messages.isEmpty && _typingUser == null) {
      return Center(
        child: Text(
          'No messages yet',
          style: TextStyle(color: widget.theme.metaColor),
        ),
      );
    }

    final showTyping = _typingUser != null;

    return ListView.builder(
      reverse: true,
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _messages.length + (showTyping ? 1 : 0),
      itemBuilder: (context, index) {
        if (showTyping && index == 0) {
          return Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: AnimatedTypingIndicator(
                username: _typingUser!,
                theme: widget.theme,
              ),
            ),
          );
        }

        final messageIndex = showTyping ? index - 1 : index;
        // The list is reversed, so index 0 is the newest message.
        final message = _messages[_messages.length - 1 - messageIndex];

        return MessageBubble(
          key: ValueKey(message.localKey),
          message: message,
          isMe: _isMine(message),
          config: widget.config,
          theme: widget.theme,
          showReadReceipt: widget.showReadReceipts,
        );
      },
    );
  }

  Widget _buildInputBar() {
    final theme = widget.theme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: theme.inputBackground,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  onChanged: _onTextChanged,
                  onSubmitted: (_) => _sendText(),
                  minLines: 1,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(color: theme.incomingText),
                  decoration: InputDecoration(
                    hintText: 'Message',
                    hintStyle: TextStyle(color: theme.metaColor),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 8,
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Attach',
                icon: Icon(Icons.attach_file, color: theme.metaColor),
                onPressed: _openAttachmentSheet,
              ),
              // Only this button rebuilds as the user types. Rebuilding the
              // whole screen per keystroke also rebuilt the message list.
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _textController,
                builder: (context, value, _) {
                  final hasText = value.text.trim().isNotEmpty;
                  return IconButton(
                    tooltip: hasText ? 'Send' : 'Record a voice note',
                    icon: Icon(
                      hasText ? Icons.send : Icons.mic,
                      color: theme.accent,
                    ),
                    onPressed: _isSending
                        ? null
                        : hasText
                            ? _sendText
                            : () => setState(() => _isRecording = true),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openAttachmentSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => AttachmentSheet(
        onFileSelected: _sendAttachment,
        onError: _reportError,
      ),
    );
  }
}

class _ConnectionDot extends StatelessWidget {
  final ChatConnectionStatus status;

  const _ConnectionDot({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status.state) {
      ChatConnectionState.connected => (Colors.green, 'Connected'),
      ChatConnectionState.connecting => (Colors.amber, 'Connecting'),
      ChatConnectionState.disconnected => (Colors.grey, 'Offline'),
      ChatConnectionState.failed => (
          Colors.red,
          'Connection failed: ${status.message ?? 'unknown error'}',
        ),
    };

    return Tooltip(
      message: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Semantics(
          label: label,
          child: Icon(Icons.circle, color: color, size: 10),
        ),
      ),
    );
  }
}
