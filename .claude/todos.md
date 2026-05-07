# TODOs

"Sonra dönerim" diyeceğin her şey buraya. Koda `// TODO` yazmak yasak.

Format:

## [YYYY-MM-DD] — Kısa başlık
**Alan:** dosya:satır ya da modül
**Neden ertelendi:** (scope creep, bloke eden başka iş, vs)
**Yapılacak:** Tek cümleyle ne gerekiyor
**Aciliyet:** high / medium / low

---

## [2026-05-07] — BFF Feed Filter Dead-Path (R11 — PR-B'de known_regressions'a yazılacak)
**Alan:** `lib/data/repositories/bff_suggestion_repository.dart:127-133` `generate_bff_suggestions` RPC + BFF filter UI flow
**Neden ertelendi:** Dalga 14f kapsamı: dürüstlük + UI rebrand + dead code cleanup. BFF feed RPC imza değişikliği = ayrı sprint (CLAUDE.md §6 protokolü gerek: migration, advisor before/after, smoke). Yaklaşım B kapsamında.
**Yapılacak:** İki seçenek:
  (a) `generate_bff_suggestions(p_user_id, p_filters jsonb)` imzasına filter parametresi ekle, RPC body içinde candidate WHERE clause genişlet.
  (b) BFF mode'da filter butonunu disable et + kullanıcıya "Filters not yet supported in BFF mode" tooltip.
Kararı PR-A merge sonrası tartışacağız.
**Aciliyet:** medium (kullanıcı bugün BFF mode'da filter seçiyor, etkisi yok — UI yalanı)

---

## [2026-04-21] — Viewer-context feature (match / stranger)
**Alan:** `lib/features/profile/profile_screen.dart` — `_ViewerContext` enum
**Neden ertelendi:** Dalga 1 hijyen scope'unda değil. Enum değerleri yarım
(UI'a bağlanmamış, `match` karşılaştırması hep false, `stranger` hiç
kullanılmıyor). `// ignore: unused_field` ile maskelenmiş yarım iş.
**Yapılacak:** Viewed-profile variant ekrana gerçekten eklendiğinde:
`_ViewerContext` enum'una `match` + `stranger` değerleri geri eklenir;
`_CuratedProfile._canSee` içindeki `isMatch: false` hardcode'u
`viewerContext == _ViewerContext.match` olarak revert edilir; viewed-profile
entry point (muhtemelen `user_profile_screen.dart`) `_CuratedProfile`'e
`match` ya da `stranger` pass eder.
**Aciliyet:** low (feature henüz yok, roadmap)

---
