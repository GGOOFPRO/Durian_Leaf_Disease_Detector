import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// Request camera permission
  static Future<bool> requestCamera() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// Request storage permission (Android only)
  static Future<bool> requestStorage() async {
    if (!Platform.isAndroid) return false;

    // Check regular storage permission
    if (await Permission.storage.isGranted) return true;
    if (await Permission.storage.request().isGranted) return true;

    // For Android 13+, try photos/media permissions (fallback)
    if (await Permission.photos.isGranted) return true;
    if (await Permission.photos.request().isGranted) return true;

    return false;
  }
}
