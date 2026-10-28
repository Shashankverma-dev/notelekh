import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';

class ExtractedPdfPage {
  final int pageNumber;
  final String title;
  final String text;

  const ExtractedPdfPage({
    required this.pageNumber,
    required this.title,
    required this.text,
  });
}

class PdfExtractorService {
  /// Extracts text and structures pages from raw PDF bytes in pure Dart.
  static List<ExtractedPdfPage> extractPages(
    Uint8List bytes, {
    String docTitle = 'Document',
  }) {
    try {
      final rawChunks = _extractStreamChunks(bytes);
      if (rawChunks.isEmpty) {
        // Fallback: try plain text search in PDF if streams were uncompressed
        final fallbackText = _extractDirectStrings(bytes);
        if (fallbackText.isNotEmpty) {
          return [
            ExtractedPdfPage(
              pageNumber: 1,
              title: '$docTitle - Page 1',
              text: fallbackText,
            ),
          ];
        }
        return [];
      }

      final pages = <ExtractedPdfPage>[];
      for (int i = 0; i < rawChunks.length; i++) {
        final chunkText = rawChunks[i];
        if (chunkText.trim().length > 15) {
          pages.add(
            ExtractedPdfPage(
              pageNumber: pages.length + 1,
              title: '$docTitle - Page ${pages.length + 1}',
              text: chunkText.trim(),
            ),
          );
        }
      }

      return pages;
    } catch (e) {
      debugPrint('[PdfExtractorService] Error extracting PDF text: $e');
      return [];
    }
  }

  static List<String> _extractStreamChunks(Uint8List bytes) {
    final decompressedChunks = <String>[];
    int i = 0;
    final len = bytes.length;

    while (i < len - 10) {
      int streamStart = -1;
      for (int j = i; j < len - 6; j++) {
        if (bytes[j] == 115 && // 's'
            bytes[j + 1] == 116 && // 't'
            bytes[j + 2] == 114 && // 'r'
            bytes[j + 3] == 101 && // 'e'
            bytes[j + 4] == 97 && // 'a'
            bytes[j + 5] == 109) { // 'm'
          int contentStart = j + 6;
          if (contentStart < len && bytes[contentStart] == 13) contentStart++; // \r
          if (contentStart < len && bytes[contentStart] == 10) contentStart++; // \n
          streamStart = contentStart;
          break;
        }
      }

      if (streamStart == -1) break;

      int streamEnd = -1;
      for (int k = streamStart; k < len - 9; k++) {
        if (bytes[k] == 101 && // 'e'
            bytes[k + 1] == 110 && // 'n'
            bytes[k + 2] == 100 && // 'd'
            bytes[k + 3] == 115 && // 's'
            bytes[k + 4] == 116 && // 't'
            bytes[k + 5] == 114 && // 'r'
            bytes[k + 6] == 101 && // 'e'
            bytes[k + 7] == 97 && // 'a'
            bytes[k + 8] == 109) { // 'm'
          streamEnd = k;
          if (streamEnd > streamStart &&
              (bytes[streamEnd - 1] == 10 || bytes[streamEnd - 1] == 13)) {
            streamEnd--;
          }
          if (streamEnd > streamStart &&
              (bytes[streamEnd - 1] == 10 || bytes[streamEnd - 1] == 13)) {
            streamEnd--;
          }
          break;
        }
      }

      if (streamEnd == -1 || streamEnd <= streamStart) {
        i = streamStart + 1;
        continue;
      }

      final streamBytes = bytes.sublist(streamStart, streamEnd);
      i = streamEnd + 9;

      Uint8List decompressed;
      try {
        decompressed = Uint8List.fromList(ZLibDecoder().decodeBytes(streamBytes));
      } catch (_) {
        decompressed = streamBytes;
      }

      final textContent = _parsePdfOperators(decompressed);
      if (textContent.trim().isNotEmpty) {
        decompressedChunks.add(textContent.trim());
      }
    }

    return decompressedChunks;
  }

  static String _parsePdfOperators(Uint8List stream) {
    final str = latin1.decode(stream);
    final buffer = StringBuffer();

    // Match ( ... ) Tj
    final tjRegex = RegExp(r'\(([^)]*)\)\s*(?:Tj|\x27|\x22)');
    for (final m in tjRegex.allMatches(str)) {
      final text = _unescapePdf(m.group(1) ?? '');
      if (text.isNotEmpty) {
        buffer.write(text);
        buffer.write(' ');
      }
    }

    // Match [ ... ] TJ
    final arrayTjRegex = RegExp(r'\[([^\]]*)\]\s*TJ');
    for (final m in arrayTjRegex.allMatches(str)) {
      final arrayContent = m.group(1) ?? '';
      final innerMatches = RegExp(r'\(([^)]*)\)').allMatches(arrayContent);
      for (final im in innerMatches) {
        final text = _unescapePdf(im.group(1) ?? '');
        if (text.isNotEmpty) {
          buffer.write(text);
        }
      }
      buffer.write(' ');
    }

    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _extractDirectStrings(Uint8List bytes) {
    final str = latin1.decode(bytes);
    final buffer = StringBuffer();
    final parenRegex = RegExp(r'\(([A-Za-z0-9 .,;:!?"\x27-]{4,})\)');
    for (final m in parenRegex.allMatches(str)) {
      final s = m.group(1)?.trim() ?? '';
      if (s.isNotEmpty && !s.startsWith('/')) {
        buffer.write(s);
        buffer.write(' ');
      }
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _unescapePdf(String input) {
    return input
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\r', '\r')
        .replaceAll(r'\t', '\t')
        .replaceAll(r'\(', '(')
        .replaceAll(r'\)', ')')
        .replaceAll(r'\\', '\\');
  }
}
