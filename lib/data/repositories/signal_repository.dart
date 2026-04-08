import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/mock_mode.dart';
import '../models/signal.dart';

class SignalRepository {
  final SupabaseClient? _supabase;

  SignalRepository({SupabaseClient? supabase}) : _supabase = supabase;

  /// Check if user can send a signal (tier limit)
  Future<bool> canSendSignal(String userId) async {
    if (isMockMode) return true;
    final result = await _supabase!
        .rpc('check_signal_limit', params: {'p_user_id': userId});
    return result as bool? ?? false;
  }

  /// Send a signal to [receiverId]. Checks permission first.
  Future<bool> sendSignal({
    required String senderId,
    required String receiverId,
  }) async {
    if (isMockMode) return true;

    // Check interaction eligibility
    final eligible = await _supabase!.rpc('can_user_interact', params: {'p_user_id': senderId, 'p_mode': 'date'});
    if (eligible != true) return false;

    // Check if target allows signals from this sender
    final allowed = await _supabase.rpc('can_reach_user', params: {
      'p_sender_id': senderId,
      'p_target_id': receiverId,
      'p_action': 'signal',
    });
    if (allowed != true) return false;

    await _supabase.from('signals').upsert({
      'sender_id': senderId,
      'receiver_id': receiverId,
    });

    // Increment signal counters
    await _supabase
        .rpc('increment_signal_count', params: {'p_user_id': senderId});

    // Notify receiver
    await _supabase.from('notifications').insert({
      'user_id': receiverId,
      'type': 'signal_received',
      'title': 'Someone sent you a Signal',
      'body': 'Someone is interested in you. Check it out!',
      'data': {'sender_id': senderId},
    });
    return true;
  }

  /// Signals received by [userId].
  Future<List<Signal>> fetchSignalsReceived(String userId) async {
    if (isMockMode) {
      return [
        Signal(
          id: 'mock-signal-1',
          senderId: 'mock-user-1',
          receiverId: userId,
          createdAt: DateTime.now(),
          senderName: 'Sofia',
        ),
      ];
    }
    final rows = await _supabase!
        .from('signals')
        .select('*, profiles!signals_sender_id_fkey(display_name, date_avatar_url)')
        .eq('receiver_id', userId)
        .order('created_at', ascending: false);

    return rows.map((r) {
      final profile = r['profiles'] as Map<String, dynamic>?;
      return Signal(
        id: r['id'] as String,
        senderId: r['sender_id'] as String,
        receiverId: r['receiver_id'] as String,
        createdAt: DateTime.parse(r['created_at'] as String),
        senderName: profile?['display_name'] as String?,
        senderPhotoUrl: profile?['date_avatar_url'] as String?,
      );
    }).toList();
  }

  /// Signals sent by [userId].
  Future<List<Signal>> fetchSignalsSent(String userId) async {
    if (isMockMode) return [];
    final rows = await _supabase!
        .from('signals')
        .select()
        .eq('sender_id', userId)
        .order('created_at', ascending: false);

    return rows.map((r) => Signal.fromJson(r)).toList();
  }

  /// Recall a sent signal (only sender can delete).
  Future<void> deleteSignal({required String signalId, required String senderId}) async {
    if (isMockMode) return;
    await _supabase!
        .from('signals')
        .delete()
        .eq('id', signalId)
        .eq('sender_id', senderId);
  }
}
