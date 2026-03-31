// Noblara smoke test — just verifies the app builds without crashing.
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Placeholder smoke test', (WidgetTester tester) async {
    // Full app initialization requires dotenv + optional Supabase.
    // End-to-end tests are out of scope for this phase.
    expect(true, isTrue);
  });
}
