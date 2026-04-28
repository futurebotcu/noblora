import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/mock_mode.dart';

/// FCM push token CRUD on `push_tokens` table. Backs the static
/// `PushNotificationService` API — auth.currentUser is read inside the repo
/// so callers don't need to pass userId (matches the previous private
/// `_saveToken` / `unregisterTokens` contract).
class PushTokenRepository {
  final SupabaseClient? _supabase;

  PushTokenRepository({SupabaseClient? supabase}) : _supabase = supabase;

  /// Lazy singleton for non-Riverpod static callers (PushNotificationService).
  /// Riverpod-aware code should use `pushTokenRepositoryProvider`.
  static PushTokenRepository? _singleton;
  static PushTokenRepository instance() {
    if (isMockMode) return _singleton ??= PushTokenRepository();
    return _singleton ??= PushTokenRepository(supabase: Supabase.instance.client);
  }

  Future<void> upsertCurrentUserToken({
    required String token,
    required String platform,
  }) async {
    if (isMockMode) return;
    final userId = _supabase!.auth.currentUser?.id;
    if (userId == null) return;
    await _supabase.from('push_tokens').upsert(
      {
        'user_id': userId,
        'token': token,
        'platform': platform,
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'user_id,token',
    );
  }

  Future<void> removeAllCurrentUserTokens() async {
    if (isMockMode) return;
    final userId = _supabase!.auth.currentUser?.id;
    if (userId == null) return;
    await _supabase.from('push_tokens').delete().eq('user_id', userId);
  }
}
