import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/mock_mode.dart';
import '../models/gating_status.dart';

class GatingRepository {
  final SupabaseClient? _supabase;

  GatingRepository({SupabaseClient? supabase}) : _supabase = supabase;

  Future<GatingStatus> fetchStatus(String userId) async {
    if (isMockMode) return GatingStatus.mockOpen();
    final client = _supabase!;
    final data = await client
        .from('gating_status')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (data == null) {
      // Row missing (user pre-dates the trigger) — create it now so
      // realtime updates have a row to fire against.
      await client.from('gating_status').upsert(
        {'user_id': userId, 'is_verified': false, 'is_entry_approved': false},
        onConflict: 'user_id',
      );
      return const GatingStatus(isVerified: false, isEntryApproved: false);
    }
    return GatingStatus.fromJson(data);
  }

  Future<void> markVerified(String userId) async {
    if (isMockMode) return;
    await _supabase!
        .from('gating_status')
        .update({'is_verified': true, 'is_entry_approved': true})
        .eq('user_id', userId);
  }

  /// Live stream — emits whenever the gating_status row is updated for this user.
  /// Uses channel-based Postgres CDC (more reliable on web than .stream()).
  /// Requires gating_status to be in supabase_realtime publication.
  Stream<GatingStatus> watchStatus(String userId) {
    if (isMockMode) return Stream.value(GatingStatus.mockOpen());

    final client = _supabase!;
    final controller = StreamController<GatingStatus>();
    final channel = client
        .channel('gating_status:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'gating_status',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final row = payload.newRecord;
            if (row.isNotEmpty && !controller.isClosed) {
              controller.add(GatingStatus.fromJson(row));
            }
          },
        )
        .subscribe();

    controller.onCancel = () {
      client.removeChannel(channel);
      controller.close();
    };

    return controller.stream;
  }
}
