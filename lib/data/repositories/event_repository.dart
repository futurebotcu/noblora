import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/mock_mode.dart';
import '../models/event.dart';
import '../models/event_participant.dart';
import '../models/event_message.dart';

class EventRepository {
  final SupabaseClient? _supabase;

  EventRepository({SupabaseClient? supabase}) : _supabase = supabase;

  // ─── Events ──────────────────────────────────────────────────────

  Future<List<NobEvent>> fetchEvents({String? userId}) async {
    if (isMockMode) return _mockEvents();

    final rows = await _supabase!
        .from('events')
        .select('*, host_profile:profiles!events_host_id_fkey(display_name, date_avatar_url)')
        .eq('status', 'active')
        .gte('event_date', DateTime.now().toIso8601String())
        .order('quality_score', ascending: false)
        .order('event_date', ascending: true);

    return rows.map((r) => NobEvent.fromJson(r, currentUserId: userId)).toList();
  }

  Future<NobEvent?> fetchEvent(String eventId) async {
    if (isMockMode) return _mockEvents().first;

    final row = await _supabase!
        .from('events')
        .select('*, host_profile:profiles!events_host_id_fkey(display_name, date_avatar_url)')
        .eq('id', eventId)
        .maybeSingle();

    return row != null ? NobEvent.fromJson(row) : null;
  }

  Future<NobEvent> createEvent({
    required String hostId,
    required String title,
    String? description,
    String? coverImageUrl,
    required DateTime eventDate,
    String? locationText,
    int maxAttendees = 10,
    bool plus3Enabled = false,
    bool companionEnabled = true,
    int qualityScore = 50,
  }) async {
    if (isMockMode) {
      return NobEvent(
        id: 'mock-event-${DateTime.now().millisecondsSinceEpoch}',
        hostId: hostId,
        title: title,
        description: description,
        eventDate: eventDate,
        locationText: locationText,
        maxAttendees: maxAttendees,
        plus3Enabled: plus3Enabled,
        companionEnabled: companionEnabled,
        status: 'active',
        qualityScore: qualityScore,
        createdAt: DateTime.now(),
      );
    }

    final data = await _supabase!.from('events').insert({
      'host_id': hostId,
      'title': title,
      'description': description,
      'cover_image_url': coverImageUrl,
      'event_date': eventDate.toIso8601String(),
      'location_text': locationText,
      'max_attendees': maxAttendees,
      'plus3_enabled': plus3Enabled,
      'companion_enabled': companionEnabled,
      'quality_score': qualityScore,
    }).select().single();

    return NobEvent.fromJson(data);
  }

  // ─── Participation ───────────────────────────────────────────────

  Future<Map<String, dynamic>> joinEvent(String eventId, {int companionCount = 0}) async {
    if (isMockMode) return {'result': 'joined'};
    final result = await _supabase!.rpc('join_event', params: {
      'p_event_id': eventId,
      'p_companion_count': companionCount,
    });
    return result as Map<String, dynamic>? ?? {'result': 'error'};
  }

  Future<void> leaveEvent(String eventId) async {
    if (isMockMode) return;
    await _supabase!.rpc('leave_event', params: {'p_event_id': eventId});
  }

  Future<void> updateAttendance(String eventId, String userId, String status) async {
    if (isMockMode) return;
    await _supabase!
        .from('event_participants')
        .update({'attendance_status': status})
        .eq('event_id', eventId)
        .eq('user_id', userId);
  }

  Future<List<EventParticipant>> fetchParticipants(String eventId, {String? hostId}) async {
    if (isMockMode) return _mockParticipants(eventId);

    final rows = await _supabase!
        .from('event_participants')
        .select('*, profiles(display_name, date_avatar_url)')
        .eq('event_id', eventId)
        .neq('attendance_status', 'out')
        .order('joined_at', ascending: true);

    return rows.map((r) => EventParticipant.fromJson(r, isHost: r['user_id'] == hostId)).toList();
  }

  // ─── Messages ────────────────────────────────────────────────────

  Future<List<EventMessage>> fetchMessages(String eventId, {String? hostId}) async {
    if (isMockMode) return [];

    final rows = await _supabase!
        .from('event_messages')
        .select('*, profiles(display_name, date_avatar_url)')
        .eq('event_id', eventId)
        .order('created_at', ascending: true)
        .limit(200);

    return rows.map((r) => EventMessage.fromJson(r, hostId: hostId)).toList();
  }

  Future<void> sendMessage(String eventId, String senderId, String content) async {
    if (isMockMode) return;
    // Check interaction eligibility
    final eligible = await _supabase!.rpc('can_user_interact', params: {'p_user_id': senderId, 'p_mode': 'social'});
    if (eligible != true) return;
    await _supabase.from('event_messages').insert({
      'event_id': eventId,
      'sender_id': senderId,
      'content': content,
    });
  }

  Future<void> flagGold(String messageId) async {
    if (isMockMode) return;
    await _supabase!.rpc('flag_message_gold', params: {'p_message_id': messageId});
  }

  Future<void> flagBlue(String messageId) async {
    if (isMockMode) return;
    await _supabase!.rpc('flag_message_blue', params: {'p_message_id': messageId});
  }

  // ─── Checkin ─────────────────────────────────────────────────────

  Future<void> submitCheckin({
    required String eventId,
    required bool wasReal,
    required bool hostRating,
    required bool noshow,
  }) async {
    if (isMockMode) return;
    await _supabase!.rpc('submit_event_checkin', params: {
      'p_event_id': eventId,
      'p_was_real': wasReal,
      'p_host_rating': hostRating,
      'p_noshow': noshow,
    });
  }

  // ─── Mock data ───────────────────────────────────────────────────

  List<NobEvent> _mockEvents() {
    return [
      NobEvent(
        id: 'mock-ev-1',
        hostId: 'mock-host-1',
        title: 'Kadikoy Coffee Walk',
        description: 'Exploring hidden coffee spots along the coast. Casual vibes, no rush.',
        eventDate: DateTime.now().add(const Duration(hours: 26)),
        locationText: 'Kadikoy, Istanbul',
        maxAttendees: 8,
        status: 'active',
        qualityScore: 85,
        attendeeCount: 3,
        createdAt: DateTime.now().subtract(const Duration(hours: 4)),
        hostName: 'Merve',
      ),
      NobEvent(
        id: 'mock-ev-2',
        hostId: 'mock-host-2',
        title: 'Board Games Night',
        description: 'Bring your favorite game or come discover new ones. Snacks provided!',
        eventDate: DateTime.now().add(const Duration(hours: 50)),
        locationText: 'Besiktas, Istanbul',
        maxAttendees: 12,
        status: 'active',
        qualityScore: 72,
        attendeeCount: 7,
        createdAt: DateTime.now().subtract(const Duration(hours: 8)),
        hostName: 'Can',
      ),
      NobEvent(
        id: 'mock-ev-3',
        hostId: 'mock-host-3',
        title: 'Silent Reading Hour',
        description: 'Bring a book, sit in silence, leave inspired.',
        eventDate: DateTime.now().add(const Duration(days: 3)),
        locationText: 'Cihangir, Istanbul',
        maxAttendees: 6,
        status: 'active',
        qualityScore: 90,
        attendeeCount: 2,
        createdAt: DateTime.now().subtract(const Duration(hours: 12)),
        hostName: 'Elif',
      ),
    ];
  }

  List<EventParticipant> _mockParticipants(String eventId) {
    return [
      EventParticipant(
        id: 'mock-p-1', eventId: eventId, userId: 'mock-host-1',
        attendanceStatus: 'going', joinedAt: DateTime.now(),
        displayName: 'Merve', isHost: true,
      ),
      EventParticipant(
        id: 'mock-p-2', eventId: eventId, userId: 'mock-u-2',
        attendanceStatus: 'going', joinedAt: DateTime.now(),
        displayName: 'Ali',
      ),
      EventParticipant(
        id: 'mock-p-3', eventId: eventId, userId: 'mock-u-3',
        attendanceStatus: 'maybe', joinedAt: DateTime.now(),
        displayName: 'Zeynep',
      ),
    ];
  }
}
