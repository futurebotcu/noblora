import 'package:flutter_test/flutter_test.dart';
import 'package:noblara/data/models/profile.dart';
import 'package:noblara/features/profile/profile_screen.dart';

// R3 guardrail — prompt answer/question pairs render through `isPromptVisible`.
// Short legitimate answers (one-word city/hobby/yes-no) MUST pass; spam and
// blocklist content MUST fail. Filter must NOT impose a char/word threshold —
// that lives on long-form story fields (longBio, dateBio, currentFocus) via
// `_substantive`, not on Q&A prompts.

PromptAnswer _p(String question, String answer) =>
    PromptAnswer(question: question, answer: answer);

void main() {
  group('R3 — meşru kısa cevaplar görünür', () {
    final cases = <String, String>{
      'tek kelime şehir (İstanbul)': 'İstanbul',
      'tek kelime hobi (kahve)': 'kahve',
      'tek kelime onay (evet)': 'evet',
      'tek kelime tercih (hayır)': 'hayır',
      'iki kelime kısa cevap (hiç içmem)': 'hiç içmem',
      'kısa liste cevap (spor + okuma)': 'spor + okuma',
      'orta uzunluk cevap (kahve seviyorum)': 'kahve seviyorum',
      'uzun cümle cevap': 'sabahları erken kalkmayı seviyorum',
    };
    for (final entry in cases.entries) {
      test(entry.key, () {
        expect(
          isPromptVisible(_p('Favori?', entry.value)),
          isTrue,
          reason: '"${entry.value}" R3 fix sonrası görünmeli',
        );
      });
    }
  });

  group('R3 — spam/blocklist cevaplar gizlenir', () {
    final cases = <String, String>{
      'blocklist asdf': 'asdf',
      'blocklist test': 'test',
      'blocklist na': 'na',
      'blocklist todo': 'todo',
      'tekrar aaaa': 'aaaa',
      'harfsiz 1234': '1234',
      'harfsiz nokta dizisi': '...',
      'tek karakter (a)': 'a',
      'tek karakter Türkçe (ş)': 'ş',
      'sadece boşluk': '   ',
      'tamamen boş cevap': '',
    };
    for (final entry in cases.entries) {
      test(entry.key, () {
        expect(
          isPromptVisible(_p('Favori?', entry.value)),
          isFalse,
          reason: '"${entry.value}" elenmeli (_strong filter)',
        );
      });
    }
  });

  group('R3 — soru tarafı validation', () {
    test('boş soru + geçerli cevap → kaybolur', () {
      expect(isPromptVisible(_p('', 'İstanbul')), isFalse);
    });
    test('spam soru (asdf) + geçerli cevap → kaybolur', () {
      expect(isPromptVisible(_p('asdf', 'İstanbul')), isFalse);
    });
    test('tek karakter soru + geçerli cevap → kaybolur', () {
      expect(isPromptVisible(_p('?', 'İstanbul')), isFalse);
    });
    test('geçerli soru + geçerli cevap → görünür', () {
      expect(isPromptVisible(_p('Favori şehir?', 'İstanbul')), isTrue);
    });
  });

  group('R3 — eski _substantive davranışı KIRILMIŞ olmalı', () {
    // These cases would previously fail under `_substantive(minChars:10, minWords:3)`
    // and disappear from the prompt section. R3 fix means they MUST now render.
    test('"İstanbul" (8 char, 1 word) artık gösterilir', () {
      expect(isPromptVisible(_p('Şehir?', 'İstanbul')), isTrue);
    });
    test('"kahve" (5 char, 1 word) artık gösterilir', () {
      expect(isPromptVisible(_p('İçecek?', 'kahve')), isTrue);
    });
    test('"hiç içmem" (9 char, 2 word) artık gösterilir', () {
      expect(isPromptVisible(_p('Alkol?', 'hiç içmem')), isTrue);
    });
  });
}
