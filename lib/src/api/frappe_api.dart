import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/chat_config.dart';

/// HTTP calls against the Frappe Chat API.
///
/// Endpoints come from the [frappe/chat](https://github.com/frappe/chat) app:
/// `chat.api.message.get_all`, `.send`, `.set_typing` and `.mark_as_read`.
class FrappeApiService {
  /// Connection settings.
  final FrappeChatConfig config;

  final http.Client _client;
  final bool _ownsClient;

  FrappeApiService(this.config, {http.Client? client})
      : _client = client ?? http.Client(),
        _ownsClient = client == null;

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        ...config.authHeaders,
      };

  Uri _uri(String method) => Uri.parse('${config.baseUrl}/api/method/$method');

  /// Extracts the message Frappe meant for the user out of an error body.
  static String _errorMessage(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map) {
        final raw = data['_server_messages'];
        if (raw != null) {
          final messages = raw is String ? jsonDecode(raw) : raw;
          if (messages is List && messages.isNotEmpty) {
            final first = messages.first;
            final decoded = first is String ? jsonDecode(first) : first;
            if (decoded is Map && decoded['message'] != null) {
              return decoded['message']
                  .toString()
                  .replaceAll(RegExp(r'<[^>]+>'), '')
                  .trim();
            }
          }
        }
        final message = data['message'];
        if (message is String && message.isNotEmpty) return message;
        final excType = data['exc_type'];
        if (excType is String && excType.isNotEmpty) return excType;
      }
    } catch (_) {
      // Not a Frappe JSON error; fall through.
    }
    return 'HTTP ${response.statusCode}';
  }

  Future<http.Response> _post(String method, Map<String, String> body) {
    return _client
        .post(_uri(method), headers: _headers, body: body)
        .timeout(config.timeout);
  }

  /// Loads a page of messages for [room].
  ///
  /// [limitStart] and [limitPageLength] are sent, but the stock
  /// `chat.api.message.get_all` accepts neither and returns the **entire** room
  /// history — Frappe drops unknown arguments silently. To get real pagination,
  /// override the method in a custom app:
  ///
  /// ```python
  /// @frappe.whitelist()
  /// def get_all(room, email, limit_start=0, limit_page_length=50):
  ///     if not is_user_allowed_in_room(room, email):
  ///         raise_not_authorized_error()
  ///     return frappe.get_all(
  ///         "Chat Message",
  ///         filters={"room": room},
  ///         fields=["name", "content", "sender", "creation", "sender_email"],
  ///         order_by="creation desc",
  ///         limit_start=int(limit_start),
  ///         limit_page_length=int(limit_page_length),
  ///     )
  /// ```
  ///
  /// Returns messages oldest first.
  Future<List<dynamic>> getMessages(
    String room,
    String email, {
    int limitStart = 0,
    int? limitPageLength,
  }) async {
    try {
      final response = await _post('chat.api.message.get_all', {
        'room': room,
        'email': email,
        'limit_start': limitStart.toString(),
        'limit_page_length': (limitPageLength ?? config.pageSize).toString(),
      });

      if (response.statusCode != 200) {
        throw FrappeChatException(
          'Could not load messages: ${_errorMessage(response)}',
          statusCode: response.statusCode,
        );
      }

      final data = jsonDecode(response.body);
      final messages = data is Map ? data['message'] : null;
      if (messages is! List) return const [];

      // A paginated server returns newest first; the stock one returns oldest
      // first. Normalise to oldest first so the list renders consistently.
      if (messages.length > 1) {
        final first = DateTime.tryParse(
          (messages.first is Map ? messages.first['creation'] : null)
                  ?.toString() ??
              '',
        );
        final last = DateTime.tryParse(
          (messages.last is Map ? messages.last['creation'] : null)
                  ?.toString() ??
              '',
        );
        if (first != null && last != null && first.isAfter(last)) {
          return messages.reversed.toList();
        }
      }
      return messages;
    } on TimeoutException {
      throw const FrappeChatException('Loading messages timed out');
    }
  }

  /// Sends a text message.
  ///
  /// The server echoes it back over the socket, so do not add it to the list
  /// yourself unless you are doing optimistic rendering.
  Future<void> sendMessage(
    String room,
    String content,
    String sender,
    String senderEmail,
  ) async {
    try {
      final response = await _post('chat.api.message.send', {
        'room': room,
        'content': content,
        'user': sender,
        'email': senderEmail,
      });

      if (response.statusCode != 200) {
        throw FrappeChatException(
          'Could not send message: ${_errorMessage(response)}',
          statusCode: response.statusCode,
        );
      }
    } on TimeoutException {
      throw const FrappeChatException('Sending timed out');
    }
  }

  /// Publishes a typing indicator.
  ///
  /// This is an HTTP call, not a socket emit. Frappe's realtime server has no
  /// handler that can invoke a whitelisted method, so emitting a typing event
  /// over the socket does nothing at all.
  Future<void> setTyping(
    String room,
    String user,
    bool isTyping, {
    bool isGuest = false,
  }) async {
    try {
      await _post('chat.api.message.set_typing', {
        'room': room,
        'user': user,
        'is_typing': isTyping.toString(),
        'is_guest': isGuest.toString(),
      });
    } catch (e) {
      // Typing indicators are cosmetic; never surface a failure.
      debugPrint('flutter_frappe_chat: typing update failed — $e');
    }
  }

  /// Marks the room as read via `chat.api.message.mark_as_read`.
  Future<void> markRoomAsRead(String room) async {
    try {
      await _post('chat.api.message.mark_as_read', {'room': room});
    } catch (e) {
      debugPrint('flutter_frappe_chat: mark as read failed — $e');
    }
  }

  /// Uploads a file and returns its `file_url`.
  ///
  /// Privacy follows [FrappeChatConfig.privateAttachments]. A public file lands
  /// under `/files/`, which Frappe serves to **anyone with the URL and no
  /// authentication**; a private one lands under `/private/files/` and needs
  /// [FrappeChatConfig.authHeaders] to fetch.
  Future<String> uploadFileBytes({
    required String fileName,
    required List<int> bytes,
    bool? isPrivate,
  }) async {
    final request = http.MultipartRequest('POST', _uri('upload_file'))
      ..headers.addAll(_headers)
      ..fields['file_name'] = fileName
      ..fields['is_private'] =
          (isPrivate ?? config.privateAttachments) ? '1' : '0'
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: fileName),
      );

    try {
      final streamed = await _client.send(request).timeout(config.timeout);
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map) {
          final message = data['message'];
          final url = message is Map ? message['file_url'] : null;
          if (url is String && url.isNotEmpty) return url;
        }
      }

      throw FrappeChatException(
        'Could not upload $fileName: ${_errorMessage(response)}',
        statusCode: response.statusCode,
      );
    } on TimeoutException {
      throw FrappeChatException('Upload of $fileName timed out');
    }
  }

  /// Releases the HTTP client, when this instance owns it.
  void dispose() {
    if (_ownsClient) _client.close();
  }
}

/// Thrown when a Frappe Chat API call fails.
class FrappeChatException implements Exception {
  final String message;
  final int? statusCode;

  const FrappeChatException(this.message, {this.statusCode});

  @override
  String toString() => message;
}
