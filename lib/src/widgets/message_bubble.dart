import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/chat_config.dart';
import '../models/chat_message.dart';
import '../models/chat_theme.dart';
import 'chat_audio_player.dart';

/// The kind of content a message carries.
enum ChatAttachmentKind { text, image, audio, pdf, file }

/// A single message bubble.
class MessageBubble extends StatelessWidget {
  /// The message to render.
  final ChatMessage message;

  /// Whether the current user sent it.
  final bool isMe;

  /// Connection settings, used to resolve attachment URLs and to authenticate
  /// requests for private files.
  final FrappeChatConfig config;

  /// Colours and shapes.
  final FrappeChatTheme theme;

  /// Whether to show the read-receipt tick.
  ///
  /// Off by default: the stock `Chat Message` DocType has no `seen` field, so
  /// the tick would never change state. Turn it on only if your site adds one.
  final bool showReadReceipt;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.config,
    this.theme = const FrappeChatTheme(),
    this.showReadReceipt = false,
  });

  /// What this message carries.
  ChatAttachmentKind get kind {
    final content = message.content.trim();
    final isAttachment = content.contains('/files/') &&
        (content.startsWith('/') || content.startsWith('http'));
    if (!isAttachment) return ChatAttachmentKind.text;

    final path = Uri.tryParse(content)?.path.toLowerCase() ??
        content.toLowerCase();

    bool endsWithAny(List<String> extensions) =>
        extensions.any(path.endsWith);

    if (endsWithAny(['.png', '.jpg', '.jpeg', '.gif', '.webp', '.bmp'])) {
      return ChatAttachmentKind.image;
    }
    if (endsWithAny(['.aac', '.mp3', '.m4a', '.wav', '.ogg', '.opus'])) {
      return ChatAttachmentKind.audio;
    }
    if (path.endsWith('.pdf')) return ChatAttachmentKind.pdf;
    return ChatAttachmentKind.file;
  }

  /// The absolute URL of the attachment.
  String get fileUrl {
    final content = message.content.trim();
    if (content.startsWith('http')) return content;
    return '${config.baseUrl}${content.startsWith('/') ? '' : '/'}$content';
  }

  /// The attachment's file name, for display.
  String get fileName {
    final path = Uri.tryParse(fileUrl)?.pathSegments.lastOrNull;
    return (path == null || path.isEmpty) ? 'Attachment' : path;
  }

  /// The timestamp, formatted for the reader's locale.
  String get formattedTime {
    final createdAt = message.createdAt;
    if (createdAt == null) return '';

    final local = createdAt.toLocal();
    final now = DateTime.now();
    final isToday = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;

    return isToday
        ? DateFormat.jm().format(local)
        : DateFormat.yMd().add_jm().format(local);
  }

  @override
  Widget build(BuildContext context) {
    final radius = Radius.circular(theme.bubbleRadius);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isMe ? theme.outgoingBubble : theme.incomingBubble,
          borderRadius: BorderRadius.only(
            topLeft: isMe ? radius : Radius.zero,
            topRight: isMe ? Radius.zero : radius,
            bottomLeft: radius,
            bottomRight: radius,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  message.sender,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: theme.senderNameColor,
                  ),
                ),
              ),
            _buildContent(context),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  formattedTime,
                  style: TextStyle(fontSize: 10, color: theme.metaColor),
                ),
                if (isMe && showReadReceipt) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.seen ? Icons.done_all : Icons.done,
                    size: 14,
                    color: message.seen ? theme.accent : theme.metaColor,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final textColor = isMe ? theme.outgoingText : theme.incomingText;

    switch (kind) {
      case ChatAttachmentKind.text:
        return SelectableText(
          message.content,
          style: (theme.messageTextStyle ?? const TextStyle())
              .copyWith(color: textColor),
        );

      case ChatAttachmentKind.image:
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: GestureDetector(
            onTap: () => _open(context),
            child: CachedNetworkImage(
              imageUrl: fileUrl,
              httpHeaders: config.authHeaders,
              fit: BoxFit.cover,
              placeholder: (context, url) => const SizedBox(
                height: 140,
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              errorWidget: (context, url, error) =>
                  _fileRow(context, Icons.broken_image_outlined,
                      'Image unavailable', textColor),
            ),
          ),
        );

      case ChatAttachmentKind.audio:
        return ChatAudioPlayer(
          audioUrl: fileUrl,
          isMe: isMe,
          theme: theme,
          headers: config.authHeaders,
        );

      case ChatAttachmentKind.pdf:
        return _fileRow(context, Icons.picture_as_pdf_outlined, fileName,
            textColor);

      case ChatAttachmentKind.file:
        return _fileRow(context, Icons.attach_file, fileName, textColor);
    }
  }

  Widget _fileRow(
    BuildContext context,
    IconData icon,
    String label,
    Color textColor,
  ) {
    return InkWell(
      onTap: () => _open(context),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: theme.accent),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final url = Uri.tryParse(fileUrl);

    if (url == null ||
        !await launchUrl(url, mode: LaunchMode.externalApplication)) {
      messenger?.showSnackBar(
        SnackBar(content: Text('Could not open $fileName')),
      );
    }
  }
}
