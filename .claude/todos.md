# TODOs

"Sonra dönerim" diyeceğin her şey buraya. Koda `// TODO` yazmak yasak.

Format:

## [YYYY-MM-DD] — Kısa başlık
**Alan:** dosya:satır ya da modül
**Neden ertelendi:** (scope creep, bloke eden başka iş, vs)
**Yapılacak:** Tek cümleyle ne gerekiyor
**Aciliyet:** high / medium / low

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
