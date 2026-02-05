import 'package:permission_handler/permission_handler.dart';

class ChatPermissions {
  static Future<bool> requestMicrophone() async {
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
    }
    return status.isGranted;
  }

  static Future<bool> requestStorage() async {
    // For Android 13+ (SDK 33), storage permissions are split
    // This is a basic implementation, might need adjustment based on exact Android versions
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage.request();
    }

    // Also check for photos/media on newer Androids if needed,
    // but often 'storage' or specific media permissions are required.
    // Keeping it simple for now.
    return status.isGranted;
  }

  static Future<bool> requestCamera() async {
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
    }
    return status.isGranted;
  }
}
