import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

bool get isMockMode {
  final supabaseUrl = dotenv.maybeGet('SUPABASE_URL') ?? '';
  return supabaseUrl.isEmpty || supabaseUrl.contains('<');
}

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
