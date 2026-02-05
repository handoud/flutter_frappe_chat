import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import '../models/chat_config.dart';

class FrappeApiService {
  final FrappeChatConfig config;
  final Dio _dio = Dio();

  FrappeApiService(this.config);

  Map<String, String> get _headers {
    final headers = <String, String>{'Accept': 'application/json'};
    if (config.apiKey != null && config.apiSecret != null) {
      headers['Authorization'] = 'token ${config.apiKey}:${config.apiSecret}';
    }
    return headers;
  }

  Future<String> uploadFile(File file) async {
    String fileName = file.path.split('/').last;

    FormData formData = FormData.fromMap({
      "file": await MultipartFile.fromFile(file.path, filename: fileName),
      "is_private": 0,
      "folder": "Home",
      "doctype": "Chat Message",
    });

    try {
      Response response = await _dio.post(
        "${config.baseUrl}/api/method/upload_file",
        data: formData,
        options: Options(
          headers: _headers,
          validateStatus: (status) => status! < 500,
        ),
      );

      if (response.statusCode == 200) {
        var data = response.data;
        if (data is String) {
          data = jsonDecode(data);
        }

        if (data['message'] != null) {
          return data['message']['file_url'];
        }
      }
      throw Exception("Failed to upload file: ${response.statusMessage}");
    } catch (e) {
      throw Exception("Error uploading file: $e");
    }
  }

  Future<List<dynamic>> getMessages(String room) async {
    try {
      var url = Uri.parse(
        "${config.baseUrl}/api/method/chat.api.message.get_all",
      );
      var response = await http.post(
        url,
        headers: _headers,
        body: {'room': room},
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        return data['message'] ?? [];
      } else {
        throw Exception("Failed to fetch messages: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Error fetching messages: $e");
    }
  }

  Future<void> sendMessage(
    String room,
    String content,
    String sender,
    String senderEmail,
  ) async {
    try {
      var url = Uri.parse("${config.baseUrl}/api/method/chat.api.message.send");
      var response = await http.post(
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

  Future<void> setTyping(String room, String user, bool isTyping) async {
    try {
      var url = Uri.parse(
        "${config.baseUrl}/api/method/chat.api.message.set_typing",
      );
      await http.post(
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
}
