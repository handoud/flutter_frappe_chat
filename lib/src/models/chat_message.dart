/// Represents a single chat message in the Frappe Chat system.
///
/// A [ChatMessage] contains all the information about a message sent in a chat room,
/// including the message content, sender information, and timestamp.
class ChatMessage {
  /// The text content of the message.
  ///
  /// This can also contain file URLs if the message is a file attachment.
  final String content;

  /// The username of the person who sent the message.
  final String sender;

  /// The unique identifier of the chat room where this message was sent.
  final String room;

  /// The email address of the message sender.
  ///
  /// This is optional and may be null for guest users.
  final String? senderEmail;

  /// The timestamp when the message was created in ISO 8601 format.
  final String creation;

  /// The unique identifier of the message (DocName).
  final String name;

  /// Whether the message has been seen by the recipient.
  final bool seen;

  /// Creates a new [ChatMessage] instance.
  ///
  /// All fields except [senderEmail] are required.
  ChatMessage({
    required this.name,
    required this.content,
    required this.sender,
    required this.room,
    this.senderEmail,
    required this.creation,
    this.seen = false,
  });

  /// Creates a [ChatMessage] from a JSON map.
  ///
  /// This is typically used when deserializing messages received from the Frappe API.
  /// The JSON map should contain keys: 'content', 'sender', 'room', 'sender_email', and 'creation'.
  factory ChatMessage.fromJson(dynamic json) {
    if (json is! Map) {
      return ChatMessage(
        name: '',
        content: 'Error: Invalid message format',
        sender: 'System',
        room: '',
        creation: '',
        seen: false,
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
      // Check for common 'seen' or 'read' flags
      seen: json['seen'] == true ||
          json['seen'] == 1 ||
          json['read'] == true ||
          json['read'] == 1,
    );
  }

  /// Converts this [ChatMessage] to a JSON map.
  ///
  /// This is useful for serializing messages before sending them to the Frappe API.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'content': content,
      'sender': sender,
      'room': room,
      'sender_email': senderEmail,
      'creation': creation,
      'seen': seen,
    };
  }
}
