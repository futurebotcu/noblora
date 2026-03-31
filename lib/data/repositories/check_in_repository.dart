import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/mock_mode.dart';
import '../models/check_in.dart';

class CheckInRepository {
  final SupabaseClient? _supabase;

  CheckInRepository({SupabaseClient? supabase}) : _supabase = supabase;

  /// Submit a post-meetup check-in. Adjusts trust score server-side.
  Future<void> submitCheckIn({
    required String meetingId,
    required String userId,
    required String response, // 'great' | 'okay' | 'rather_not_say' | 'report'
  }) async {
    if (isMockMode) return;

    await _supabase!.rpc('process_check_in', params: {
      'p_meeting_id': meetingId,
      'p_user_id': userId,
      'p_response': response,
    });
  }

  /// Fetch check-in for a meeting by this user.
  Future<CheckIn?> fetchForMeeting(String meetingId, String userId) async {
    if (isMockMode) return null;

    final data = await _supabase!
        .from('check_ins')
        .select()
        .eq('meeting_id', meetingId)
        .eq('user_id', userId)
        .maybeSingle();

    if (data == null) return null;
    return CheckIn.fromJson(data);
  }

  /// Fetch all meetings that need a check-in (confirmed, past scheduled_at + 2h).
  Future<List<Map<String, dynamic>>> fetchPendingCheckIns(String userId) async {
    if (isMockMode) return [];

    final twoHoursAgo = DateTime.now().subtract(const Duration(hours: 2));

    final data = await _supabase!
        .from('real_meetings')
        .select('*, matches!inner(user1_id, user2_id)')
        .eq('status', 'confirmed')
        .lte('scheduled_at', twoHoursAgo.toIso8601String())
        .or('user1_id.eq.$userId,user2_id.eq.$userId',
            referencedTable: 'matches');

    // Filter out meetings where user already checked in
    final meetingIds = data.map((r) => r['id'] as String).toList();
    if (meetingIds.isEmpty) return [];

    final existingCheckIns = await _supabase
        .from('check_ins')
        .select('meeting_id')
        .eq('user_id', userId)
        .inFilter('meeting_id', meetingIds);

    final checkedInIds =
        existingCheckIns.map((r) => r['meeting_id'] as String).toSet();

    return data.where((r) => !checkedInIds.contains(r['id'] as String)).toList();
  }
}
