import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/chat_message.dart';

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
    // Ensure we don't double slash if baseUrl ends with /
    String cleanBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    // Ensure content starts with / if it doesn't
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

  bool get isPdf {
    return message.content.toLowerCase().endsWith('.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isMe ? Colors.blue[100] : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Text(
                message.sender,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            if (isFile) _buildFileContent(context) else _buildTextContent(),
            const SizedBox(height: 4),
            Text(
              message.creation, // Todo: Format date
              style: const TextStyle(fontSize: 10, color: Colors.grey),
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
      // Handle error
      debugPrint('Could not launch $url');
    }
  }
}
