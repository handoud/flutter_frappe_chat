import 'package:flutter/material.dart';
import 'package:flutter_frappe_chat/flutter_frappe_chat.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Frappe Chat Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _baseUrlController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _apiSecretController = TextEditingController();
  final TextEditingController _roomController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _partnerNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Set default values for easier testing
    _baseUrlController.text = 'https://your-frappe-site.com';
    _roomController.text = 'room-id-123';
    _usernameController.text = 'John Doe';
    _emailController.text = 'john@example.com';
    _partnerNameController.text = 'Jane Doe';
  }

  void _openChat() {
    if (_baseUrlController.text.isEmpty ||
        _roomController.text.isEmpty ||
        _usernameController.text.isEmpty ||
        _emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
        ),
      );
      return;
    }

    // Create the configuration
    final config = FrappeChatConfig(
      baseUrl: _baseUrlController.text,
      apiKey: _apiKeyController.text.isNotEmpty
          ? _apiKeyController.text
          : null,
      apiSecret: _apiSecretController.text.isNotEmpty
          ? _apiSecretController.text
          : null,
    );

    // Navigate to the chat screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          config: config,
          room: _roomController.text,
          sender: _usernameController.text,
          senderEmail: _emailController.text,
          chatPartnerName: _partnerNameController.text.isNotEmpty
              ? _partnerNameController.text
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Frappe Chat Example'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Connection Settings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _baseUrlController,
              decoration: const InputDecoration(
                labelText: 'Frappe Base URL *',
                hintText: 'https://your-frappe-site.com',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _apiKeyController,
              decoration: const InputDecoration(
                labelText: 'API Key (optional)',
                hintText: 'Your API key',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _apiSecretController,
              decoration: const InputDecoration(
                labelText: 'API Secret (optional)',
                hintText: 'Your API secret',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            const Text(
              'Chat Settings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _roomController,
              decoration: const InputDecoration(
                labelText: 'Room ID *',
                hintText: 'room-id-123',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Your Username *',
                hintText: 'John Doe',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Your Email *',
                hintText: 'john@example.com',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _partnerNameController,
              decoration: const InputDecoration(
                labelText: 'Chat Partner Name (optional)',
                hintText: 'Jane Doe',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _openChat,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
              child: const Text(
                'Open Chat',
                style: TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '* Required fields',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _apiSecretController.dispose();
    _roomController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _partnerNameController.dispose();
    super.dispose();
  }
}
