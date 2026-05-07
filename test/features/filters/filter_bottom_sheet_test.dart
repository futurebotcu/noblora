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

  group('FilterBottomSheet — Smart sort subtitle (Dalga 14f)', () {
    testWidgets('BFF mode header shows BFF badge (modeProvider override sanity)',
        (tester) async {
      await tester.pumpWidget(_harness(mode: NobleMode.bff));
      await tester.pumpAndSettle();

      expect(find.text('BFF'), findsOneWidget,
          reason: 'modeProvider override must propagate to header chip');
    });

    testWidgets('BFF mode renders "Smart sort: Languages" label', (tester) async {
      await tester.pumpWidget(_harness(mode: NobleMode.bff));
      await tester.pumpAndSettle();

      await _scrollUntilFound(tester, find.text('Smart sort: Languages'));
      expect(find.text('Smart sort: Languages'), findsOneWidget);
    });

    testWidgets('BFF mode renders Languages subtitle copy', (tester) async {
      await tester.pumpWidget(_harness(mode: NobleMode.bff));
      await tester.pumpAndSettle();

      await _scrollUntilFound(
          tester, find.text('Boosts matching profiles in feed order'));
      expect(
        find.text('Boosts matching profiles in feed order'),
        findsAtLeastNWidgets(1),
        reason: 'Languages section subtitle must render in BFF mode',
      );
    });

    testWidgets('BFF mode + advanced expanded renders "Smart sort: Interests" label',
        (tester) async {
      await tester.pumpWidget(_harness(mode: NobleMode.bff));
      await tester.pumpAndSettle();

      await _scrollUntilFound(tester, find.text('More filters'));
      await tester.tap(find.text('More filters'));
      await tester.pumpAndSettle();

      await _scrollUntilFound(tester, find.text('Smart sort: Interests'));
      expect(find.text('Smart sort: Interests'), findsOneWidget);
    });

    testWidgets('BFF mode + advanced expanded renders subtitle under both Languages and Interests',
        (tester) async {
      await tester.pumpWidget(_harness(mode: NobleMode.bff));
      await tester.pumpAndSettle();

      await _scrollUntilFound(tester, find.text('More filters'));
      await tester.tap(find.text('More filters'));
      await tester.pumpAndSettle();

      // Force the Interests section into the build by scrolling to it; the
      // Languages section above is already built from the initial pump.
      await _scrollUntilFound(tester, find.text('Smart sort: Interests'));

      // Identical subtitle copy is reused under both Languages and Interests.
      expect(
        find.text('Boosts matching profiles in feed order'),
        findsNWidgets(2),
        reason:
            'Subtitle must render under both Languages and Interests in BFF + advanced',
      );
    });

    testWidgets('Dating mode does NOT render Smart sort sections (BFF-only)',
        (tester) async {
      await tester.pumpWidget(_harness(mode: NobleMode.date));
      await tester.pumpAndSettle();

      // Expand advanced too — to cover the Interests slot which is also gated
      // behind `if (mode == NobleMode.bff)`.
      await _scrollUntilFound(tester, find.text('More filters'));
      await tester.tap(find.text('More filters'));
      await tester.pumpAndSettle();

      expect(find.text('Smart sort: Languages'), findsNothing);
      expect(find.text('Smart sort: Interests'), findsNothing);
      expect(find.text('Boosts matching profiles in feed order'), findsNothing);
    });
  });
}
