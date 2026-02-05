# Flutter Frappe Chat

A complete, customizable Flutter package for integrating Frappe Chat with your application.
It handles WebSocket connections, authentication, file uploads (images, PDFs, generic files), voice notes, and real-time messaging.

## Features

- 🚀 **Real-time Messaging**: Powered by Socket.IO.
- 📎 **File Uploads**: Send images, PDFs, and other files.
- 🎙️ **Voice Notes**: Integrated audio recorder with permissions.
- 🤳 **UI Kit**: Ready-to-use `ChatScreen` with attachment sheet and message bubbles.
- 🔐 **Authentication**: Supports token-based auth (API Key/Secret).
- 📱 **Cross-Platform**: Designed for iOS, Android, Web, and Desktop.

## Installation

Add this package to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_frappe_chat: ^0.1.0
```

## Usage

### 1. Initialize Configuration

You can use either API Key/Secret **OR** a Session Cookie (e.g., `sid`).

**Option A: API Key & Secret**
```dart
final config = FrappeChatConfig(
  baseUrl: "https://your-frappe-site.com",
  apiKey: "your_api_key",
  apiSecret: "your_api_secret",
);
```

**Option B: Session Cookie (Recommended for Mobile Apps)**
If you are logged in, simply pass the session ID (`sid`). The package will format it automatically.

```dart
final config = FrappeChatConfig(
  baseUrl: "https://your-frappe-site.com",
  sid: "YOUR_SESSION_ID",
);
```

### 2. Open Chat Screen

Navigate to the `ChatScreen` widget.

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => ChatScreen(
        config: config,
        room: "ROOM_ID", // The Frappe Chat Room name
        sender: "User Full Name",
        senderEmail: "user@example.com",
        chatPartnerName: "Support Agent",
    ),
  ),
);
```

## Permissions

This package uses `permission_handler`. Ensure you add the necessary permissions to your platform configuration.

**Android (`AndroidManifest.xml`):**
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<!-- For Android 13+ -->
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
```

**iOS (`Info.plist`):**
```xml
<key>NSMicrophoneUsageDescription</key>
<string>We need access to the microphone to send voice notes.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>We need access to photos to send attachments.</string>
```

## Contributing

Feel free to open issues or submit PRs to improve this package.
