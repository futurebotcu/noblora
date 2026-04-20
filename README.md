# Noblara

Flutter ile yazılmış elite sosyal/dating platformu. Üç ana mod: **Dating**,
**BFF**, ve **Noblara Feed** (Nob paylaşımı + sosyal etkileşim).

> Durum etiketleri — ✅ gerçek + doğrulanmış, 🟡 kısmi / unverified,
> ⏳ beklemede, ❌ placeholder, 🔒 locked. Kaynak: `FEATURE_REGISTRY.md`,
> `pubspec.yaml`, `lib/features/`.

---

## Stack (pubspec.yaml'dan birebir)

| Paket | Versiyon | Amaç |
|---|---|---|
| Flutter / Dart | 3.35.4 / 3.9.2 | Framework |
| `flutter_riverpod` | 2.6.1 | State |
| `supabase_flutter` | 2.9.0 | Auth + DB + realtime + storage |
| `firebase_core` / `firebase_messaging` | 3.13 / 15.2 | Push entegrasyonu (yalnızca client) |
| `flutter_local_notifications` | 18.0.1 | Local notif |
| `google_fonts` | 6.2.1 | Playfair Display + Inter |
| `cached_network_image` | 3.4.1 | Image cache |
| `image_picker` | 1.1.2 | Photo seçim |
| `video_thumbnail` | 0.5.3 | Video önizleme |
| `geolocator` / `geocoding` | 13.0.2 / 3.0.0 | Konum |
| `flutter_dotenv` | 5.2.1 | `.env` |

**Eksik olduğu doğrulanan:** `flutter_webrtc` yok → video call için gerçek
peer-to-peer altyapı kurulmamış (R6).

---

## Çalışan Özellikler

### Auth & Onboarding
- ✅ Email/şifre + Supabase auth
- ✅ Onboarding flow (mode seçim, gender, profil temelleri)
- ✅ Splash → Auth → Onboarding → Entry Gate gating

### Feed / Dating
- ✅ Swipe feed (right/left)
- ✅ Swipe limiti, connection limiti (RPC: `check_swipe_limit`, `check_connection_limit`)
- ✅ Signal (super-like) + Rewind
- ✅ Match found ekranı → MiniIntro flow
- ✅ Filtreler: age range, Trust Shield, Status Badge, strict mode, presetler, SharedPreferences persistence
- 🟡 Max distance filtresi (PostGIS gerekiyor — FEATURE_REGISTRY.md'de UI_ONLY)
- 🟡 Six+ Photos filtresi (photo count profilde yok — UI_ONLY)
- ✅ Oracle counter (`count_filtered_profiles` RPC)

### BFF
- ✅ AI suggestions (`generate_bff_suggestions` RPC)
- ✅ Connect / Pass (`process_bff_action` RPC)
- ✅ Reach Out (gönderme + alma)
- ✅ BFF Plan oluşturma
- 🟡 Plan görüntüleme (fetchPlans mevcut, liste ekranı yok)

### Chat & Match Flow
- ✅ Individual Chat — gerçek zamanlı (Supabase channel, `typing` presence, `messages` realtime)
- ✅ End-connection flow
- ✅ Post-call decision
- ✅ Real meeting screen + check-in

### Video Call
- 🟡 UI akışı çalışıyor (video_scheduling, video_call, post_call_decision ekranları)
- ❌ **Gerçek video bağlantı altyapısı YOK** (WebRTC / signaling kurulmamış, `flutter_webrtc` pubspec'te yok). UI mock sinyali ile ilerliyor. R6.

### Noblara Feed (Nob paylaşımı)
- ✅ Nob compose (text + media)
- ✅ Nob detail + comments + reactions
- ✅ Mood map
- ✅ My Nobs
- ✅ Notifications ekranı

### Social / Events
- ✅ Event feed, create, join, detail
- ✅ Event chat (realtime)
- ✅ Gold/Blue flag (`flag_message_gold`, `flag_message_blue` RPC)
- ✅ Attendance states
- ✅ Event check-in → trust_score
- 🟡 Event Leave (provider method var, UI butonu yok)

### Profile
- ✅ Profile görüntüleme (73 alan modellenmiş)
- ✅ Edit profile main + sections (photos, core info, lifestyle, prompts)
- 🟡 Profile kayıt roundtrip — 67/73 alan `toJson`'da serialize edilmiyor, 36/73 alan `copyWith`'te düşüyor (R1/R2). `test/guardrails/profile_roundtrip_guardrail_test.dart` bu eksikleri yeşile döndürene kadar fix eksik.

### Tier / Maturity / Trust
- ✅ NobTier (observer / explorer / noble)
- ✅ Maturity score (auth trigger RPC)
- ✅ Profile strength
- ✅ Tier promotion ekranı
- 🟡 Trust score — modelde var, feed sorgularında aktif kullanılmıyor

### Push Notifications
- 🟡 Firebase Messaging client kurulu, local notifications çalışıyor
- 🟡 E2E backend push (server → device) **doğrulanmadı** bu oturumda

### Settings
- ✅ Mode toggles (6 mod)
- ✅ Pause account (feed repository filtreliyor)
- 🟡 Incognito, Calm mode, Show city only, Hide exact distance, Show last active, Show status badge, Message preview → DB'ye yazılıyor ama feed query'leri okumuyor (FEATURE_REGISTRY UI_ONLY)
- 🟡 Notification prefs (yazılıyor, push sistemi uçtan uca doğrulanmadı)
- ❌ Delete account (yalnızca sign out; gerçek silme yok)

### Admin
- ✅ Admin ekranı (users, reports, metrics sekmeleri) — Supabase client doğrudan kullanılıyor (mimari borç: `current_violations.md` §3)

### Locked
- 🔒 QR check-in
- 🔒 Geofence verification
- 🔒 Real-world forced validation

---

## Mimari (lib/ özeti)

```
lib/
├── main.dart              # dotenv + Supabase init + ProviderScope
├── app.dart               # MaterialApp + AppTheme.dark
├── core/
│   ├── services/          # device_service (⚠ doğrudan Supabase)
│   ├── theme/             # AppColors, AppTheme, AppSpacing
│   └── utils/             # mock_mode.dart
├── data/
│   ├── models/            # Profile, Post, Match, Notification, PromptAnswer (+ ~15 daha)
│   └── repositories/      # 15+ repo — mimari hedef tek veri erişim katmanı
├── providers/             # Riverpod — çoğu repository'ye delege ediyor,
│                          #           bir kısmı hâlâ doğrudan Supabase
├── services/              # gemini_service, push_notification_service
├── navigation/            # AppRouter, MainTabNavigator
├── features/              # 15 feature klasörü (auth, onboarding, feed,
│                          #           matches, bff, social, profile,
│                          #           noblara_feed, admin, settings, ...)
└── shared/widgets/        # Butonlar, text field, skeleton, avatar_picker
```

**Mimari borç:** `current_violations.md`'de detaylı — 121 çağrı `Supabase.instance.client` 46 dosyada dış alanda yaşıyor, repository mimariyi tam delmiş durumda.

---

## Yerel Geliştirme

```bash
# Bağımlılıklar
flutter pub get

# .env dosyanı ayarla (boşsa mock mode devreye girer)
cp .env.example .env

# Web (mock mode uygun, Supabase gerekmez)
flutter run -d chrome --web-port 8082

# Android (emülatör ya da bağlı cihaz)
flutter run

# Testler
flutter test                               # tüm testler
flutter test test/guardrails/              # yalnızca guardrail'lar
```

### Mock Mode

`.env` içinde placeholder değerler (`<your-supabase-url>`) varsa uygulama
tamamen offline çalışır — mock kullanıcı + 5 örnek feed kartı.

---

## Test Altyapısı

- `test/guardrails/no_banned_patterns_test.dart` — `catch (_)`, `// ignore: unused_*`, TODO/FIXME/HACK/XXX, dış alanda `Supabase.instance.client` yasakları (CLAUDE.md §4).
- `test/guardrails/profile_parse_guardrail_test.dart` — Profile fromJson field coverage.
- `test/guardrails/profile_roundtrip_guardrail_test.dart` — toJson ↔ fromJson roundtrip + copyWith preservation (73 alan).
- `test/guardrails/stream_order_guardrail_test.dart` — stream/ordering.
- Özellik testleri: `post_masking_test`, `posts_optimistic_react_test`, `nob_compose_turkish_test`, `video_assets_test`, `widget_test`.

CI: `.github/workflows/validate.yml` her push/PR'da `analyze --fatal-infos` + `test` + `build apk --debug`.

**Mevcut CI durumu (ilk kurulum):**
- Banned patterns: ❌ FAIL (171 ihlal — ayrıntı: `.claude/current_violations.md`)
- Profile roundtrip: ❌ FAIL (103 alan kayıp / 146 subtest)
- Diğer testler: yeşil (son `flutter test` çıktısına göre, bu oturumda tam suite çalıştırılmadı — **unverified**)

---

## Bilinen Kısıtlar (Dürüst Liste)

1. **Video call WebRTC yok** — UI akışı çalışıyor, gerçek bağlantı kurulmuyor. Feature'ı "canlı video görüşme" olarak pazarlamak yanlış olur. Hedef: `flutter_webrtc` + signaling (Supabase realtime ya da dedicated) eklenene kadar 🟡.
2. **Profile model roundtrip kırık** — 67 alan toJson'da serialize edilmiyor. Edit Profile üzerinden kaydedilen rich alanlar (promptlar dahil) sessizce kayboluyor riski var. R1/R2 buradan.
3. **Mimari kaçak** — 121 doğrudan Supabase çağrısı UI/provider katmanında yaşıyor. Repository mimarisi tam anlamıyla devreye alınmadı.
4. **Settings toggle'ları yazıp okumuyor** — Incognito, Calm mode, Show city only, vs. DB'ye yazılıyor ama feed query'leri okumuyor. Kullanıcıya "ayar uygulandı" illüzyonu veriyor.
5. **Delete account sadece sign out** — Gerçek data silme yok.
6. **Push E2E doğrulanmadı** — Client kurulu ama server → device yolculuğu bu oturumda doğrulanmadı.
7. **P0 security migration uygulandı ama etkisiz** — Migration 20260408140730 olarak canlıda UYGULANDI (bu sabahki audit oturumunda `list_migrations` ile doğrulandı). Ancak eski permissive `*_system WITH CHECK (true)` policy'leri DROP edilmediği için advisor hâlâ kırmızı gösteriyor (R5 — "bypass-disguised-as-fix"). Sıradaki RLS hardening migration'ı bu boşluğu kapatacak.
8. **Dual-branch repo** — `main` ve `master` paralel duruyor. Chat/profile koduna dokunmadan önce aktif branch'i teyit et.

---

## İlgili Dosyalar (Proje Yönetimi)

- [`CLAUDE.md`](CLAUDE.md) — Proje anayasası (altın kural, protokoller, yasak kalıplar).
- [`FEATURE_REGISTRY.md`](FEATURE_REGISTRY.md) — Feature durumları (2026-04-01 itibarıyla).
- [`.claude/known_regressions.md`](.claude/known_regressions.md) — R1–R7 tekrarlayan hatalar.
- [`.claude/current_violations.md`](.claude/current_violations.md) — Bugünkü ihlal envanteri.
- [`.claude/done_log.md`](.claude/done_log.md) — Tamamlanan işlerin kanıt checklist'i.
- [`.claude/todos.md`](.claude/todos.md) — Kodda `// TODO` yerine kullanılacak defter.
- [`.claude/session_notes.md`](.claude/session_notes.md) — Oturum kayıtları.
