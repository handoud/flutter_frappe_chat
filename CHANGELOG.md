## 1.1.0

The realtime layer did not work against a stock Frappe site. This release fixes
that, removes several features that could never have worked, and makes the UI
themeable.

### Fixed — realtime

* **The socket now connects.** Frappe registers its realtime handlers on
  `io.of(/^\/.*$/)` and its auth middleware rejects any namespace that is not
  the site name, so connecting to the bare `baseUrl` always failed with
  `Invalid namespace`. `FrappeChatConfig.socketUrl` now appends the site
  namespace automatically (override with the new `siteName`).
* **The `Origin` header is now sent.** The same middleware refuses a connection
  when `Origin` does not match `Host`, and a native Dart client sends no
  `Origin` at all — so every connection was refused with `Invalid origin`.
  `x-frappe-site-name` is sent too, for multi-tenant benches.
* **Connection failures are visible.** `connect_error` was never listened to, so
  all of the above failed silently. `FrappeSocketManager.connectionStatus` is
  now a `ValueNotifier<ChatConnectionStatus>` carrying the state and the
  server's reason, with targeted hints logged for the common causes.
* **The status indicator no longer lies.** It was set to "connected"
  unconditionally, right after `connect()` was called, regardless of whether a
  socket existed. It is now driven by the real connection state.
* **Reconnecting no longer duplicates messages.** `subscribeToRoom` added
  listeners without removing the old ones, and `onConnect` re-subscribed after
  every automatic reconnect, so each message was appended once per reconnect.
* **Typing indicators work.** `sendTyping` emitted a `doc_events` socket event;
  Frappe's realtime server has no such handler and discarded it silently. Typing
  now goes through `chat.api.message.set_typing` over HTTP — the endpoint this
  package already implemented but never called — throttled to one call per two
  seconds with an automatic stop after three seconds of inactivity.
* Removed the `doc_update` and `message_update` listeners. Frappe Chat publishes
  neither, and core's `doc_update` only reaches subscribers of a document room.
  `latest_chat_updates`, which the app really does publish, is now exposed
  through `onChatUpdate`. `subscribeToDoc()` was added for document rooms.

### Fixed — messages

* **Messages are no longer mixed up.** `chat.api.message.get_all` returns no
  `name`, and neither does the realtime payload, so every `ChatMessage.name` was
  empty and `indexWhere((m) => m.name == ...)` matched the *first* message —
  updates overwrote the oldest one. `ChatMessage.localKey` derives a stable
  identity from creation time, sender and content, and is used for equality and
  deduplication.
* **Socket messages during startup are no longer lost.** History loading
  replaced the message list wholesale, discarding anything the socket delivered
  while the request was in flight. Those messages are now buffered and merged.
* **No more `setState` after dispose.** Message loading and the socket callback
  updated state without checking `mounted`.
* Leaks fixed: the scroll controller is disposed, the socket manager has a real
  `dispose()` that unsubscribes and clears callbacks, and the HTTP client is
  closed.

### Fixed — other

* **Typing no longer rebuilds the message list.** Every keystroke called a bare
  `setState(() {})` to re-evaluate the send/mic button, rebuilding the whole
  screen including the `ListView`. Only the button rebuilds now.
* Requests have timeouts, and errors carry the message Frappe showed the user
  (from `_server_messages`) instead of a raw status code.
* Attachment detection no longer treats a text message containing `/files/` as
  an attachment, and copes with query strings and uppercase extensions.
* Timestamps are formatted for the reader's locale instead of being printed as a
  raw ISO string.
* The bundled notification sound is now declared in `pubspec.yaml`, so it is
  actually packaged. `notificationSoundPath` defaults to it.

### Removed

* **Read receipts.** The stock `Chat Message` DocType has **no `seen` field**,
  and its only permission row is System Manager, so `markMessageAsRead` could
  never persist anything for an ordinary user. The tick is now behind
  `showReadReceipts` (default off) and `markRoomAsRead()` calls the real
  endpoint, `chat.api.message.mark_as_read`.
* **Six unused dependencies** — `dio`, `mime`, `path`, `flutter_pdfview` and
  `provider` were declared and never imported; `intl` is now genuinely used.
  `flutter_pdfview` was pulling native Android and iOS view code for an inline
  PDF viewer that did not exist.
* The dead web HTTP shim (`http_client_helper.dart` and friends). It could never
  run: three files import `dart:io`, so the package does not compile for web.
  It also keyed on the deprecated `dart.library.html`.
* `verifyInsecure`, which was documented as controlling SSL verification and
  read nowhere.
* `AudioRecorder`, superseded by `RecordingInput` and never referenced.

### Added

* `FrappeChatTheme` — every colour, the bubble radius and the message text style.
  `FrappeChatTheme.fromTheme(Theme.of(context))` derives one from your app's
  `ColorScheme`, including dark mode.
* `ChatScreen.actions` for app bar actions (the hardcoded, non-functional call
  button is gone), `ChatScreen.onError` for error handling, and
  `ChatScreen.showReadReceipts`.
* `FrappeChatConfig.privateAttachments`. Frappe serves `/files/` to **anyone
  with the URL and no authentication**; uploads were hardcoded to public. Turn
  this on for confidential chats — images and voice notes are fetched with
  credentials, and private audio is downloaded before playback because
  flutter_sound cannot send headers.
* `FrappeChatConfig.copyWith()`, so a rotated session id can be swapped in.
* `FrappeApiService.uploadFileBytes()` replaces the `dart:io`-bound
  `uploadFile(File)`, so the API layer no longer depends on `dart:io`.
* `getMessages()` accepts `limitStart` / `limitPageLength`. The stock server
  ignores them and returns the entire room history; the doc comment includes the
  five-line custom method that makes pagination real.
* `ChatPermissions.requestMediaAccess()`, which handles the Android 13+ split of
  storage into per-media permissions. `requestStorage()` is deprecated.
* An `analysis_options.yaml` — `flutter_lints` was a dev dependency but nothing
  included it, so no lint had ever run on this package.
* 36 tests covering the socket URL and origin, auth headers, message identity,
  attachment detection and theming.

### Changed

* **Platform support is now stated honestly.** The README claimed "iOS, Android,
  Web and Desktop"; the package imports `dart:io` and cannot build for web.
* Minimum SDK is Dart 3.8 / Flutter 3.32.
* `file_picker` moved to `^11.0.0`, whose `pickFiles` is now static.
  `permission_handler` moved to `^13.0.0`.

### Migrating from 1.0.x

```dart
// Attachments now arrive as bytes rather than a dart:io File.
AttachmentSheet(onFileSelected: (attachment) {
  print('${attachment.name}: ${attachment.bytes.length} bytes');
});

// Upload takes bytes.
await api.uploadFileBytes(fileName: 'photo.png', bytes: bytes);

// Read the connection state instead of assuming it.
socket.connectionStatus.addListener(() => print(socket.connectionStatus.value));

// Typing goes over HTTP, not the socket.
await api.setTyping(room, user, true);
```

`MessageBubble` now takes `config:` instead of `baseUrl:`.

## 1.0.1
* **Stable Release**: First stable version of `flutter_frappe_chat`.
## 1.0.0
* **Enhanced Configuration**: Added support for `csrfToken`, `socketUrlOverride`, and `verifyInsecure` SSL options in `FrappeChatConfig`.
* **Improved File Uploads**: Better handling of multipart requests with authentication headers.
* **Updated Dependencies**: Upgraded `permission_handler` to v12.0.1 for better Android/iOS compatibility.
* **Bug Fixes**: Improved error handling for WebSocket connections and API responses.

## 0.1.3
* Added email parameter to `getMessages` API call for better user-specific message retrieval.

## 0.1.2
* Updated `permission_handler` to the latest version.
* Improved error handling in API and WebSocket communication.

## 0.1.1
* Fixed unused element warning in audio recorder.
* Improved stability.

## 0.0.1

* Initial release.
* Added `FrappeApiService` for message and file API handling.
* Added `FrappeSocketManager` for real-time WebSocket communication.
* Added `ChatScreen` UI with attachment support and voice recorder.
