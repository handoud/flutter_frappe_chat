## 1.0.0
* **Stable Release**: First stable version of `flutter_frappe_chat`.
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
