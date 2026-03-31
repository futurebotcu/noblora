import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/mock_mode.dart';
import '../models/bff_suggestion.dart';
import '../models/bff_plan.dart';

class BffSuggestionRepository {
  final SupabaseClient? _supabase;

  BffSuggestionRepository({SupabaseClient? supabase}) : _supabase = supabase;

  // ─── Suggestions ─────────────────────────────────────────────────

  Future<List<BffSuggestion>> fetchSuggestions(String userId) async {
    if (isMockMode) return _mockSuggestions(userId);

    final rows = await _supabase!
        .from('bff_suggestions')
        .select()
        .or('user_a_id.eq.$userId,user_b_id.eq.$userId')
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    final suggestions = <BffSuggestion>[];
    for (final row in rows) {
      final otherId = row['user_a_id'] == userId
          ? row['user_b_id']
          : row['user_a_id'];

      final profile = await _supabase
          .from('profiles')
          .select('display_name, date_avatar_url, bio')
          .eq('id', otherId)
          .maybeSingle();

      final posts = await _supabase
          .from('posts')
          .select('content')
          .eq('user_id', otherId)
          .eq('is_draft', false)
          .eq('is_archived', false)
          .order('published_at', ascending: false)
          .limit(3);

      row['other_profile'] = profile;
      row['other_posts'] = posts;
      suggestions.add(BffSuggestion.fromJson(row, currentUserId: userId));
    }
    return suggestions;
  }

  Future<Map<String, dynamic>> actOnSuggestion({
    required String suggestionId,
    required String userId,
    required String action,
  }) async {
    if (isMockMode) {
      return action == 'connect'
          ? {'result': 'waiting'}
          : {'result': 'passed'};
    }

    final result = await _supabase!.rpc('process_bff_action', params: {
      'p_suggestion_id': suggestionId,
      'p_user_id': userId,
      'p_action': action,
    });
    return result as Map<String, dynamic>? ?? {'result': 'error'};
  }

  Future<bool> canReceiveSuggestion(String userId) async {
    if (isMockMode) return true;
    final result = await _supabase!
        .rpc('check_bff_suggestion_limit', params: {'p_user_id': userId});
    return result as bool? ?? false;
  }

  /// Trigger real server-side BFF suggestion generation
  Future<int> generateSuggestions(String userId) async {
    if (isMockMode) return 0;
    final result = await _supabase!.rpc('generate_bff_suggestions', params: {
      'p_user_id': userId,
    });
    return (result as int?) ?? 0;
  }

  // ─── Reach Out ───────────────────────────────────────────────────

  Future<bool> canReachOut(String userId) async {
    if (isMockMode) return true;
    final result = await _supabase!
        .rpc('check_reach_out_limit', params: {'p_user_id': userId});
    return result as bool? ?? false;
  }

  Future<void> sendReachOut({
    required String senderId,
    required String receiverId,
  }) async {
    if (isMockMode) return;

    await _supabase!.from('reach_outs').upsert({
      'sender_id': senderId,
      'receiver_id': receiverId,
      'mode': 'bff',
    });

    await _supabase.from('notifications').insert({
      'user_id': receiverId,
      'type': 'bff_reach_out',
      'title': 'Someone reached out',
      'body': 'Someone wants to connect with you. Check it out!',
      'data': {'sender_id': senderId},
    });
  }

  Future<Map<String, dynamic>> acceptReachOut(String reachOutId) async {
    if (isMockMode) return {'result': 'connected'};
    final result = await _supabase!.rpc('accept_reach_out', params: {
      'p_reach_out_id': reachOutId,
    });
    return result as Map<String, dynamic>? ?? {'result': 'error'};
  }

  Future<List<Map<String, dynamic>>> fetchReachOutsReceived(String userId) async {
    if (isMockMode) return [];

    final rows = await _supabase!
        .from('reach_outs')
        .select('*, profiles!reach_outs_sender_id_fkey(display_name, date_avatar_url, bio)')
        .eq('receiver_id', userId)
        .eq('status', 'pending')
        .eq('mode', 'bff')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(rows);
  }

  // ─── Plans ───────────────────────────────────────────────────────

  Future<BffPlan> createPlan({
    required String conversationId,
    required String createdBy,
    required String planType,
    String? location,
    required DateTime scheduledAt,
  }) async {
    if (isMockMode) {
      return BffPlan(
        id: 'mock-plan-${DateTime.now().millisecondsSinceEpoch}',
        conversationId: conversationId,
        createdBy: createdBy,
        planType: planType,
        location: location,
        scheduledAt: scheduledAt,
        status: 'proposed',
        createdAt: DateTime.now(),
      );
    }

    final data = await _supabase!.from('bff_plans').insert({
      'conversation_id': conversationId,
      'created_by': createdBy,
      'plan_type': planType,
      'location': location,
      'scheduled_at': scheduledAt.toIso8601String(),
    }).select().single();

    return BffPlan.fromJson(data);
  }

  Future<void> respondToPlan(String planId, String status) async {
    if (isMockMode) return;
    await _supabase!.from('bff_plans').update({'status': status}).eq('id', planId);
  }

  Future<List<BffPlan>> fetchPlans(String conversationId) async {
    if (isMockMode) return [];

    final rows = await _supabase!
        .from('bff_plans')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: false);

    return rows.map((r) => BffPlan.fromJson(r)).toList();
  }

  // ─── Mock data ───────────────────────────────────────────────────

  List<BffSuggestion> _mockSuggestions(String userId) {
    return [
      BffSuggestion(
        id: 'mock-sug-1',
        userAId: userId,
        userBId: 'mock-bff-user-1',
        commonGround: [
          'You both prefer quieter places',
          'You both seem more structured',
          'You both like slower routines',
        ],
        status: 'pending',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        expiresAt: DateTime.now().add(const Duration(hours: 46)),
        otherUserName: 'Elif',
        otherUserBio: 'Bookworm. Coffee addict. City walker.',
        otherUserNobPosts: [
          'Found a hidden bookstore in Kadikoy today',
          'Best coffee is the one you drink slowly',
          'Weekend plan: absolutely nothing',
        ],
      ),
      BffSuggestion(
        id: 'mock-sug-2',
        userAId: 'mock-bff-user-2',
        userBId: userId,
        commonGround: [
          'You both enjoy creative spaces',
          'You both value deep conversations',
        ],
        status: 'pending',
        createdAt: DateTime.now().subtract(const Duration(hours: 6)),
        expiresAt: DateTime.now().add(const Duration(hours: 42)),
        otherUserName: 'Deniz',
        otherUserBio: 'Designer. Night owl. Museum lover.',
        otherUserNobPosts: [
          'The new exhibition at Istanbul Modern is worth seeing',
          'Design is how it works, not how it looks',
        ],
      ),
    ];
  }
}
