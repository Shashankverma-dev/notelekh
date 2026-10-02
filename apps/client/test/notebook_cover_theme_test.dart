import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_workspace_client/features/dashboard/widgets/notebook_cover_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Notebook Cover & Luxury Theme Tests', () {
    test('LuxuryCoverTheme presets are populated and valid', () {
      expect(LuxuryCoverTheme.solidColors.length, greaterThanOrEqualTo(16));
      expect(LuxuryCoverTheme.gradients.length, greaterThanOrEqualTo(12));
      expect(LuxuryCoverTheme.patterns.length, greaterThanOrEqualTo(7));

      for (final g in LuxuryCoverTheme.gradients) {
        expect(g.length, 3);
        final c1 = parseHexColor(g[0]);
        final c2 = parseHexColor(g[1]);
        expect(c1.a, greaterThan(0));
        expect(c2.a, greaterThan(0));
      }
    });

    testWidgets('NotebookCoverWidget renders bookplate with title', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: NotebookCoverWidget(
                title: 'Architecture Portfolio',
                coverColor: Color(0xFF1B2A47),
                isDark: false,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Architecture Portfolio'), findsOneWidget);
      expect(find.text('JOURNAL'), findsOneWidget);
    });

    testWidgets('NotebookCoverWidget renders gradient style properly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: NotebookCoverWidget(
                title: 'Velvet Notes',
                coverColor: Color(0xFF1B263B),
                coverStyle: 'gradient',
                coverStyleData: '1B263B,0D1B2A',
                isDark: true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Velvet Notes'), findsOneWidget);
    });

    testWidgets('NotebookCoverWidget renders tactile pattern without crash', (tester) async {
      for (final p in LuxuryCoverTheme.patterns) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: NotebookCoverWidget(
                  title: 'Pattern ${p.$2}',
                  coverColor: const Color(0xFF38261E),
                  coverStyle: 'pattern',
                  coverStyleData: p.$1,
                  isDark: false,
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.text('Pattern ${p.$2}'), findsOneWidget);
      }
    });

    testWidgets('NotebookCoverWidget handles crest / emblem or clean plate', (tester) async {
      // 1. Clean plate without emoji
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: NotebookCoverWidget(
                title: 'Pure Classic',
                coverColor: Color(0xFF17382B),
                coverEmoji: '',
                isDark: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pure Classic'), findsOneWidget);

      // 2. Custom emblem
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: NotebookCoverWidget(
                title: 'Royal Journal',
                coverColor: Color(0xFF4A1525),
                coverEmoji: '⚜️',
                isDark: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('⚜️'), findsOneWidget);
      expect(find.text('Royal Journal'), findsOneWidget);
    });
  });
}
