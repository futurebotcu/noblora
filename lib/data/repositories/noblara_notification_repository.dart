import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/mock_mode.dart';

/// RPC + table wrappers for the noblara_notifications table — distinct from
/// the regular `NotificationRepository` (different table, different RPCs).
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

  /// Fetch the most recent noblara notifications for the current session user.
  /// RLS scopes rows to `auth.uid()`. Returns raw rows; caller maps to
  /// `NoblaraNotification.fromJson`.
  Future<List<Map<String, dynamic>>> fetchAll({int limit = 100}) async {
    if (isMockMode) return const [];
    final rows = await _supabase!
        .from('noblara_notifications')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(
      (rows as List).map((r) => Map<String, dynamic>.from(r as Map)),
    );
  }
}
