import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/mock_mode.dart';

/// Centralized abuse reporting — handles user reports across all surfaces
/// (match detail, chat, profile, post). Single insert path for the
/// `user_reports` table.
class UserReportRepository {
  final SupabaseClient? _supabase;

  UserReportRepository({SupabaseClient? supabase}) : _supabase = supabase;

  /// Submit an abuse report for a user. `context` identifies the surface
  /// the report was filed from (e.g. `match_detail`, `chat`); `contextId`
  /// carries the surface-specific identifier (typically the match id).
  Future<void> submitReport({
    required String reporterId,
    required String? reportedUserId,
    required String reason,
    required String context,
    String? contextId,
  }) async {
    if (isMockMode) return;
    final client = _supabase;
    if (client == null) throw Exception('Supabase client not initialized');
    await client.from('user_reports').insert({
      'reporter_id': reporterId,
      'reported_user_id': reportedUserId,
      'reason': reason,
      'context': context,
      'context_id': contextId,
    });
  }
}
