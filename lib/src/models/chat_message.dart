/// A single message in a Frappe Chat room.
class ChatMessage {
  /// The message text, or the URL of an attachment.
  final String content;

  /// Display name of the sender.
  final String sender;

  /// The room this message belongs to.
  final String room;

  /// Email of the sender. Null for guests.
  final String? senderEmail;

  /// Creation timestamp, as returned by the server.
  final String creation;

  /// The Frappe document name (id).
  ///
  /// **Usually empty.** The stock `chat.api.message.get_all` selects only
  /// `content`, `sender`, `creation` and `sender_email`, and the realtime
  /// payload carries no id either. Use [localKey] to identify a message.
  final String name;

  /// Whether the message has been read.
  ///
  /// **The stock `Chat Message` DocType has no `seen` field**, so this is false
  /// unless your site adds one. Read receipts in the bundled UI are off by
  /// default for this reason.
  final bool seen;

  ChatMessage({
    required this.name,
    required this.content,
    required this.sender,
    required this.room,
    this.senderEmail,
    required this.creation,
    this.seen = false,
  });

  /// A stable identity for this message.
  ///
  /// Falls back to creation time plus sender when the server did not send a
  /// document name, which is the normal case. Used to merge socket messages
  /// with loaded history without duplicating them.
  String get localKey =>
      name.isNotEmpty ? name : '$creation|${senderEmail ?? sender}|$content';

  /// [creation] parsed as a [DateTime], or null when it is missing or invalid.
  DateTime? get createdAt => DateTime.tryParse(creation);

  /// Whether this message was sent by [email] or [displayName].
  bool isFrom({String? email, String? displayName}) {
    if (email != null && senderEmail != null && senderEmail == email) {
      return true;
    }
    return displayName != null && sender == displayName;
  }

  factory ChatMessage.fromJson(dynamic json) {
    if (json is! Map) {
      return ChatMessage(
        name: '',
        content: '',
        sender: 'System',
        room: '',
        creation: '',
      );
    }

    return ChatMessage(
      name: json['name']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      sender:
          json['sender']?.toString() ?? json['user']?.toString() ?? 'Unknown',
      room: json['room']?.toString() ?? '',
      senderEmail:
          json['sender_email']?.toString() ?? json['email']?.toString(),
      creation: json['creation']?.toString() ?? '',
      seen: json['seen'] == true ||
          json['seen'] == 1 ||
          json['read'] == true ||
          json['read'] == 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'content': content,
        'sender': sender,
        'room': room,
        'sender_email': senderEmail,
        'creation': creation,
        'seen': seen,
      };

  ChatMessage copyWith({bool? seen}) => ChatMessage(
        name: name,
        content: content,
        sender: sender,
        room: room,
        senderEmail: senderEmail,
        creation: creation,
        seen: seen ?? this.seen,
      );

  @override
  bool operator ==(Object other) =>
      other is ChatMessage && other.localKey == localKey;

  @override
  int get hashCode => localKey.hashCode;

  @override
  String toString() => 'ChatMessage($sender: $content)';
}
