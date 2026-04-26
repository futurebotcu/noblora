import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guardrail: `lib/` altında CLAUDE.md §4'te listelenen yasak kalıplar
/// bulunamaz.
///
/// Bu test CI'da her push/PR'da çalışır. Bir ihlal bulunduğunda test
/// kırmızı olur ve ihlal edilen dosya:satır listesiyle fail eder.
///
/// Yasak kalıplar:
/// - `catch (_)` — sessiz fail (R4)
/// - `// ignore: unused_*` — dead code / yarım iş
/// - `// TODO` / `// FIXME` / `// HACK` / `// XXX` — koda çöp
/// - `Supabase.instance.client` (screen/widget içinde) — yalnızca
///   `lib/data/repositories/` altında VEYA tek noktadan client wrapper
///   olan `lib/providers/supabase_client_provider.dart` içinde olabilir.
///   Wrapper, repository pattern'in giriş noktası — tüm client erişimi
///   buradan provider injection ile geçer (Dalga 5a, 2026-04-27).
void main() {
  final libDir = Directory('lib');

  final dartFiles = <File>[];
  if (libDir.existsSync()) {
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        dartFiles.add(entity);
      }
    }
  }

  group('no banned patterns (CLAUDE.md §4)', () {
    test('lib/ contains no `catch (_)`', () {
      final pattern = RegExp(r'catch\s*\(\s*_\s*\)');
      final violations = _scan(dartFiles, pattern);
      expect(
        violations,
        isEmpty,
        reason: _format('catch (_)', violations),
      );
    });

    test('lib/ contains no `// ignore: unused_*`', () {
      final pattern = RegExp(r'//\s*ignore:\s*unused_');
      final violations = _scan(dartFiles, pattern);
      expect(
        violations,
        isEmpty,
        reason: _format('// ignore: unused_*', violations),
      );
    });

    test('lib/ contains no TODO/FIXME/HACK/XXX comments', () {
      final pattern = RegExp(r'//\s*(TODO|FIXME|HACK|XXX)\b');
      final violations = _scan(
        dartFiles,
        pattern,
        skipSelf: true,
      );
      expect(
        violations,
        isEmpty,
        reason: _format('// TODO/FIXME/HACK/XXX', violations),
      );
    });

    test(
      'Supabase.instance.client only under lib/data/repositories/',
      () {
        final pattern = RegExp(r'Supabase\.instance\.client');
        final scoped = dartFiles.where((f) {
          final p = f.path.replaceAll(r'\', '/');
          if (p.contains('/data/repositories/')) return false;
          // Wrapper provider — tek noktadan client erişimi (Dalga 5a).
          if (p.endsWith('lib/providers/supabase_client_provider.dart')) {
            return false;
          }
          return true;
        }).toList();
        final violations = _scan(scoped, pattern);
        expect(
          violations,
          isEmpty,
          reason: _format(
            'Supabase.instance.client (outside lib/data/repositories/)',
            violations,
          ),
        );
      },
    );
  });
}

class _Hit {
  _Hit(this.file, this.line, this.text);
  final String file;
  final int line;
  final String text;

  @override
  String toString() => '$file:$line  $text';
}

List<_Hit> _scan(
  List<File> files,
  RegExp pattern, {
  bool skipSelf = false,
}) {
  final hits = <_Hit>[];
  for (final file in files) {
    final path = file.path.replaceAll(r'\', '/');
    if (skipSelf && path.endsWith('no_banned_patterns_test.dart')) continue;
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (pattern.hasMatch(line)) {
        hits.add(_Hit(path, i + 1, line.trim()));
      }
    }
  }
  return hits;
}

String _format(String name, List<_Hit> hits) {
  if (hits.isEmpty) return '$name: 0 violations';
  final buf = StringBuffer()
    ..writeln('$name: ${hits.length} violations')
    ..writeln('(first 20 shown)');
  for (final h in hits.take(20)) {
    buf.writeln('  $h');
  }
  return buf.toString();
}
