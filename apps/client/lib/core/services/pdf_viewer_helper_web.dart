import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

void openPdfInBrowserTab(Uint8List bytes, String title) {
  try {
    final blobParts = [bytes.toJS].toJS;
    final blob = web.Blob(
      blobParts,
      web.BlobPropertyBag(type: 'application/pdf'),
    );
    final url = web.URL.createObjectURL(blob);
    web.window.open(url, '_blank');
  } catch (_) {}
}
