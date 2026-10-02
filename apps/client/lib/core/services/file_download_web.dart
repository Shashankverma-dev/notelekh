import 'dart:typed_data';

import 'package:web/web.dart' as web;
import 'dart:js_interop';

void downloadFile(Uint8List bytes, String filename, String mimeType) {
  final jsArray = bytes.toJS;
  final blobParts = [jsArray].toJS;
  final options = web.BlobPropertyBag(type: mimeType);
  final blob = web.Blob(blobParts, options);
  final url = web.URL.createObjectURL(blob);

  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = url;
  anchor.download = filename;
  anchor.click();

  web.URL.revokeObjectURL(url);
}
