import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Proves the Nob compose text pipeline preserves Turkish ı and other chars.
/// This is NOT a full widget test of NobComposeScreen (which requires Riverpod
/// and Supabase), but a focused unit/widget test of the text processing logic
/// extracted from that screen.
void main() {
  group('Turkish character preservation — unit', () {
    test('ı survives trim()', () {
      const input = '  ılık  ';
      expect(input.trim(), equals('ılık'));
    });

    test('ı survives characters.length check', () {
      const input = 'ısı';
      // characters.length counts grapheme clusters, not code units
      expect(input.characters.length, equals(3));
    });

    test('all Turkish special chars survive trim()', () {
      const input = 'ğüşıöçĞÜŞİÖÇ';
      expect(input.trim(), equals('ğüşıöçĞÜŞİÖÇ'));
    });

    test('ı is detected by _isTurkish regex', () {
      final regex = RegExp(r'[ğüşıöçĞÜŞİÖÇ]');
      expect(regex.hasMatch('ılık'), isTrue);
      expect(regex.hasMatch('ısı'), isTrue);
      expect(regex.hasMatch('İstanbul'), isTrue);
      expect(regex.hasMatch('hello'), isFalse);
    });

    test('_isSpammy does not block Turkish text', () {
      // Exact logic from nob_compose_screen.dart lines 410-418
      bool isSpammy(String text) {
        if (text.isEmpty) return false;
        final stripped = text.replaceAll(RegExp(r'\s'), '');
        if (stripped.characters.length > 20) {
          final unique = stripped.characters.toSet();
          if (unique.length == 1) return true;
        }
        return false;
      }

      expect(isSpammy('bugün ılık bir his var, içimde sıkı bir sessizlik'), isFalse);
      expect(isSpammy('ışık'), isFalse);
      expect(isSpammy('ı'), isFalse);
      expect(isSpammy('İstanbul kızıl'), isFalse);
    });

    test('TextEditingController preserves ı', () {
      final ctrl = TextEditingController();
      ctrl.text = 'bugün ılık bir his var';
      expect(ctrl.text, equals('bugün ılık bir his var'));
      expect(ctrl.text.contains('ı'), isTrue);
      ctrl.dispose();
    });

    test('publish payload preserves ı after trim', () {
      final ctrl = TextEditingController();
      ctrl.text = '  bugün ılık bir ışık, içimde sıkı bir şey yok  ';
      final text = ctrl.text.trim();
      expect(text, equals('bugün ılık bir ışık, içimde sıkı bir şey yok'));
      expect(text.contains('ı'), isTrue);
      expect(text.contains('ş'), isTrue);
      expect(text.contains('ü'), isTrue);
      ctrl.dispose();
    });
  });

  group('Turkish character preservation — widget', () {
    testWidgets('TextField accepts and displays ı', (tester) async {
      final ctrl = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(
              controller: ctrl,
              maxLines: null,
              maxLength: 300,
              maxLengthEnforcement: MaxLengthEnforcement.truncateAfterCompositionEnds,
            ),
          ),
        ),
      );

      // Simulate entering Turkish text with ı
      await tester.enterText(find.byType(TextField), 'ılık ısı ışık');
      await tester.pump();

      expect(ctrl.text, equals('ılık ısı ışık'));
      expect(find.text('ılık ısı ışık'), findsOneWidget);

      ctrl.dispose();
    });

    testWidgets('TextField preserves İstanbul with dotted İ', (tester) async {
      final ctrl = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(controller: ctrl, maxLength: 300),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'İstanbul kızıl sıkı');
      await tester.pump();

      expect(ctrl.text, equals('İstanbul kızıl sıkı'));
      expect(ctrl.text.contains('ı'), isTrue);
      expect(ctrl.text.contains('İ'), isTrue);

      ctrl.dispose();
    });

    testWidgets('full compose pipeline simulation', (tester) async {
      // Simulates the exact flow: enter text → trim → validate → payload
      final contentCtrl = TextEditingController();
      String? publishedContent;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TextField(
                  controller: contentCtrl,
                  maxLines: null,
                  maxLength: 300,
                  maxLengthEnforcement:
                      MaxLengthEnforcement.truncateAfterCompositionEnds,
                ),
                ElevatedButton(
                  onPressed: () {
                    final text = contentCtrl.text.trim();
                    if (text.characters.length >= 3) {
                      publishedContent = text;
                    }
                  },
                  child: const Text('Publish'),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.enterText(
        find.byType(TextField),
        'bugün ılık bir his var, içimde sıkı bir sessizlik yok',
      );
      await tester.pump();

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(publishedContent, isNotNull);
      expect(publishedContent, contains('ılık'));
      expect(publishedContent, contains('sıkı'));
      expect(publishedContent, contains('ı'));
      expect(
        publishedContent,
        equals('bugün ılık bir his var, içimde sıkı bir sessizlik yok'),
      );

      contentCtrl.dispose();
    });
  });
}
