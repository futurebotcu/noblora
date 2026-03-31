# Noblara

Elite Black & Gold dating app — built with Flutter.

## Stack

- **Flutter** 3.35 / Dart 3.9
- **Riverpod** 2.6 — state management
- **Supabase** — auth & database (optional, mock mode available)
- **Google Fonts** — Playfair Display + Inter
- **flutter_dotenv** — env config

## Quick Start

```bash
# 1. Dependencies
flutter pub get

# 2. Web (mock mode — no Supabase needed)
flutter run -d chrome --web-port 8082

# 3. Mobile (connected device / emulator)
flutter run
```

## Mock Mode

When `.env` contains placeholder values (`<your-supabase-url>`), the app runs
fully offline with a mock golden user and 5 sample feed cards.

## Project Structure

```
lib/
├── main.dart            # Entry point (dotenv + Supabase init + ProviderScope)
├── app.dart             # MaterialApp + AppTheme.dark
├── core/
│   ├── theme/           # AppColors, AppTheme, AppSpacing
│   └── utils/           # mock_mode.dart
├── data/
│   ├── models/          # Profile, GatingStatus, ProfileCard
│   └── repositories/    # AuthRepository, ProfileRepository, GatingRepository
├── providers/           # Riverpod StateNotifiers (auth, profile, gating, feed)
├── navigation/          # AppRouter (5-flow gating) + MainTabNavigator
├── features/
│   ├── auth/            # WelcomeScreen, SignInScreen, SignUpScreen
│   ├── onboarding/      # ModeSelection, GenderSelection, ProfileBasics
│   ├── feed/            # FeedScreen + SwipeCardWidget (gesture + animation)
│   ├── matches/         # MatchesScreen
│   ├── social/          # SocialScreen (placeholder)
│   ├── profile/         # ProfileScreen
│   ├── verification/    # VerificationHubScreen (placeholder)
│   └── entry_gate/      # EntryGateScreen (placeholder)
└── shared/widgets/      # AppButton, AppTextField, SkeletonLoader

assets/
├── images/              # logo.svg, logo_wordmark.svg
└── icons/               # star_gold.svg, crown.svg, verified.svg
```

## Gating Flow

```
Splash → Auth → Onboarding → Verification* → Entry Gate* → Main Tabs
                                    * placeholder screens
```

## Next Phase

- Real-time Chat (Supabase Realtime)
- Video Call
- QR Check-in
- Photo Upload (Supabase Storage)
- Push Notifications
