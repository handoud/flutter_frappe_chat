import 'package:permission_handler/permission_handler.dart';

/// Runtime permission helpers for the chat UI.
class ChatPermissions {
  const ChatPermissions._();

  /// Requests microphone access, needed to record a voice note.
  static Future<bool> requestMicrophone() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;
    return (await Permission.microphone.request()).isGranted;
  }

  /// Requests camera access.
  static Future<bool> requestCamera() async {
    final status = await Permission.camera.status;
    if (status.isGranted) return true;
    return (await Permission.camera.request()).isGranted;
  }

  /// Requests access to photos and media.
  ///
  /// Android 13 (API 33) split `READ_EXTERNAL_STORAGE` into per-media
  /// permissions, so `photos` is tried first and `storage` is the fallback for
  /// older releases. On iOS only `photos` applies.
  static Future<bool> requestMediaAccess() async {
    final photos = await Permission.photos.status;
    if (photos.isGranted || photos.isLimited) return true;

    final requested = await Permission.photos.request();
    if (requested.isGranted || requested.isLimited) return true;

    final storage = await Permission.storage.status;
    if (storage.isGranted) return true;
    return (await Permission.storage.request()).isGranted;
  }

  /// Deprecated alias for [requestMediaAccess].
  @Deprecated(
    'Renamed to requestMediaAccess(), which also handles the Android 13+ '
    'per-media permissions. Will be removed in 2.0.0.',
  )
  static Future<bool> requestStorage() => requestMediaAccess();
}
