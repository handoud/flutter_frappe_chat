import 'package:flutter/material.dart';
import 'package:flutter_frappe_chat/flutter_frappe_chat.dart';
import 'package:flutter_test/flutter_test.dart';

final config = FrappeChatConfig(baseUrl: 'https://erp.example.com');

MessageBubble bubbleFor(String content) {
  return MessageBubble(
    message: ChatMessage(
      name: '',
      content: content,
      sender: 'Jane Doe',
      room: 'room-1',
      senderEmail: 'jane@example.com',
      creation: '2026-08-27 10:30:00.000000',
    ),
    isMe: false,
    config: config,
  );
}

void main() {
  group('attachment detection', () {
    test('plain text is text, even when it mentions a path', () {
      expect(bubbleFor('hello there').kind, ChatAttachmentKind.text);
      expect(
        bubbleFor('look in /files/ for the report').kind,
        ChatAttachmentKind.text,
        reason: 'a substring match alone must not turn prose into an attachment',
      );
    });

    test('recognises images', () {
      for (final path in [
        '/files/photo.png',
        '/files/photo.JPG',
        '/private/files/scan.jpeg',
        'https://cdn.example.com/files/animation.gif',
      ]) {
        expect(bubbleFor(path).kind, ChatAttachmentKind.image, reason: path);
      }
    });

    test('recognises audio', () {
      for (final path in ['/files/note.aac', '/files/note.m4a', '/files/x.ogg']) {
        expect(bubbleFor(path).kind, ChatAttachmentKind.audio, reason: path);
      }
    });

    test('recognises PDFs and falls back to a generic file', () {
      expect(bubbleFor('/files/contract.pdf').kind, ChatAttachmentKind.pdf);
      expect(bubbleFor('/files/data.zip').kind, ChatAttachmentKind.file);
    });

    test('ignores a query string when detecting the type', () {
      expect(
        bubbleFor('/files/photo.png?v=2').kind,
        ChatAttachmentKind.image,
      );
    });
  });

  group('urls', () {
    test('resolves a relative file path against the base url', () {
      expect(
        bubbleFor('/files/photo.png').fileUrl,
        'https://erp.example.com/files/photo.png',
      );
    });

    test('leaves an absolute url alone', () {
      expect(
        bubbleFor('https://cdn.example.com/files/photo.png').fileUrl,
        'https://cdn.example.com/files/photo.png',
      );
    });

    test('exposes the file name for display', () {
      expect(bubbleFor('/files/quarterly report.pdf').fileName,
          'quarterly report.pdf');
    });
  });

  group('rendering', () {
    testWidgets('shows the message text and sender', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: bubbleFor('Hello world'))),
      );

      expect(find.text('Hello world'), findsOneWidget);
      expect(find.text('Jane Doe'), findsOneWidget);
    });

    testWidgets('hides read receipts by default', (tester) async {
      // The stock Chat Message DocType has no `seen` field, so a tick would
      // never change state.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              message: ChatMessage(
                name: '',
                content: 'mine',
                sender: 'Jane Doe',
                room: 'room-1',
                senderEmail: 'jane@example.com',
                creation: '2026-08-27 10:30:00.000000',
              ),
              isMe: true,
              config: config,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.done), findsNothing);
      expect(find.byIcon(Icons.done_all), findsNothing);
    });
  });

  group('FrappeChatTheme', () {
    test('derives a dark palette from the app theme', () {
      final dark = FrappeChatTheme.fromTheme(
        ThemeData(brightness: Brightness.dark, useMaterial3: true),
      );
      final light = FrappeChatTheme.fromTheme(
        ThemeData(brightness: Brightness.light, useMaterial3: true),
      );

      expect(dark.background, isNot(light.background));
      expect(dark.incomingText, isNot(light.incomingText));
    });

    test('copyWith overrides one value and keeps the rest', () {
      const base = FrappeChatTheme();
      final tweaked = base.copyWith(accent: const Color(0xFF123456));

      expect(tweaked.accent, const Color(0xFF123456));
      expect(tweaked.background, base.background);
    });
  });
}
