# Frappe Chat Example

This is a simple example app that demonstrates how to use the `flutter_frappe_chat` package.

## Features Demonstrated

- Configuring connection to a Frappe server
- Setting up authentication (API keys or session)
- Opening a chat screen with real-time messaging
- Customizing chat partner display name

## Getting Started

1. Clone the repository and navigate to the example directory:
   ```bash
   cd example
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run
   ```

4. Fill in the required fields:
   - **Frappe Base URL**: Your Frappe server URL (e.g., `https://your-site.erpnext.com`)
   - **API Key** (optional): Your Frappe API key for authentication
   - **API Secret** (optional): Your Frappe API secret for authentication
   - **Room ID**: The chat room identifier
   - **Your Username**: Your display name in the chat
   - **Your Email**: Your email address
   - **Chat Partner Name** (optional): The name to display in the app bar

5. Tap "Open Chat" to open the chat screen

## Authentication Options

You can authenticate using either:

### Option 1: API Keys
Provide both `apiKey` and `apiSecret` in the configuration:
```dart
final config = FrappeChatConfig(
  baseUrl: 'https://your-frappe-site.com',
  apiKey: 'your_api_key',
  apiSecret: 'your_api_secret',
);
```

### Option 2: Session Cookie
Provide a session ID or complete cookie string:
```dart
final config = FrappeChatConfig(
  baseUrl: 'https://your-frappe-site.com',
  sid: 'your_session_id',
);
```

## Customization

The example provides a simple setup form. In a real application, you would typically:
- Store authentication credentials securely
- Fetch user information from your app's authentication system
- Integrate the chat screen into your existing navigation flow
- Customize the chat UI theme to match your app

## Learn More

For more information about the `flutter_frappe_chat` package, see the main [README](../README.md).
