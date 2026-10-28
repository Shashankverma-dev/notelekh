import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_workspace_client/core/services/pdf_extractor_service.dart';

void main() {
  group('PdfExtractorService Tests', () {
    test('extractPages parses standard BT ET text stream', () {
      // Create minimal valid PDF content stream with BT (text) ET
      const pdfText = '''%PDF-1.4
1 0 obj
<< /Type /Catalog /Pages 2 0 R >>
endobj
2 0 obj
<< /Type /Pages /Kids [3 0 R] /Count 1 >>
endobj
3 0 obj
<< /Type /Page /Parent 2 0 R /Contents 4 0 R >>
endobj
4 0 obj
<< /Length 50 >>
stream
BT
/F1 12 Tf
(Machine Learning Lecture Notes) Tj
ET
endstream
endobj
xref
0 5
0000000000 65535 f 
0000000009 00000 n 
0000000058 00000 n 
0000000115 00000 n 
0000000179 00000 n 
trailer
<< /Size 5 /Root 1 0 R >>
startxref
280
%%EOF''';

      final bytes = utf8.encode(pdfText);
      final pages = PdfExtractorService.extractPages(bytes, docTitle: 'ML Lecture');

      expect(pages.isNotEmpty, true);
      expect(pages.first.text, contains('Machine Learning Lecture Notes'));
    });

    test('extractPages extracts multiple text segments and TJ array format', () {
      const pdfText = '''%PDF-1.4
stream
BT
[(Deep) -20 (Learning) 10 (Architecture)] TJ
ET
endstream''';

      final bytes = utf8.encode(pdfText);
      final pages = PdfExtractorService.extractPages(bytes, docTitle: 'Deep Learning');

      expect(pages.isNotEmpty, true);
      expect(pages.first.text, contains('Deep Learning Architecture'));
    });
  });
}
