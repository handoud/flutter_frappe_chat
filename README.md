# flutter_frappe_chat

Frappe Chat for Flutter: realtime messaging over Socket.IO, attachments, voice
notes, typing indicators and a themeable chat screen.

[![pub package](https://img.shields.io/pub/v/flutter_frappe_chat.svg)](https://pub.dev/packages/flutter_frappe_chat)

Requires the [frappe/chat](https://github.com/frappe/chat) app installed on your
Frappe / ERPNext site.

```dart
final config = FrappeChatConfig(
  baseUrl: 'https://erp.example.com',
  sid: mySessionId,
);

Navigator.push(context, MaterialPageRoute(
  builder: (_) => ChatScreen(
    config: config,
    room: 'ROOM-0001',
    sender: 'Jane Doe',
    senderEmail: 'jane@example.com',
    chatPartnerName: 'Support',
    theme: FrappeChatTheme.fromTheme(Theme.of(context)),
  ),
));
```

## Features

- Realtime messages over Frappe's Socket.IO service
- Typing indicators
- Images, PDFs and arbitrary file attachments
- Voice notes with a live waveform
- A themeable `ChatScreen`, or build your own on `FrappeApiService` and
  `FrappeSocketManager`
- Token or session authentication
- Private attachments, fetched with credentials

## Platforms

**Android, iOS and desktop.** Not web — the package uses `dart:io` for file
handling and audio recording.

## Install

```yaml
dependencies:
  flutter_frappe_chat: ^1.1.0
```

Requires Dart 3.8 / Flutter 3.32 or newer.

### Android

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
<!-- Android 12 and below -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="32"/>
```

`minSdkVersion 24` or higher, for flutter_sound.

### iOS

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Record voice notes</string>
<key>NSCameraUsageDescription</key>
<string>Take photos to send in chat</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Attach photos to messages</string>
```

## Configuration

```dart
final config = FrappeChatConfig(
  baseUrl: 'https://erp.example.com',

  // Either token auth...
  apiKey: 'your_api_key',
  apiSecret: 'your_api_secret',

  // ...or a session
  sid: mySessionId,

  timeout: const Duration(seconds: 30),
  privateAttachments: true,
);
```

With `flutter_next_auth`:

```dart
final config = FrappeChatConfig(
  baseUrl: 'https://erp.example.com',
  sid: await flutternext.getStoredSid(),
);
```

### The socket URL

Frappe's realtime server registers its handlers on `io.of(/^\/.*$/)` and then
**rejects any namespace that is not the site name**. Connecting to the bare host
fails with `Invalid namespace`.

This package appends the namespace for you — `socketUrl` becomes
`https://erp.example.com/erp.example.com`. Set `siteName` when the site name
differs from the host:

```dart
FrappeChatConfig(
  baseUrl: 'http://localhost:8000',
  siteName: 'mysite.localhost',   // -> http://localhost:8000/mysite.localhost
);
```

Frappe also refuses a connection whose `Origin` header does not match `Host`.
Native Dart clients send no `Origin`, so this package sends one derived from
`baseUrl`, along with `x-frappe-site-name`.

## Theming

```dart
ChatScreen(
  // ...
  theme: FrappeChatTheme.fromTheme(Theme.of(context)),
);
```

Or set colours yourself:

```dart
const FrappeChatTheme(
  background: Color(0xFF0E1621),
  outgoingBubble: Color(0xFF2B5278),
  incomingBubble: Color(0xFF182533),
  outgoingText: Colors.white,
  incomingText: Colors.white,
  accent: Color(0xFF64B5F6),
  bubbleRadius: 16,
);
```

## Building your own UI

```dart
final api = FrappeApiService(config);
final socket = FrappeSocketManager(config);

socket
  ..onMessageReceived = (message) => setState(() => _messages.add(message))
  ..onTypingChanged = (isTyping, user) => setState(() => _typing = isTyping)
  ..onChatUpdate = (update) => refreshRoomList()
  ..connect(room: roomId);

// Watch the real connection state — never assume connect() succeeded.
socket.connectionStatus.addListener(() {
  final status = socket.connectionStatus.value;
  if (status.state == ChatConnectionState.failed) {
    print('Realtime failed: ${status.message}');
  }
});

await api.sendMessage(roomId, 'Hello', 'Jane Doe', 'jane@example.com');
await api.setTyping(roomId, 'Jane Doe', true);
await api.markRoomAsRead(roomId);

socket.dispose();
api.dispose();
```

### Identifying messages

`chat.api.message.get_all` returns only `content`, `sender`, `creation` and
`sender_email` — **no document id** — and the realtime payload carries none
either. Use `ChatMessage.localKey`, which derives a stable identity from those
fields, for deduplication and list keys. `ChatMessage` implements `==` and
`hashCode` on it, so a `Set<ChatMessage>` deduplicates correctly.

## Attachments

```dart
final url = await api.uploadFileBytes(
  fileName: 'photo.png',
  bytes: bytes,
);
await api.sendMessage(roomId, url, sender, senderEmail);
```

> Frappe serves `/files/` to **anyone with the URL, with no authentication**.
> Set `privateAttachments: true` for confidential chats — attachments then land
> under `/private/files/` and this package fetches them with credentials.
> Private audio is downloaded to a temporary file before playback, because
> flutter_sound cannot send headers.

## Pagination

The stock `chat.api.message.get_all` takes no pagination arguments and returns
the **entire** room history on every open. `getMessages()` sends `limit_start`
and `limit_page_length` anyway, so overriding the method in a custom app is all
that is needed:

```python
@frappe.whitelist()
def get_all(room, email, limit_start=0, limit_page_length=50):
    if not is_user_allowed_in_room(room, email):
        raise_not_authorized_error()
    return frappe.get_all(
        "Chat Message",
        filters={"room": room},
        fields=["name", "content", "sender", "creation", "sender_email"],
        order_by="creation desc",
        limit_start=int(limit_start),
        limit_page_length=int(limit_page_length),
    )
```

Adding `name` to the field list also gives messages real ids.

## Read receipts

Off by default. The stock `Chat Message` DocType has **no `seen` field**, so a
tick could never change state. Add one in a custom app, then turn the UI on:

```dart
ChatScreen(showReadReceipts: true, /* ... */);
```

## Troubleshooting

| Symptom | Cause |
| --- | --- |
| `Invalid namespace` | The socket URL is missing the site namespace. Set `siteName`. |
| `Invalid origin` | Frappe compares `Origin` to `Host`. Check that `baseUrl` is the host actually serving the site. |
| `Unauthorized` | Bad `sid` or API key/secret. |
| Connects, no messages | Confirm the sender's email is a member of the room — `chat.api.message.send` publishes only to members. |
| Attachments 404 | Private files need credentials. Set `privateAttachments` consistently. |

`FrappeSocketManager` logs a specific hint for each of the first three.

## API reference

| Type | Purpose |
| --- | --- |
| `FrappeChatConfig` | URL, credentials, socket namespace, timeouts |
| `FrappeApiService` | `getMessages`, `sendMessage`, `setTyping`, `markRoomAsRead`, `uploadFileBytes` |
| `FrappeSocketManager` | `connect`, `subscribeToRoom`, `connectionStatus`, `dispose` |
| `ChatScreen` | The ready-made screen |
| `FrappeChatTheme` | Colours and shapes |
| `ChatMessage` | `localKey`, `createdAt`, `isFrom` |
| `MessageBubble` | A single bubble, with `ChatAttachmentKind` detection |
| `ChatPermissions` | Microphone, camera and media access |

## License

MIT — see [LICENSE](LICENSE).
