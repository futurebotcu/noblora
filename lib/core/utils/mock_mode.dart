import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

bool get isMockMode {
  final supabaseUrl = dotenv.maybeGet('SUPABASE_URL') ?? '';
  return supabaseUrl.isEmpty || supabaseUrl.contains('<');
}

/// Feature flag — Social layer (events, rooms, circles, group chats).
///
/// When false:
///   • Social tab hidden from mode switcher, profile persona pills,
///     stats tabs, inbox tabs.
///   • Event/Room providers short-circuit (no network calls, no streams).
///   • Onboarding defaults exclude 'social' from active_modes.
///   • Settings toggles for social_active/social_visible/event_* hidden.
///
/// The Social code lives in lib/features/social/ and related providers/
/// repositories, but is inert at runtime. Flip to true to re-enable.
const bool kSocialEnabled = false;

/// True when running on localhost in debug mode.
/// Used to enable dev-only shortcuts like auto-verification.
bool get isDevMode {
  if (kReleaseMode) return false;
  if (isMockMode) return false;
  if (kIsWeb) {
    final host = Uri.base.host;
    return host == 'localhost' || host == '127.0.0.1';
  }
  return kDebugMode;
}
