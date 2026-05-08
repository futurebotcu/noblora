# TODOs

"Sonra dönerim" diyeceğin her şey buraya. Koda `// TODO` yazmak yasak.

Format:

## [YYYY-MM-DD] — Kısa başlık
**Alan:** dosya:satır ya da modül
**Neden ertelendi:** (scope creep, bloke eden başka iş, vs)
**Yapılacak:** Tek cümleyle ne gerekiyor
**Aciliyet:** high / medium / low

---

## [2026-05-08] — R14 candidate: photo_verification.dart model ↔ DB schema nullability mismatch
**Alan:** `lib/data/models/photo_verification.dart:4` (`final String photoUrl`),
`:19` (`required this.photoUrl`), `:36` (`photoUrl: json['photo_url'] as String`).
DB schema (PR-α pre-state envanter 2026-05-08): `photo_url` is_nullable=YES.
**Neden ertelendi:** PR-α scope sadece migration (DML, testfeed seed fix).
Model tarafında düzeltme ayrı bir PR + sözleşme değişikliği — production
sign-up flow ve mevcut row'lar için davranış kontrolü gerek.
**Yapılacak:** İki seçenek:
(a) Model `photoUrl` nullable yap: `final String? photoUrl;` +
`fromJson` `as String?` cast + `latest.photoUrl` kullanan UI yerlerinde
null check ekle. Daha esnek, schema gerçeğini yansıtır.
(b) DB'de `photo_url` NOT NULL constraint ekle (Edge Function
`verify-both-photos`'un her zaman doldurduğu doğrulanmalı; mevcut NULL
satırlar varsa migration ile coalesce). Model değişmez, daha sıkı
sözleşme.
PR-α'da workaround: `'placeholder://testfeed-seed'` insert. Kalıcı
değil — gelecek seed/manuel insert NULL bırakırsa client crash riski
sürer. R12 whack-a-mole pattern'inin model↔DB varyantı.
**Aciliyet:** medium (PR-α placeholder'ı taşıyor; üretim sign-up flow
zaten doğru dolduruyor; sadece manuel/seed yollarda risk)

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
