# Current Violations — Envanter

**Oluşturma tarihi:** 2026-04-20
**Amaç:** Şu anki kodda CLAUDE.md §4 yasaklarına aykırı kullanımları
GÖRÜNÜR kılmak. Düzeltme listesi değil, harita.
**Kaynak:** `flutter test test/guardrails/no_banned_patterns_test.dart`
+ `Grep` doğrulama.

---

## Özet

| Kategori | Sayı |
|---|---|
| `catch (_)` kullanımı | **48** dosya:satır |
| `// ignore:` kullanımı | **3** dosya:satır |
| Dış alanda `Supabase.instance.client` | **121** çağrı / **46** dosya |
| 500+ satır Dart dosyası | **25** dosya |

Toplam 172 ihlal + 25 devasa dosya. Düzeltme sırası bu envantere göre
planlanır.

---

## 1) `catch (_)` Kullanımları (48 hit)

Data katmanı (sessiz fail zaten burada da yasak — §4):
- `lib/data/models/post.dart:231`
- `lib/data/repositories/comment_repository.dart:148`
- `lib/data/repositories/echo_repository.dart:51,73,88`
- `lib/data/repositories/feed_repository.dart:49` *(R4 — distance filter'ın olay mahalli)*
- `lib/data/repositories/messages_repository.dart:247`
- `lib/data/repositories/post_repository.dart:66,103,117,161`
- `lib/data/repositories/swipe_repository.dart:66,81`

Provider katmanı:
- `lib/providers/auth_provider.dart:164,207`
- `lib/providers/comment_provider.dart:64`
- `lib/providers/feed_provider.dart:135`
- `lib/providers/interaction_gate_provider.dart:68`
- `lib/providers/notification_provider.dart:84`
- `lib/providers/posts_provider.dart:105,666`

Servis katmanı:
- `lib/services/gemini_service.dart:35`
- `lib/services/push_notification_service.dart:59`

Feature/UI katmanı:
- `lib/features/entry_gate/entry_gate_screen.dart:52`
- `lib/features/match/match_detail_screen.dart:131,182`
- `lib/features/match/mini_intro_screen.dart:59`
- `lib/features/match/video_call_screen.dart:153`
- `lib/features/matches/end_connection_screen.dart:72`
- `lib/features/matches/individual_chat_screen.dart:316,345,375,426,463`
- `lib/features/matches/matches_screen.dart:38,1029,1043`
- `lib/features/noblara_feed/nob_compose_screen.dart:389,407,417`
- `lib/features/noblara_feed/notifications_screen.dart:66,97`
- `lib/features/onboarding/onboarding_flow_screen.dart:656`
- `lib/features/profile/edit/sections/photos_media_section.dart:151`
- `lib/features/settings/settings_screen.dart:46`
- `lib/features/social/create_room_screen.dart:80`
- `lib/features/status/status_screen.dart:85,95`

**Düzeltme modeli:** `catch (_)` → `catch (e, st)` + debug log + (UI'a sinyal
verilecekse) snackbar/banner. Yorumla "non-critical" demek dokunulmazlık
tanımaz — yine `catch (e, st)` ile yazılmalı, log bırakılmalı.

---

## 2) `// ignore:` Kullanımları (3 hit)

| Dosya:Satır | Tür | Neden var (tahmin) |
|---|---|---|
| `lib/features/admin/admin_screen.dart:575` | `use_build_context_synchronously` | Admin ekranında async sonrası BuildContext kullanımı. `mounted` kontrolü ya da context'i yerel yakalama ile kaldırılabilir. |
| `lib/features/profile/profile_screen.dart:46` | `unused_field` | Yarım kalmış bir alan. Kullan ya da sil. |
| `lib/features/profile/profile_screen.dart:48` | `unused_field` | Yarım kalmış bir alan. Kullan ya da sil. |

**Düzeltme modeli:** Her ignore için ya kullan, ya sil. Orta yol yok.

---

## 3) Dış Alanda `Supabase.instance.client` (121 çağrı / 46 dosya)

Mimari kural: veri erişimi yalnızca `lib/data/repositories/` altında.
İhlal edenler aşağıda, yoğunluğa göre sıralı.

### En yoğun 10 dosya (toplam 71 çağrı — ihlallerin %59'u)

| Dosya | Çağrı | Hedef repository |
|---|---:|---|
| `lib/providers/posts_provider.dart` | 10 | `post_repository.dart` (mevcut) |
| `lib/features/settings/settings_screen.dart` | 9 | yeni `settings_repository.dart` gerek |
| `lib/features/admin/admin_screen.dart` | 8 | yeni `admin_repository.dart` gerek |
| `lib/features/matches/individual_chat_screen.dart` | 7 | `messages_repository.dart` (mevcut, genişlet) |
| `lib/features/noblara_feed/nob_compose_screen.dart` | 5 | `post_repository.dart` |
| `lib/providers/feed_provider.dart` | 5 | `feed_repository.dart` |
| `lib/core/services/device_service.dart` | 4 | yeni `device_repository.dart` gerek |
| `lib/services/push_notification_service.dart` | 4 | yeni `push_repository.dart` gerek |
| `lib/features/noblara_feed/mood_map_screen.dart` | 4 | yeni `mood_map_repository.dart` gerek |
| `lib/features/profile/edit/sections/photos_media_section.dart` | 4 | `profile_repository.dart` + storage helper |

### Kalan 36 dosya (50 çağrı)

Provider'lar: `active_modes_provider, appearance_provider, auth_provider, bff_provider, check_in_provider, comment_provider, event_provider, gating_provider, interaction_gate_provider, match_provider, messages_provider, mini_intro_provider, note_provider, notification_provider, profile_provider, real_meeting_provider, room_provider, status_provider, verification_provider, video_provider`

Feature'lar: `entry_gate_screen, match_detail_screen, post_call_decision_screen, my_nobs_screen, matches_screen, end_connection_screen, notifications_screen, status_screen, event_chat_screen, edit_event_screen, edit_room_screen, edit_profile_provider`

Navigasyon + shared: `main_tab_navigator, city_search_screen`

Servis: `gemini_service`, `onboarding_flow_screen`

**Düzeltme modeli:** Yeni repository sınıfları aç (`settings_repository`,
`admin_repository`, `device_repository`, `push_repository`), mevcut
repository'leri genişlet (posts, feed, messages, profile), provider/screen
koduna `ref.read(XRepositoryProvider)` ile enjekte et. Sıra: en yoğun 10
dosyadan başla.

---

## 4) 500+ Satır Dart Dosyaları (25 adet)

| Dosya | Satır | Önerilen split planı |
|---|---:|---|
| `lib/features/noblara_feed/mood_map_screen.dart` | 1868 | Widget ağacı, state yönetimi ve renderer'ı ayrı dosyalara böl (map_controller, map_markers_widget, mood_filter_sheet). |
| `lib/features/matches/individual_chat_screen.dart` | 1740 | Chat header, message list, composer bar ve reactions'ı ayrı widget'lara çıkar. `Supabase.instance.client` çağrılarını aynı anda repository'ye taşı. |
| `lib/features/profile/profile_screen.dart` | 1677 | R3 riskli alan. Header, photo gallery, prompts, scores, actions ayrı widget'lara bölünmeli. |
| `lib/features/matches/matches_screen.dart` | 1570 | Dating matches tab, BFF matches tab ve shared chrome ayrılabilir. |
| `lib/features/noblara_feed/noblara_feed_screen.dart` | 1481 | Feed list, story bar, FAB composer, filters ayrılmalı. |
| `lib/features/noblara_feed/nob_detail_screen.dart` | 1405 | Detail header, comments section, composer ayrılmalı. |
| `lib/shared/widgets/avatar_picker.dart` | 1219 | Picker flow, crop UI, upload pipeline ayrılabilir. |
| `lib/features/match/video_scheduling_screen.dart` | 1211 | Takvim, gündem, confirmation alt bölümleri ayrı. (Ayrıca R6 riski — WebRTC yok.) |
| `lib/features/noblara_feed/nob_compose_screen.dart` | 1193 | Compose form, media attach, preview ayrı. |
| `lib/features/onboarding/onboarding_flow_screen.dart` | 973 | Her step ayrı dosyaya. `OnboardingStep` abstract + subclasses. |
| `lib/features/settings/settings_screen.dart` | 948 | Privacy, notifications, account sections ayrı. Repository ekle. |
| `lib/features/feed/swipe_card_widget.dart` | 900 | Card content vs swipe gesture ayrı. |
| `lib/features/match/real_meeting_screen.dart` | 758 | Check-in flow, venue picker, share sheet ayrılabilir. |
| `lib/providers/posts_provider.dart` | 682 | Feed provider, compose provider, single-post provider'a split. Supabase kullanımları repository'ye. |
| `lib/features/admin/admin_screen.dart` | 678 | Her admin sekmesi (users, reports, metrics) kendi widget'ına. |
| `lib/features/settings/help_center_screen.dart` | 672 | FAQ data'yı json/const'a çıkar; screen sadece render. |
| `lib/features/profile/edit/edit_profile_main_screen.dart` | 663 | Zaten section'lar var; orchestration kısmını provider'a al, view saf kalsın. |
| `lib/features/bff/bff_screen.dart` | 638 | Tab bar + matches + directory ayrılabilir. |
| `lib/features/bff/bff_plan_screen.dart` | 629 | Plan steps ayrı widget'lara. |
| `lib/features/social/room_chat_screen.dart` | 618 | Chat UI tekrar — individual_chat ile shared widget'lar oluşturulabilir. |
| `lib/features/feed/feed_screen.dart` | 596 | Filter sheet + card stack + empty state ayrı. |
| `lib/features/noblara_feed/user_profile_screen.dart` | 587 | Profile preview ile profile_screen arasında widget share. |
| `lib/features/profile/edit/profile_draft.dart` | 539 | Draft state + persistence ayrılabilir. R2 riskli — model protokolü §7 şart. |
| `lib/features/status/status_screen.dart` | 529 | Section'lara böl, business logic provider'a. |
| `lib/navigation/main_tab_navigator.dart` | 502 | Tab config const'a çıkar, navigator ince kalsın. |

---

## Regresyon Çapraz Referansları

- R3 (`_substantive` filter) dokunulan dosya: `profile_screen.dart` (1677 satır, split edilmeden iç yapıya dokunmak risk).
- R4 (distance filter): `feed_repository.dart:49` — hit listesinde.
- R6 (video call WebRTC yok): `video_call_screen.dart:153` (catch_), `video_scheduling_screen.dart` (1211 satır) — feature yarım, büyük dosya iki sorunu birleştirmiş.

---

## Düzeltme Sırası Önerisi (3 dalga)

1. **Dalga 1 — Hijyen (küçük, mekanik):**
   - 3 `// ignore:` kaldır (kullan ya da sil).
   - En "yalın" 10 `catch (_)` → `catch (e, st)` + log (yalnızca log ekle, davranışı değiştirme).

2. **Dalga 2 — Repository mimari:**
   - En yoğun 10 dosyadaki Supabase çağrılarını repository'lere taşı.
   - Yeni repository'ler: `settings`, `admin`, `device`, `push`, `mood_map`.

3. **Dalga 3 — Model + split:**
   - Profile copyWith + toJson düzelt (roundtrip testi yeşile çevir).
   - İlk 5 büyük dosyayı split planına göre böl (mood_map, chat, profile, matches, feed).
