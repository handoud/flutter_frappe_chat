import 'package:flutter_frappe_chat/flutter_frappe_chat.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('socket URL', () {
    test('appends the site namespace Frappe requires', () {
      final config = FrappeChatConfig(baseUrl: 'https://erp.example.com');

      // Frappe registers realtime handlers on io.of(/^\/.*$/) and its auth
      // middleware refuses any namespace that is not the site name. Connecting
      // to the bare host fails with "Invalid namespace".
      expect(config.socketUrl, 'https://erp.example.com/erp.example.com');
      expect(config.resolvedSiteName, 'erp.example.com');
    });

    test('honours an explicit site name for multi-tenant benches', () {
      final config = FrappeChatConfig(
        baseUrl: 'http://localhost:8000',
        siteName: 'mysite.localhost',
      );

      expect(config.socketUrl, 'http://localhost:8000/mysite.localhost');
    });

    test('socketUrlOverride wins outright', () {
      final config = FrappeChatConfig(
        baseUrl: 'https://erp.example.com',
        siteName: 'ignored',
        socketUrlOverride: 'https://realtime.example.com:9000/site',
      );

      expect(config.socketUrl, 'https://realtime.example.com:9000/site');
    });

    test('strips trailing slashes from the base url', () {
      final config = FrappeChatConfig(baseUrl: 'https://erp.example.com//');
      expect(config.baseUrl, 'https://erp.example.com');
      expect(config.socketUrl, 'https://erp.example.com/erp.example.com');
    });
  });

  group('origin', () {
    test('exposes scheme and host for the Origin header', () {
      // Frappe compares Origin against Host and refuses a mismatch; a native
      // Dart client sends no Origin at all, so one must be supplied.
      expect(
        FrappeChatConfig(baseUrl: 'https://erp.example.com/').origin,
        'https://erp.example.com',
      );
      expect(
        FrappeChatConfig(baseUrl: 'http://localhost:8000').origin,
        'http://localhost:8000',
      );
    });
  });

  group('authentication headers', () {
    test('uses a token when a key and secret are set', () {
      final config = FrappeChatConfig(
        baseUrl: 'https://erp.example.com',
        apiKey: 'key',
        apiSecret: 'secret',
      );

      expect(config.usesTokenAuth, isTrue);
      expect(config.authHeaders['Authorization'], 'token key:secret');
      expect(config.authHeaders.containsKey('Cookie'), isFalse);
    });

    test('falls back to the session cookie', () {
      final config =
          FrappeChatConfig(baseUrl: 'https://erp.example.com', sid: 'abc123');

      expect(config.usesTokenAuth, isFalse);
      expect(config.cookieHeader, 'sid=abc123');
      expect(config.authHeaders['Cookie'], 'sid=abc123');
    });

    test('a full cookie string beats a bare sid', () {
      final config = FrappeChatConfig(
        baseUrl: 'https://erp.example.com',
        cookie: 'sid=abc; user_id=jane',
        sid: 'ignored',
      );

      expect(config.cookieHeader, 'sid=abc; user_id=jane');
    });

    test('includes the CSRF token when set', () {
      final config = FrappeChatConfig(
        baseUrl: 'https://erp.example.com',
        sid: 'abc',
        csrfToken: 'token-value',
      );

      expect(config.authHeaders['X-Frappe-CSRF-Token'], 'token-value');
    });

    test('no credentials means no auth headers', () {
      final config = FrappeChatConfig(baseUrl: 'https://erp.example.com');
      expect(config.cookieHeader, isNull);
      expect(config.authHeaders, isEmpty);
    });
  });

  group('copyWith', () {
    test('rotates the session without rebuilding the config', () {
      final config =
          FrappeChatConfig(baseUrl: 'https://erp.example.com', sid: 'old');
      final rotated = config.copyWith(sid: 'new');

      expect(rotated.cookieHeader, 'sid=new');
      expect(rotated.baseUrl, config.baseUrl);
      expect(rotated.socketUrl, config.socketUrl);
    });
  });

  group('ChatConnectionStatus', () {
    test('carries the server reason for a failure', () {
      const status = ChatConnectionStatus(
        ChatConnectionState.failed,
        'Invalid namespace',
      );

      expect(status.isConnected, isFalse);
      expect(status.message, 'Invalid namespace');
      expect(
        status,
        const ChatConnectionStatus(
          ChatConnectionState.failed,
          'Invalid namespace',
        ),
      );
    });

    test('connected has no message', () {
      const status = ChatConnectionStatus(ChatConnectionState.connected);
      expect(status.isConnected, isTrue);
      expect(status.message, isNull);
    });
  });
}
