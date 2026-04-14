import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guardrail: Supabase realtime streams must always specify
/// `ascending: true` (or `false`) on `.order()` calls.
///
/// WHY this test exists: `PostgrestTransformBuilder.order()` defaults to
/// ASCENDING, but `SupabaseStreamBuilder.order()` defaults to DESCENDING.
/// A bare `.order('created_at')` works differently depending on whether
/// it's a regular query or a `.stream()` chain — and that has burned us
/// multiple times (chat messages appeared at the top, mini-intros came
/// out reversed, etc.).
///
/// HOW it works: we scan every repository file for stream chains and
/// make sure any `.order(...)` that follows a `.stream(` call passes an
/// explicit `ascending:` parameter. If you introduce a new stream and
/// forget, this test fails immediately.
void main() {
  test('stream .order() calls specify ascending explicitly', () {
    final repoDir = Directory('lib/data/repositories');
    expect(repoDir.existsSync(), isTrue,
        reason: 'repositories directory missing');

    final offenders = <String>[];

    for (final entity in repoDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final src = entity.readAsStringSync();

      // Walk every `.stream(primaryKey:` occurrence and look at the next
      // `.order(` within the same chain. If that `.order(` doesn't mention
      // `ascending:`, it's using the (descending) default — bug.
      var from = 0;
      while (true) {
        final streamIdx = src.indexOf('.stream(primaryKey', from);
        if (streamIdx < 0) break;
        // A chain ends at the next semicolon.
        final chainEnd = src.indexOf(';', streamIdx);
        if (chainEnd < 0) break;
        final chain = src.substring(streamIdx, chainEnd);
        if (chain.contains('.order(') && !chain.contains('ascending:')) {
          offenders.add(
              '${entity.path}: stream chain uses .order() without ascending:');
        }
        from = chainEnd;
      }
    }

    expect(offenders, isEmpty,
        reason: 'Bare .order() on a Supabase stream defaults to DESCENDING. '
            'Pass `ascending: true` (or false) explicitly.\n\n'
            'Offenders:\n${offenders.join('\n')}');
  });
}
