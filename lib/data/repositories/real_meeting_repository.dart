import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/mock_mode.dart';
import '../models/real_meeting.dart';

class RealMeetingRepository {
  final SupabaseClient? _supabase;

  RealMeetingRepository({SupabaseClient? supabase}) : _supabase = supabase;

  Future<RealMeeting?> fetchForMatch(String matchId) async {
    if (isMockMode) return null;
    final data = await _supabase!
        .from('real_meetings')
        .select()
        .eq('match_id', matchId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (data == null) return null;
    return RealMeeting.fromJson(data);
  }

  Stream<RealMeeting?> watchForMatch(String matchId) {
    if (isMockMode) return const Stream.empty();
    return _supabase!
        .from('real_meetings')
        .stream(primaryKey: ['id'])
        .eq('match_id', matchId)
        .order('created_at', ascending: false)
        .map((rows) => rows.isEmpty ? null : RealMeeting.fromJson(rows.first));
  }

  Future<RealMeeting> propose({
    required String matchId,
    required String proposedBy,
    required DateTime scheduledAt,
    required String locationText,
  }) async {
    final data = await _supabase!.from('real_meetings').insert({
      'match_id': matchId,
      'proposed_by': proposedBy,
      'scheduled_at': scheduledAt.toIso8601String(),
      'location_text': locationText,
      'status': 'proposed',
    }).select().single();
    return RealMeeting.fromJson(data);
  }

  Future<RealMeeting> respond({
    required String meetingId,
    required String responderId,
    required bool accepted,
  }) async {
    final data = await _supabase!
        .from('real_meetings')
        .update({
          'status': accepted ? 'confirmed' : 'cancelled',
          'confirmed_by': accepted ? responderId : null,
        })
        .eq('id', meetingId)
        .select()
        .single();
    return RealMeeting.fromJson(data);
  }

  Future<void> cancel(String meetingId) async {
    await _supabase!
        .from('real_meetings')
        .update({'status': 'cancelled'})
        .eq('id', meetingId);
  }
}
