import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../models/chat_config.dart';
import '../utils/http_client_helper.dart';

/// Service class for making HTTP API calls to Frappe Chat endpoints.
///
/// This service handles all REST API interactions including:
/// - Fetching message history
/// - Sending messages
/// - Uploading file attachments
/// - Setting typing status
///
/// Authentication is handled automatically using the credentials provided in [config].
class FrappeApiService {
  /// The configuration containing server URL and authentication details.
  final FrappeChatConfig config;

  final http.Client _client = getHttpClient();

  /// Creates a new [FrappeApiService] with the given [config].
  FrappeApiService(this.config);

  /// Returns HTTP headers with authentication credentials.
  ///
  /// Includes either API token or cookie-based authentication based on [config].
  Map<String, String> get _headers {
    final headers = <String, String>{'Accept': 'application/json'};
    if (config.apiKey != null && config.apiSecret != null) {
      headers['Authorization'] = 'token ${config.apiKey}:${config.apiSecret}';
    }

    if (config.cookieHeader != null) {
      headers['Cookie'] = config.cookieHeader!;
    }

    if (config.csrfToken != null) {
      headers['X-Frappe-CSRF-Token'] = config.csrfToken!;
    }

    return headers;
  }

  /// Uploads a file to the Frappe server.
  ///
  /// The [file] is uploaded to the server and becomes accessible via a URL.
  /// Returns the URL of the uploaded file which can be included in chat messages.
  ///
  /// Throws an [Exception] if the upload fails.
  Future<String> uploadFile(File file) async {
    String fileName = file.path.split('/').last;
    var url = Uri.parse("${config.baseUrl}/api/method/upload_file");

    // MultipartRequest handles its own client logic usually, but to support credentials
    // we might need to use _client.send. However, standard http.MultipartRequest
    // doesn't easily allow setting a client.
    // For web file upload with credentials, usage of BrowserClient is tricky with MultipartRequest directly
    // unless we use _client.send(request).

    var request = http.MultipartRequest('POST', url);

    // Add Headers
    request.headers.addAll(_headers);
    // Explicitly remove Expect header if http client adds it, though usually safe
    // request.headers.remove('Expect');

    // Add Fields
    // Add Fields
    request.fields['filename'] = fileName;
    request.fields['is_private'] = '0';
    request.fields['from_form'] = '1';
    // request.fields['folder'] = 'Home'; // Removed to avoid validation error
    // request.fields['doctype'] = 'Chat Message'; // Removed: Cannot attach to non-existent doc

    // Add File
    var stream = http.ByteStream(file.openRead());
    var length = await file.length();
    var multipartFile = http.MultipartFile(
      'file',
      stream,
      length,
      filename: fileName,
    );
    request.files.add(multipartFile);

    try {
      // Use _client.send instead of request.send() to use our configured client
      var response = await _client.send(request);
      var responseString = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        var data = jsonDecode(responseString);
        if (data['message'] != null) {
          return data['message']['file_url'];
        }
      }
      throw Exception(
          "Failed to upload file: ${response.statusCode} - $responseString");
    } catch (e) {
      throw Exception("Error uploading file: $e");
    }
  }

  /// Fetches all messages for a specific chat room.
  ///
  /// Retrieves the message history for the given [room] for the user identified by [email].
  /// Returns a list of message data as JSON maps.
  ///
  /// Throws an [Exception] if the request fails.
  Future<List<dynamic>> getMessages(String room, String email) async {
    try {
      var url = Uri.parse(
        "${config.baseUrl}/api/method/chat.api.message.get_all",
      );
      var response = await _client.post(
        url,
        headers: _headers,
        body: {'room': room, 'email': email, 'user': email},
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        return data['message'] ?? [];
      } else {
        debugPrint(
            "Failed to fetch messages: ${response.statusCode} - ${response.body}");
        throw Exception(
            "Failed to fetch messages: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      throw Exception("Error fetching messages: $e");
    }
  }

  /// Sends a text message to a chat room.
  ///
  /// Sends a message with the given [content] to the specified [room].
  /// The message is attributed to the user identified by [sender] and [senderEmail].
  ///
  /// Throws an [Exception] if sending fails.
  Future<void> sendMessage(
    String room,
    String content,
    String sender,
    String senderEmail,
  ) async {
    try {
      var url = Uri.parse("${config.baseUrl}/api/method/chat.api.message.send");
      var response = await _client.post(
        url,
        headers: _headers,
        body: {
          'room': room,
          'content': content,
          'user': sender,
          'email': senderEmail,
        },
      );

      if (response.statusCode != 200) {
        throw Exception("Failed to send message: ${response.body}");
      }
    } catch (e) {
      throw Exception("Error sending message: $e");
    }
  }

  /// Updates the typing status for a user in a chat room.
  ///
  /// Notifies the server that [user] is currently typing (or has stopped typing)
  /// in the specified [room]. Set [isTyping] to true when the user starts typing
  /// and false when they stop.
  ///
  /// This is typically called automatically by the chat UI.
  Future<void> setTyping(String room, String user, bool isTyping) async {
    try {
      var url = Uri.parse(
        "${config.baseUrl}/api/method/chat.api.message.set_typing",
      );
      await _client.post(
        url,
        headers: _headers,
        body: {
          'room': room,
          'user': user,
          'is_typing': isTyping.toString(),
          'is_guest': 'false',
        },
      );
    } catch (e) {
      debugPrint("Error setting typing status: $e");
    }
  }

  /// Marks a specific message as read/seen.
  ///
  /// Uses [frappe.client.set_value] to update the 'seen' status of the [ChatMessage].
  Future<void> markMessageAsRead(String messageId) async {
    try {
      var url = Uri.parse(
        "${config.baseUrl}/api/method/frappe.client.set_value",
      );
      await _client.post(
        url,
        headers: _headers,
        body: {
          'doctype': 'Chat Message',
          'name': messageId,
          'fieldname': 'seen',
          'value': '1',
        },
      );
    } catch (e) {
      debugPrint("Error marking message as read: $e");
    }
  }
}
