import 'package:flutter/material.dart';

import 'dart:io';
import '../models/chat_config.dart';
import '../models/chat_message.dart';
import '../api/frappe_api.dart';
import '../socket/socket_manager.dart';
import '../widgets/message_bubble.dart';
import '../widgets/attachment_sheet.dart';
import '../widgets/audio_recorder.dart';

class ChatScreen extends StatefulWidget {
  final FrappeChatConfig config;
  final String room;
  final String sender;
  final String senderEmail;
  final String? chatPartnerName;

  const ChatScreen({
    Key? key,
    required this.config,
    required this.room,
    required this.sender,
    required this.senderEmail,
    this.chatPartnerName,
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
  String? _partnerTyping;

  @override
  void initState() {
    super.initState();
    _apiService = FrappeApiService(widget.config);
    _socketManager = FrappeSocketManager(widget.config);

    _loadMessages();
    _connectSocket();
  }

  void _loadMessages() async {
    try {
      final messagesData = await _apiService.getMessages(
        widget.room,
        widget.senderEmail,
      );
      setState(() {
        _messages = messagesData.map((m) => ChatMessage.fromJson(m)).toList();
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint("Error loading messages: $e");
      setState(() => _isLoading = false);
    }
  }

  void _connectSocket() {
    _socketManager.onMessageReceived = (message) {
      setState(() {
        _messages.add(message);
      });
      _scrollToBottom();
    };

    _socketManager.onTypingChanged = (isTyping) {
      // Simple logic: if anyone else is typing, show it
      setState(() {
        _partnerTyping = isTyping ? "Typing..." : null;
      });
    };

    _socketManager.connect(widget.room);
    setState(() => _isConnected = true);
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage({String? content, File? file}) async {
    if ((content == null || content.trim().isEmpty) && file == null) return;

    try {
      String messageContent = content ?? "";

      if (file != null) {
        // Upload file first
        String fileUrl = await _apiService.uploadFile(file);
        messageContent =
            fileUrl; // Or construct a specific message format if needed
      }

      await _apiService.sendMessage(
        widget.room,
        messageContent,
        widget.sender,
        widget.senderEmail,
      );

      _textController.clear();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error sending message: $e")));
    }
  }

  @override
  void dispose() {
    _socketManager.disconnect();
    _textController.dispose();
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
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.chatPartnerName ?? "Chat"),
            if (_partnerTyping != null)
              Text(
                _partnerTyping!,
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
        actions: [
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
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      // Frappe uses email or username for sender identification.
                      // We need to check both or standardize.
                      bool isMe =
                          message.senderEmail == widget.senderEmail ||
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
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (context) => AttachmentSheet(
                  onFileSelected: (file) => _sendMessage(file: file),
                ),
              );
            },
          ),
          Expanded(
            child: TextField(
              controller: _textController,
              onChanged: _onTyping,
              decoration: const InputDecoration(
                hintText: "Type a message...",
                border: InputBorder.none,
              ),
            ),
          ),
          // Toggle between Send and Mic based on text content
          if (_textController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: () => _sendMessage(content: _textController.text),
            )
          else
            AudioRecorder(onStop: (path) => _sendMessage(file: File(path))),
        ],
      ),
    );
  }
}
