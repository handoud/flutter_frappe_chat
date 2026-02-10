import 'package:flutter/material.dart';

import 'dart:ui';
import 'dart:io';
import '../models/chat_config.dart';
import '../models/chat_message.dart';
import '../api/frappe_api.dart';
import '../socket/socket_manager.dart';
import '../widgets/message_bubble.dart';
import '../widgets/attachment_sheet.dart';
import '../widgets/recording_input.dart';
import 'package:flutter_sound/flutter_sound.dart';
import '../widgets/typing_indicator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

/// A full-featured chat screen widget for Frappe Chat.
///
/// This widget provides a complete chat interface with:
/// - Real-time message updates via WebSocket
/// - Message history loading
/// - Text message sending
/// - File attachment support
/// - Audio message recording
/// - Typing indicators
/// - Connection status indicator
///
/// Example usage:
/// ```dart
/// Navigator.push(
///   context,
///   MaterialPageRoute(
///     builder: (context) => ChatScreen(
///       config: frappeChatConfig,
///       room: 'room-id-123',
///       sender: 'john_doe',
///       senderEmail: 'john@example.com',
///       chatPartnerName: 'Jane Doe',
///     ),
///   ),
/// );
/// ```
class ChatScreen extends StatefulWidget {
  /// The configuration for connecting to the Frappe server.
  final FrappeChatConfig config;

  /// The unique identifier of the chat room.
  final String room;

  /// The username of the current user sending messages.
  final String sender;

  /// The email address of the current user.
  final String senderEmail;

  /// The display name of the chat partner (optional).
  ///
  /// If provided, this will be shown in the app bar. Otherwise, "Chat" is displayed.
  final String? chatPartnerName;

  /// The path to the notification sound asset (optional).
  final String? notificationSoundPath;

  /// Creates a new [ChatScreen] widget.
  ///
  /// All parameters except [chatPartnerName] are required.
  const ChatScreen({
    Key? key,
    required this.config,
    required this.room,
    required this.sender,
    required this.senderEmail,
    this.chatPartnerName,
    this.notificationSoundPath,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late FrappeApiService _apiService;
  late FrappeSocketManager _socketManager;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isConnected = false;
  bool _isTyping = false;
  bool _isRecording = false;
  final FlutterSoundPlayer _soundPlayer = FlutterSoundPlayer();
  // String? _partnerTyping; // Removed in favor of _typingUser

  @override
  void initState() {
    super.initState();
    _apiService = FrappeApiService(widget.config);
    _socketManager = FrappeSocketManager(widget.config);

    _loadMessages();
    _connectSocket();
    _initSoundPlayer();
  }

  void _initSoundPlayer() async {
    await _soundPlayer.openPlayer();
  }

  void _loadMessages() async {
    try {
      debugPrint(
        "DEBUG: _loadMessages started for room: ${widget.room}, email: ${widget.senderEmail}",
      );
      final messagesData = await _apiService.getMessages(
        widget.room,
        widget.senderEmail,
      );
      debugPrint("DEBUG: getMessages returned ${messagesData.length} messages");

      setState(() {
        _messages = messagesData.map((m) {
          try {
            return ChatMessage.fromJson(m);
          } catch (e) {
            debugPrint("Error parsing message: $e");
            return ChatMessage(
              content: 'Error parsing message',
              sender: 'System',
              room: widget.room,
              creation: '',
              name: '',
            );
          }
        }).toList();
        _isLoading = false;
      });

      // Mark unseen messages as read
      for (var msg in _messages) {
        bool isMe = msg.senderEmail == widget.senderEmail ||
            msg.sender == widget.sender;
        if (!msg.seen && !isMe && msg.name.isNotEmpty) {
          _apiService.markMessageAsRead(msg.name);
        }
      }

      // No need to scroll manually with reverse: true
    } catch (e, stack) {
      debugPrint("Error loading messages: $e");
      debugPrint("Stack trace: $stack");
      setState(() => _isLoading = false);
    }
  }

  String? _typingUser;

  // ... (existing helper methods)

  void _connectSocket() {
    _socketManager.onMessageReceived = (message) {
      setState(() {
        _messages.add(message);
      });
      // Play sound if message is not from me
      bool isMe = message.senderEmail == widget.senderEmail ||
          message.sender == widget.sender;
      if (!isMe) {
        _playSound();
        if (message.name.isNotEmpty) {
          _apiService.markMessageAsRead(message.name);
        }
      }
      // No need to scroll manually with reverse: true as new messages appear at bottom (index 0)
    };

    // Modified to receive user info if possible, or just toggle
    // We need to update SocketManager to pass the user who is typing
    _socketManager.onTypingChanged = (isTyping, user) {
      setState(() {
        if (isTyping) {
          // Use the user from the socket event
          _typingUser = user;
        } else {
          _typingUser = null;
        }
      });
      // Scroll to show typing indicator
      if (isTyping) {
        // With reverse: true, typing indicator appears at index 0 (bottom).
        // ListView should handle this naturally or we might want to jump to 0.
        if (_scrollController.hasClients && _scrollController.offset > 0) {
          // Optional: jump to bottom if near bottom
        }
      }
    };

    // Listen for message updates (seen status)
    _socketManager.onMessageUpdated = (message) {
      if (!mounted) return;
      setState(() {
        int index = _messages.indexWhere((m) => m.name == message.name);
        if (index != -1) {
          _messages[index] = message;
        }
      });
    };

    _socketManager.connect(room: widget.room);
    setState(() => _isConnected = true);
  }

  Future<void> _playSound() async {
    // If no path is provided, do nothing or fallback
    if (widget.notificationSoundPath == null) return;

    try {
      // 1. Get Temporary Directory
      final tempDir = await getTemporaryDirectory();
      // Extract filename from path (e.g. message.mp3)
      final fileName = widget.notificationSoundPath!.split('/').last;
      final file = File('${tempDir.path}/$fileName');

      // 2. Load Asset logic (Write to file only if not exists)
      if (!await file.exists()) {
        try {
          // Verify asset exists in root bundle
          final byteData = await rootBundle.load(widget.notificationSoundPath!);
          await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
          debugPrint("Sound file written to ${file.path}");
        } catch (e) {
          debugPrint("Error loading/writing asset: $e");
          return;
        }
      }

      // 3. Play from local file
      await _soundPlayer.startPlayer(
        fromURI: file.path,
        codec: Codec.mp3,
        whenFinished: () {
          debugPrint("Sound finished playing");
        },
      );
      debugPrint("Sound started playing");
    } catch (e) {
      debugPrint("Error playing sound: $e");
    }
  }

  Future<void> _sendMessage({String? content, File? file}) async {
    if ((content == null || content.trim().isEmpty) && file == null) return;

    try {
      String messageContent = content ?? "";

      if (file != null) {
        // Upload file first
        String fileUrl = await _apiService.uploadFile(file);
        messageContent = fileUrl;
      }

      await _apiService.sendMessage(
        widget.room,
        messageContent,
        widget.sender,
        widget.senderEmail,
      );

      _textController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error sending message: $e")),
        );
      }
    }
  }

  @override
  void dispose() {
    _socketManager.disconnect();
    _textController.dispose();
    _soundPlayer.closePlayer();
    super.dispose();
  }

  void _onTyping(String text) {
    bool isTyping = text.isNotEmpty;
    if (_isTyping != isTyping) {
      _isTyping = isTyping;
      _socketManager.sendTyping(widget.room, widget.sender, isTyping);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor:
            Colors.white.withValues(alpha: 0.8), // Transparent/Blurry
        elevation: 0,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.chatPartnerName ?? "Chat",
          style: const TextStyle(color: Colors.black),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call, color: Colors.black),
            onPressed: () {}, // Todo: Implement call
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(
              Icons.circle,
              color: _isConnected ? Colors.green : Colors.red,
              size: 12,
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFECE5DD), // WhatsApp default background color
        ),
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      reverse: true, // WhatsApp style: bottom is 0
                      controller: _scrollController,
                      // +1 for typing indicator which will be at index 0
                      itemCount:
                          _messages.length + (_typingUser != null ? 1 : 0),
                      itemBuilder: (context, index) {
                        // If typing, it takes up index 0 (bottom-most)
                        if (_typingUser != null) {
                          if (index == 0) {
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: AnimatedTypingIndicator(
                                    username: _typingUser!),
                              ),
                            );
                          }
                          // Adjust index for messages if typing is present
                          index = index - 1;
                        }

                        // Reverse index access to show Newest at Bottom (Index 0/1 depending on typing)
                        // _messages is [Oldest, ..., Newest]
                        // reversed index: length - 1 - index
                        final reversedIndex = _messages.length - 1 - index;
                        final message = _messages[reversedIndex];

                        bool isMe = message.senderEmail == widget.senderEmail ||
                            message.sender == widget.sender;
                        return MessageBubble(
                          message: message,
                          isMe: isMe,
                          baseUrl: widget.config.baseUrl,
                        );
                      },
                    ),
            ),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    if (_isRecording) {
      return RecordingInput(
        onStop: (path) {
          setState(() {
            _isRecording = false;
          });
          _sendMessage(file: File(path));
        },
        onCancel: () {
          setState(() {
            _isRecording = false;
          });
        },
      );
    }

    return Container(
      padding: const EdgeInsets.only(left: 8, right: 8, top: 8, bottom: 20),
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 1),
            )
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                onChanged: (text) {
                  _onTyping(text);
                  setState(() {});
                },
                minLines: 1,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: "Message",
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.attach_file, color: Colors.grey),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  builder: (context) => AttachmentSheet(
                    onFileSelected: (file) => _sendMessage(file: file),
                  ),
                );
              },
            ),
            const SizedBox(width: 4),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: _textController.text.trim().isNotEmpty
                  ? GestureDetector(
                      key: const ValueKey('send'),
                      onTap: () {
                        _sendMessage(content: _textController.text);
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(Icons.send,
                            color: Color(0xFF075E54), size: 28),
                      ),
                    )
                  : GestureDetector(
                      key: const ValueKey('mic'),
                      onTap: () {
                        setState(() {
                          _isRecording = true;
                        });
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(
                          Icons.mic,
                          color: Color(0xFF075E54),
                          size: 28,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
