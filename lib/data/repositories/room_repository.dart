import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/mock_mode.dart';
import '../models/room.dart';
import '../models/room_message.dart';
import '../models/room_participant.dart';

class RoomRepository {
  final SupabaseClient? _supabase;

  RoomRepository({SupabaseClient? supabase}) : _supabase = supabase;

  // ─── Fetch rooms ordered by proximity ───────────────────────

  Future<List<Room>> fetchRooms({double? userLat, double? userLng}) async {
    if (isMockMode) return _mockRooms();

    final rows = await _supabase!
        .from('rooms')
        .select('*, host_profile:profiles!rooms_host_id_fkey(display_name, date_avatar_url)')
        .eq('status', 'active')
        .order('last_activity_at', ascending: false);

    final rooms = rows
        .map((r) => Room.fromJson(r, userLat: userLat, userLng: userLng))
        .toList();

    // Sort by distance if user location is available
    if (userLat != null && userLng != null) {
      rooms.sort((a, b) {
        final da = a.distanceKm ?? double.infinity;
        final db = b.distanceKm ?? double.infinity;
        return da.compareTo(db);
      });
    }

    return rooms;
  }

  // ─── Fetch single room ──────────────────────────────────────

  Future<Room?> fetchRoom(String roomId) async {
    if (isMockMode) return null;
    final row = await _supabase!
        .from('rooms')
        .select('*, host_profile:profiles!rooms_host_id_fkey(display_name, date_avatar_url)')
        .eq('id', roomId)
        .maybeSingle();
    return row != null ? Room.fromJson(row) : null;
  }

  // ─── Join / Leave ───────────────────────────────────────────

  Future<String> joinRoom(String roomId) async {
    if (isMockMode) return 'joined';
    final result = await _supabase!.rpc('join_room', params: {'p_room_id': roomId});
    return result as String? ?? 'error';
  }

  Future<String> leaveRoom(String roomId) async {
    if (isMockMode) return 'left';
    final result = await _supabase!.rpc('leave_room', params: {'p_room_id': roomId});
    return result as String? ?? 'error';
  }

  // ─── Create room ────────────────────────────────────────────

  Future<Room> createRoom({
    required String hostId,
    required String title,
    String? description,
    required List<String> topicTags,
    int maxParticipants = 10,
    int qualityScore = 50,
    double? hostLat,
    double? hostLng,
  }) async {
    if (isMockMode) {
      return Room(
        id: 'mock-room-${DateTime.now().millisecondsSinceEpoch}',
        hostId: hostId,
        title: title,
        description: description,
        topicTags: topicTags,
        maxParticipants: maxParticipants,
        qualityScore: qualityScore,
        lastActivityAt: DateTime.now(),
        createdAt: DateTime.now(),
      );
    }

    final data = await _supabase!.from('rooms').insert({
      'host_id': hostId,
      'title': title,
      'description': description,
      'topic_tags': topicTags,
      'max_participants': maxParticipants,
      'quality_score': qualityScore,
      'host_lat': hostLat,
      'host_lng': hostLng,
    }).select('*, host_profile:profiles!rooms_host_id_fkey(display_name, date_avatar_url)').single();

    // Auto-join as host
    await _supabase.from('room_participants').insert({
      'room_id': data['id'],
      'user_id': hostId,
    });

    return Room.fromJson(data);
  }

  // ─── Messages ───────────────────────────────────────────────

  Future<List<RoomMessage>> fetchMessages(String roomId, {String? hostId}) async {
    if (isMockMode) return [];

    final rows = await _supabase!
        .from('room_messages')
        .select('*, profiles(display_name, date_avatar_url)')
        .eq('room_id', roomId)
        .order('created_at', ascending: true)
        .limit(200);

    return rows.map((r) => RoomMessage.fromJson(r, hostId: hostId)).toList();
  }

  Future<void> sendMessage(String roomId, String content) async {
    if (isMockMode) return;
    await _supabase!.from('room_messages').insert({
      'room_id': roomId,
      'sender_id': Supabase.instance.client.auth.currentUser!.id,
      'content': content,
    });
  }

  Stream<List<Map<String, dynamic>>> watchRoomMessages(String roomId) {
    if (isMockMode) return const Stream.empty();
    return _supabase!
        .from('room_messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('created_at', ascending: true);
  }

  // ─── Participants ───────────────────────────────────────────

  Future<List<RoomParticipant>> fetchParticipants(String roomId) async {
    if (isMockMode) return [];

    final rows = await _supabase!
        .from('room_participants')
        .select('*, profiles(display_name, date_avatar_url)')
        .eq('room_id', roomId)
        .order('joined_at', ascending: true);

    return rows.map((r) => RoomParticipant.fromJson(r)).toList();
  }

  Stream<List<Map<String, dynamic>>> watchRoomParticipants(String roomId) {
    if (isMockMode) return const Stream.empty();
    return _supabase!
        .from('room_participants')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId);
  }

  // ─── Flagging ───────────────────────────────────────────────

  Future<String> flagMessageGold(String messageId) async {
    if (isMockMode) return 'flagged';
    final result = await _supabase!.rpc('flag_room_message_gold', params: {'p_message_id': messageId});
    return result as String? ?? 'error';
  }

  Future<String> flagMessageBlue(String messageId) async {
    if (isMockMode) return 'flagged';
    final result = await _supabase!.rpc('flag_room_message_blue', params: {'p_message_id': messageId});
    return result as String? ?? 'error';
  }

  // ─── Mock data ──────────────────────────────────────────────

  List<Room> _mockRooms() {
    return [
      Room(
        id: 'mock-room-1',
        hostId: 'mock-user-1',
        title: 'Startup ideas over coffee',
        description: 'Casual chat about side projects',
        topicTags: ['Startup', 'Tech'],
        maxParticipants: 10,
        participantCount: 4,
        qualityScore: 82,
        lastActivityAt: DateTime.now().subtract(const Duration(minutes: 5)),
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        hostName: 'Elif',
      ),
      Room(
        id: 'mock-room-2',
        hostId: 'mock-user-2',
        title: 'Film recommendations tonight',
        description: 'Share your favorite hidden gems',
        topicTags: ['Film', 'Art'],
        maxParticipants: 8,
        participantCount: 6,
        qualityScore: 75,
        lastActivityAt: DateTime.now().subtract(const Duration(minutes: 15)),
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        hostName: 'Deniz',
      ),
    ];
  }
}
