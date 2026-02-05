class ChatMessage {
  final String content;
  final String sender;
  final String room;
  final String? senderEmail;
  final String creation;

  ChatMessage({
    required this.content,
    required this.sender,
    required this.room,
    this.senderEmail,
    required this.creation,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      content: json['content'] as String,
      sender: json['sender'] as String,
      room: json['room'] as String,
      senderEmail: json['sender_email'] as String?,
      creation: json['creation'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'sender': sender,
      'room': room,
      'sender_email': senderEmail,
      'creation': creation,
    };
  }
}
