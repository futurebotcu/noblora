// Widget tests — verify Smart sort subtitle rendering in BFF mode.
//
// Manual emulator smoke deferred for Dalga 14f (test seed gaps: R12 auth NULL
// tokens + R13 photo_verifications missing). These widget tests verify the
// 6-line subtitle change in lib/features/filters/filter_bottom_sheet.dart
// renders correctly under the modeProvider toggle.

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:noblara/core/enums/noble_mode.dart';
import 'package:noblara/features/filters/filter_bottom_sheet.dart';
import 'package:noblara/providers/mode_provider.dart';

class _ModeNotifierSeeded extends ModeNotifier {
  _ModeNotifierSeeded(NobleMode initial) {
    setMode(initial);
  }
}

Widget _harness({required NobleMode mode}) {
  return ProviderScope(
    overrides: [
      modeProvider.overrideWith((_) => _ModeNotifierSeeded(mode)),
    ],
    child: const MaterialApp(
      home: Scaffold(body: FilterBottomSheet()),
    ),
  );
}

Future<void> _scrollUntilFound(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    // Force isMockMode → true (skips Supabase RPCs in _fetchCount).
    dotenv.testLoad(fileInput: 'SUPABASE_URL=');
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() {
    // Tall viewport so DraggableScrollableSheet's ListView builds enough
    // children for the Languages / Interests sections to be reachable via
    // scrollUntilVisible.
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.implicitView!
      ..physicalSize = const Size(1080, 4800)
      ..devicePixelRatio = 1.0;
  });

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.implicitView!.resetPhysicalSize();
    binding.platformDispatcher.implicitView!.resetDevicePixelRatio();
  });

  // R18 — BFF-mode "Smart sort" widget tests removed entirely.
  // The Dalga-14f BFF Smart sort feature was deleted along with the BFF
  // mode; the original positive tests (`BFF mode renders Smart sort:
  // Languages`, etc.) no longer apply because `NobleMode.bff` no longer
  // exists. The companion negative test (`Dating mode does NOT render
  // Smart sort sections`) was also removed because it only existed to
  // prove the BFF-only conditional was respected on date mode.
  group('FilterBottomSheet — Dating mode renders without BFF leftovers', () {
    testWidgets('Dating mode shows the Dating badge, no Smart sort sections',
        (tester) async {
      await tester.pumpWidget(_harness(mode: NobleMode.date));
      await tester.pumpAndSettle();

      expect(find.text('Dating'), findsOneWidget);

      await _scrollUntilFound(tester, find.text('More filters'));
      await tester.tap(find.text('More filters'));
      await tester.pumpAndSettle();

      expect(find.text('Smart sort: Languages'), findsNothing);
      expect(find.text('Smart sort: Interests'), findsNothing);
      expect(find.text('Boosts matching profiles in feed order'), findsNothing);
    });
  });
}
