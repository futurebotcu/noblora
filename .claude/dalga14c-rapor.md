# Dalga 14c — Sprint Sonuç Raporu

**Tarih:** 2026-05-05
**Branch:** `dalga-14c-secrets-rotate`
**Sonuç:** Scope değişti — kod değişikliği yok, dokümantasyon-only PR

---

## Sprint Niyeti (Başlangıç)

Audit raporu (5 Mayıs) §11 P0-3 maddesi: ".env + local.properties live anahtarlar git history'de leaked. Rotate gerekli."

İlk plan: BFG / filter-branch ile history temizleme + Supabase ANON KEY + Google Places KEY rotate + force-push.

## Kanıt-Dayalı Doğrulama (R7 + R10 Disiplini)

| Kanıt | Sonuç |
|---|---|
| `git log --all --oneline -- .env` | **boş çıktı** — hiçbir commit'te yok |
| `git log --all --oneline -- android/local.properties` | **boş çıktı** |
| `git ls-files .env android/local.properties` | **boş** (tracked değil) |
| `.gitignore:2` | `.env` ignore'da ✅ |
| `android/.gitignore:6` | `/local.properties` ignore'da ✅ |

**SONUÇ:** Audit iddiası **YANLIŞ**. Git history'de leak yok. Filter-branch / BFG / force-push **gereksiz** (ve tehlikeli olurdu).

## Gerçek Risk (Audit'in Atladığı)

`pubspec.yaml:41` `- .env` asset olarak dahil → **APK içinde bundled**.

| Kanıt | Sonuç |
|---|---|
| `unzip -l app-release.apk \| grep .env` | `339 byte assets/flutter_assets/.env` (disk'tekiyle aynı boyut) |
| `unzip -p app-release.apk assets/flutter_assets/.env` (sed redacted) | 3 satır: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GOOGLE_PLACES_KEY` |
| `aapt dump xmltree app-release.apk AndroidManifest.xml \| grep geo.API_KEY` | `<meta-data android:name="com.google.android.geo.API_KEY" android:value="AIzaSy...">` plaintext |

**İki leak yolu APK içinde:**
1. `assets/flutter_assets/.env` (Flutter asset bundle)
2. `AndroidManifest meta-data` (build.gradle manifestPlaceholders)

Şu an Play Store'a çıkılmadığı için aktif compromise yok, ama future dağıtım için risk.

## Yapılan İş (Bu Sprint)

- [x] Git history kanıtsızlık doğrulaması (yukarıda)
- [x] APK content kanıtlama (unzip + aapt)
- [x] `.claude/known_regressions.md` "Audit Raporu Yanılgıları" bölümü eklendi (3 yanılgı: A1 git history, A2 RECORD_AUDIO gerekçesi, A3 INTERNET kaçırma)
- [x] Bu rapor dosyası
- [x] R7 disiplin yakalaması: log'da kazara plaintext key exposure (aapt çıktısı sed ile redact edilmedi) — kullanıcının zaten rotate planı kapsıyor, ek aciliyet yarattı

## Yapılacak (Sprint Dışı, Kullanıcı Manuel)

- [ ] **Google Cloud Console**: Places API key rotate
  - Yeni key üret
  - **Application restrictions** ekle:
    - Type: Android apps
    - Package name: `com.noblara.noblara_flutter`
    - SHA-1: `57:86:6A:F1:91:49:0C:42:1D:9F:34:76:28:E4:FE:5F:D3:7C:9F:65` (Dalga 14a upload keystore)
  - **API restrictions** ekle: Sadece "Places API" + "Maps SDK for Android" çağrılabilsin
  - Eski key'i revoke
  - Yeni key'i `.env` ve `android/local.properties`'e elle yaz (git'e gitmez)
  - `flutter run` smoke (yeni key çalışıyor mu)

## Sprint Dışı (Ayrı PR — Dalga 14c2)

APK bundled .env temizliği — production-grade secret management:

1. `pubspec.yaml`'dan `- .env` asset'i kaldır
2. Build script: `flutter build apk --release --dart-define=SUPABASE_URL=$SUPABASE_URL --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY --dart-define=GOOGLE_PLACES_KEY=$GOOGLE_PLACES_KEY`
3. `lib/main.dart`: `String.fromEnvironment('SUPABASE_URL', defaultValue: '')`
4. `dotenv` paketini opsiyonel/dev-only yap
5. CI/CD secret store entegrasyonu (GitHub Actions, fastlane match)
6. Tahmini scope: 5+ dosya, CLAUDE.md §5 "max 4 dosya" kuralı için ayrı sprint

**Dalga 14c2 için P1 önceliği** (P0 değil — Play Store öncesi tamamlansın yeterli).

## Sıradaki Sprint Önerisi

- **14d**: Forgot password handler (`sign_in_screen.dart:107-109` boş onTap → Supabase auth.resetPasswordForEmail)
- **14e**: Privacy policy URL (canlı noblara.com/privacy yayını + in-app link)
- **14f**: Filter UI dürüstlük (Trust Shield + Languages + Interests + Strict + Presets ya implement ya kaldır)
- **14g**: Video Call etiketleme (R6 — UI'a "🟡 Beta" / "Coming soon" ekle)
- **14h**: L10n iskelet (flutter_localizations + app_tr.arb / app_en.arb)
- **14c2** (sonra): APK bundled .env temizliği (--dart-define injection)

## Disiplin Kazanımları

- **R7 yakalaması**: Audit iddiası kanıtsız doğrulanınca yanlış çıktı. Kanıt-dayalı sorgulama saatler kayıptan + tehlikeli force-push'tan kurtardı.
- **R10 paralelliği**: "apply success ≠ effective fix" → "audit claim ≠ git/runtime reality"
- **Yeni kural** (`.claude/known_regressions.md`'e eklendi): Audit iddialarını her sprint'te bağımsız doğrula, körlemesine uygulama yapma.
