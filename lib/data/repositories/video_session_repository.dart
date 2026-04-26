import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/mock_mode.dart';
import '../models/video_session.dart';
import '../../services/video_service.dart';

class VideoSessionRepository {
  final SupabaseClient? _supabase;

  VideoSessionRepository({SupabaseClient? supabase}) : _supabase = supabase;

  /// Propose a time for the video call.
  /// [recipientId] is the other user who should receive the notification.
  Future<VideoSession> proposeTime({
    required String matchId,
    required String proposedBy,
    required String recipientId,
    required DateTime scheduledAt,
  }) async {
    if (isMockMode) {
      final now = DateTime.now();
      return VideoSession(
        id: 'mock-session-1',
        matchId: matchId,
        scheduledAt: scheduledAt,
        status: 'pending',
        proposedBy: proposedBy,
        roomUrl: VideoService.roomUrl(matchId),
        createdAt: now,
        proposedAt: now,
      );
    }

    final data = await _supabase!.from('video_sessions').insert({
      'match_id': matchId,
      'scheduled_at': scheduledAt.toIso8601String(),
      'proposed_by': proposedBy,
      'proposed_at': DateTime.now().toIso8601String(),
      'room_url': VideoService.roomUrl(matchId),
      'status': 'pending',
    }).select().single();

    // Notify the recipient that a video call was proposed
    if (recipientId.isNotEmpty) {
      await _supabase.from('notifications').insert({
        'user_id': recipientId,
        'type': 'video_proposed',
        'title': 'Video Call Proposed',
        'body': 'Your match wants to schedule a video call. Confirm or suggest another time.',
        'data': {'match_id': matchId, 'session_id': data['id']},
      });
    }

    return VideoSession.fromJson(data);
  }

  /// Male confirms or counter-proposes.
  /// [proposerUserId] is used to notify the original proposer when accepted.
  Future<VideoSession> respond({
    required String sessionId,
    required String responderId,
    required bool accepted,
    DateTime? counterTime,
    String? proposerUserId,
  }) async {
    if (isMockMode) {
      return VideoSession(
        id: sessionId,
        matchId: 'mock-match-1',
        scheduledAt: counterTime ?? DateTime.now().add(const Duration(hours: 1)),
        status: accepted ? 'accepted' : 'counter_proposed',
        proposedBy: 'mock-user',
        confirmedBy: accepted ? responderId : null,
        createdAt: DateTime.now(),
        proposedAt: DateTime.now(),
      );
    }

    final update = accepted
        ? {'status': 'accepted', 'confirmed_by': responderId}
        : {
            'status': 'counter_proposed',
            'scheduled_at': counterTime!.toIso8601String(),
            'counter_proposed_at': DateTime.now().toIso8601String(),
          };

    final data = await _supabase!
        .from('video_sessions')
        .update(update)
        .eq('id', sessionId)
        .select()
        .single();

    // Notify the original proposer when the call is confirmed
    if (accepted && proposerUserId != null && proposerUserId.isNotEmpty) {
      await _supabase.from('notifications').insert({
        'user_id': proposerUserId,
        'type': 'video_confirmed',
        'title': 'Video Call Confirmed!',
        'body': 'Your match confirmed the video call. Get ready!',
        'data': {
          'match_id': data['match_id'],
          'session_id': sessionId,
        },
      });
    }

    return VideoSession.fromJson(data);
  }

  Future<VideoSession?> fetchForMatch(String matchId) async {
    if (isMockMode) return null;
    final data = await _supabase!
        .from('video_sessions')
        .select()
        .eq('match_id', matchId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (data == null) return null;
    return VideoSession.fromJson(data);
  }

  /// Realtime stream — karşı öneri veya onay anında UI'ya yansısın.
  Stream<VideoSession?> watchForMatch(String matchId) {
    if (isMockMode) return const Stream.empty();
    return _supabase!
        .from('video_sessions')
        .stream(primaryKey: ['id'])
        .eq('match_id', matchId)
        .order('created_at', ascending: false)
        .map((rows) => rows.isEmpty ? null : VideoSession.fromJson(rows.first));
  }

  /// Decline an incoming proposal with an optional reason.
  /// If [counterTime] is provided, a counter-proposal is sent instead.
  Future<VideoSession> decline({
    required String sessionId,
    required String responderId,
    required String reason,
    DateTime? counterTime,
  }) async {
    if (isMockMode) {
      return VideoSession(
        id: sessionId,
        matchId: 'mock-match-1',
        scheduledAt: counterTime ?? DateTime.now().add(const Duration(hours: 2)),
        status: counterTime != null ? 'counter_proposed' : 'cancelled',
        proposedBy: 'mock-user',
        createdAt: DateTime.now(),
        proposedAt: DateTime.now(),
        declineReason: reason,
        counterProposedAt: counterTime != null ? DateTime.now() : null,
      );
    }
    final update = counterTime != null
        ? {
            'status': 'counter_proposed',
            'scheduled_at': counterTime.toIso8601String(),
            'counter_proposed_at': DateTime.now().toIso8601String(),
            'decline_reason': reason,
          }
        : {
            'status': 'cancelled',
            'decline_reason': reason,
          };
    final data = await _supabase!
        .from('video_sessions')
        .update(update)
        .eq('id', sessionId)
        .select()
        .single();
    return VideoSession.fromJson(data);
  }

  Future<void> markStarted(String sessionId) async {
    if (isMockMode) return;
    await _supabase!
        .from('video_sessions')
        .update({'status': 'active', 'started_at': DateTime.now().toIso8601String()})
        .eq('id', sessionId);
  }

  Future<void> markCompleted(String sessionId, int durationSeconds) async {
    if (isMockMode) return;
    await _supabase!.from('video_sessions').update({
      'status': 'completed',
      'ended_at': DateTime.now().toIso8601String(),
      'duration_seconds': durationSeconds,
    }).eq('id', sessionId);

    // Also update match status
    final session = await _supabase
        .from('video_sessions')
        .select('match_id')
        .eq('id', sessionId)
        .single();
    await _supabase
        .from('matches')
        .update({'status': 'video_completed'})
        .eq('id', session['match_id'] as String);
  }

  /// Submit post-call decision (enjoyed or not).
  /// Upserts the row then calls process_call_decision.
  /// Returns: 'chat_opened' | 'closed' | 'waiting'
  Future<String> submitDecision({
    required String sessionId,
    required String userId,
    required bool enjoyed,
  }) async {
    if (isMockMode) return enjoyed ? 'chat_opened' : 'closed';

    // Upsert this user's decision
    await _supabase!.from('call_decisions').upsert({
      'video_session_id': sessionId,
      'user_id': userId,
      'enjoyed': enjoyed,
    });

    return _processDecision(sessionId: sessionId, userId: userId, enjoyed: enjoyed);
  }

  /// Re-run process_call_decision without upserting again.
  /// Used by the realtime listener once both decisions are detected.
  Future<String> finalizeDecision({
    required String sessionId,
    required String userId,
    required bool enjoyed,
  }) async {
    if (isMockMode) return enjoyed ? 'chat_opened' : 'closed';
    return _processDecision(sessionId: sessionId, userId: userId, enjoyed: enjoyed);
  }

  Future<String> _processDecision({
    required String sessionId,
    required String userId,
    required bool enjoyed,
  }) async {
    final result = await _supabase!.rpc('process_call_decision', params: {
      'p_video_session_id': sessionId,
      'p_user_id': userId,
      'p_enjoyed': enjoyed,
    });
    final resultMap = result as Map<String, dynamic>;
    final r = resultMap['result'] as String? ?? 'waiting';
    return r == 'expired' ? 'closed' : r;
  }

  /// Stream of call_decisions rows for [sessionId] — emits the full set of
  /// decisions every time one changes. Used by the post-call decision screen
  /// to know when both participants have decided. Empty stream in mock mode.
  Stream<List<Map<String, dynamic>>> streamCallDecisions(String sessionId) {
    if (isMockMode) return const Stream.empty();
    return _supabase!
        .from('call_decisions')
        .stream(primaryKey: ['id'])
        .eq('video_session_id', sessionId);
  }
}
