import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/mock_mode.dart';
import '../models/app_notification.dart';

class NotificationRepository {
  final SupabaseClient? _supabase;

  NotificationRepository({SupabaseClient? supabase}) : _supabase = supabase;

  Future<List<AppNotification>> fetchUnread(String userId) async {
    if (isMockMode) return [];
    final data = await _supabase!
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .isFilter('read_at', null)
        .order('created_at', ascending: false)
        .limit(50);
    return data.map((e) => AppNotification.fromJson(e)).toList();
  }

  Future<void> markRead(String notificationId) async {
    if (isMockMode) return;
    await _supabase!
        .from('notifications')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('id', notificationId);
  }

  Future<void> markAllRead(String userId) async {
    if (isMockMode) return;
    await _supabase!
        .from('notifications')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('user_id', userId)
        .isFilter('read_at', null);
  }

  Stream<List<AppNotification>> notificationsStream(String userId) {
    if (isMockMode) return const Stream.empty();
    return _supabase!
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50)
        .map((data) => data.map((e) => AppNotification.fromJson(e)).toList());
  }
}
