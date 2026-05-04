import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

bool get isMockMode {
  final supabaseUrl = dotenv.maybeGet('SUPABASE_URL') ?? '';
  final isMock = supabaseUrl.isEmpty || supabaseUrl.contains('<');
  assert(!isMock || kDebugMode, 'SUPABASE_URL is missing or placeholder — app cannot run in release without valid .env');
  return isMock;
}

/// Feature flag — Social layer (rooms, circles, group chats).
///
/// When false:
///   • Room providers short-circuit (no network calls, no streams).
///   • Notifications of type room_*/circle_invite are stripped.
///
/// Events were removed in Dalga 13. Rooms/circles code lives in
/// lib/features/social/ and related providers, but is inert at runtime.
/// Flip to true to re-enable.
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
