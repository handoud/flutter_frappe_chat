import 'package:flutter_frappe_chat/flutter_frappe_chat.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessage message({
  String name = '',
  String content = 'hello',
  String sender = 'Jane Doe',
  String? senderEmail = 'jane@example.com',
  String creation = '2026-08-27 10:30:00.000000',
}) {
  return ChatMessage(
    name: name,
    content: content,
    sender: sender,
    room: 'room-1',
    senderEmail: senderEmail,
    creation: creation,
  );
}

void main() {
  group('parsing', () {
    test('reads the fields chat.api.message.get_all actually returns', () {
      // The stock endpoint selects only content, sender, creation and
      // sender_email — no `name`.
      final parsed = ChatMessage.fromJson({
        'content': 'hi',
        'sender': 'Jane Doe',
        'sender_email': 'jane@example.com',
        'creation': '2026-08-27 10:30:00.000000',
      });

      expect(parsed.content, 'hi');
      expect(parsed.sender, 'Jane Doe');
      expect(parsed.senderEmail, 'jane@example.com');
      expect(parsed.name, isEmpty);
    });

    test('accepts the realtime payload, which uses "user" for the sender', () {
      final parsed = ChatMessage.fromJson({
        'content': 'hi',
        'user': 'Jane Doe',
        'email': 'jane@example.com',
        'room': 'room-1',
      });

      expect(parsed.sender, 'Jane Doe');
      expect(parsed.senderEmail, 'jane@example.com');
    });

    test('survives a malformed payload', () {
      final parsed = ChatMessage.fromJson('not a map');
      expect(parsed.sender, 'System');
      expect(parsed.content, isEmpty);
    });
  });

  group('localKey', () {
    test('falls back to time, sender and content when there is no id', () {
      final a = message();
      final b = message();

      // Without this, deduplication would match every message against the
      // first one, because every `name` is empty.
      expect(a.localKey, b.localKey);
      expect(a, equals(b));
      expect({a, b}, hasLength(1));
    });

    test('different messages get different keys', () {
      expect(
        message(content: 'one').localKey,
        isNot(message(content: 'two').localKey),
      );
      expect(
        message(creation: '2026-08-27 10:30:00').localKey,
        isNot(message(creation: '2026-08-27 10:31:00').localKey),
      );
    });

    test('prefers the document name when the server sends one', () {
      expect(message(name: 'CHAT-0001').localKey, 'CHAT-0001');
    });
  });

  group('createdAt', () {
    test('parses a Frappe timestamp', () {
      expect(message().createdAt, DateTime(2026, 8, 27, 10, 30));
    });

    test('returns null for an empty or invalid timestamp', () {
      expect(message(creation: '').createdAt, isNull);
      expect(message(creation: 'nonsense').createdAt, isNull);
    });
  });

  group('isFrom', () {
    test('matches on email first', () {
      expect(message().isFrom(email: 'jane@example.com'), isTrue);
      expect(message().isFrom(email: 'someone@else.com'), isFalse);
    });

    test('falls back to the display name for guests', () {
      final guest = message(senderEmail: null, sender: 'Guest 42');
      expect(guest.isFrom(email: 'jane@example.com'), isFalse);
      expect(guest.isFrom(displayName: 'Guest 42'), isTrue);
    });
  });

  test('round-trips through JSON', () {
    final original = message(name: 'CHAT-0001');
    final restored = ChatMessage.fromJson(original.toJson());

    expect(restored.localKey, original.localKey);
    expect(restored.content, original.content);
  });
}
