import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/mock_mode.dart';

/// RPC wrappers for the noblara_notifications table — distinct from the
/// regular `NotificationRepository` (different table, different RPCs).
/// A future wave (5d7) can move the screen's direct `noblara_notifications`
/// table read here too.
class NoblaraNotificationRepository {
  final SupabaseClient? _supabase;

  NoblaraNotificationRepository({SupabaseClient? supabase})
      : _supabase = supabase;

  /// Server-side count of unread noblara notifications for the current
  /// session user. RPC reads `auth.uid()` internally so no parameter.
  Future<int> fetchUnreadCount() async {
    if (isMockMode) return 0;
    final res = await _supabase!.rpc('fetch_noblara_unread_count');
    if (res is num) return res.toInt();
    return 0;
  }

  /// Mark every unread noblara notification for the current session user as
  /// read. Caller invalidates dependent providers after.
  Future<void> markAllRead() async {
    if (isMockMode) return;
    await _supabase!.rpc('mark_noblara_notifications_read');
  }
}
