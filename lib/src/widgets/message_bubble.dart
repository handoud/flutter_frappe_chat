import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/chat_message.dart';
import 'chat_audio_player.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final String baseUrl;

  const MessageBubble({
    Key? key,
    required this.message,
    required this.isMe,
    required this.baseUrl,
  }) : super(key: key);

  bool get isFile => message.content.contains('/files/');

  String get fileUrl {
    if (message.content.startsWith('http')) return message.content;
    String cleanBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    String cleanContent = message.content.startsWith('/')
        ? message.content
        : '/${message.content}';
    return "$cleanBase$cleanContent";
  }

  bool get isImage {
    final lower = message.content.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.gif');
  }

  bool get isAudio {
    final lower = message.content.toLowerCase();
    return lower.endsWith('.aac') ||
        lower.endsWith('.mp3') ||
        lower.endsWith('.m4a') ||
        lower.endsWith('.wav') ||
        lower.endsWith('.ogg');
  }

  bool get isPdf {
    return message.content.toLowerCase().endsWith('.pdf');
  }

  @override
  Widget build(BuildContext context) {
    // WhatsApp Colors
    final Color myColor = const Color(0xFFDCF8C6);
    final Color otherColor = Colors.white;
    const Radius radius = Radius.circular(12);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isMe ? myColor : otherColor,
          borderRadius: BorderRadius.only(
            topLeft: isMe ? radius : Radius.zero,
            topRight: isMe ? Radius.zero : radius,
            bottomLeft: radius,
            bottomRight: radius,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 2,
              offset: const Offset(0, 1),
            )
          ],
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Text(
                  message.sender,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.orange[800],
                  ),
                ),
              ),
            if (isFile) _buildFileContent(context) else _buildTextContent(),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  message.creation, // Todo: Format date properly
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.seen ? Icons.done_all : Icons.done,
                    size: 14,
                    color: message.seen ? Colors.blue : Colors.grey[600],
                  ),
                ]
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextContent() {
    return Text(message.content);
  }

  Widget _buildFileContent(BuildContext context) {
    if (isImage) {
      return GestureDetector(
        onTap: () => _launchUrl(fileUrl),
        child: CachedNetworkImage(
          imageUrl: fileUrl,
          placeholder: (context, url) => const CircularProgressIndicator(),
          errorWidget: (context, url, error) => const Icon(Icons.error),
        ),
      );
    } else if (isAudio) {
      return ChatAudioPlayer(audioUrl: fileUrl, isMe: isMe);
    } else if (isPdf) {
      return GestureDetector(
        onTap: () => _launchUrl(fileUrl),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.picture_as_pdf, color: Colors.red),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                "PDF Document",
                style: TextStyle(decoration: TextDecoration.underline),
              ),
            ),
          ],
        ),
      );
    } else {
      return GestureDetector(
        onTap: () => _launchUrl(fileUrl),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.attach_file),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                "Attachment",
                style: TextStyle(decoration: TextDecoration.underline),
              ),
            ),
          ],
        ),
      );
    }
  }

  void _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }
}
