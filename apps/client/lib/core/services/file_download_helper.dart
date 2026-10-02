import 'dart:typed_data';
import 'package:ai_workspace_client/core/services/file_download_stub.dart'
    if (dart.library.js_interop) 'package:ai_workspace_client/core/services/file_download_web.dart'
    as platform;

class FileDownloadHelper {
  static void downloadBytes({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) {
    platform.downloadFile(bytes, filename, mimeType);
  }
}
