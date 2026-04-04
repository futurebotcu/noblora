import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/utils/mock_mode.dart';
import '../data/models/room.dart';
import '../data/models/room_message.dart';
import '../data/models/room_participant.dart';
import '../data/repositories/room_repository.dart';
import 'auth_provider.dart';

// ─── Repository provider ──────────────────────────────────────────

final roomRepositoryProvider = Provider<RoomRepository>((ref) {
  if (isMockMode) return RoomRepository();
  return RoomRepository(supabase: Supabase.instance.client);
});

// ─── Room List State ──────────────────────────────────────────────

class RoomListState {
  final List<Room> rooms;
  final bool isLoading;
  final String? error;

  const RoomListState({
    this.rooms = const [],
    this.isLoading = false,
    this.error,
  });

  RoomListState copyWith({
    List<Room>? rooms,
    bool? isLoading,
    String? error,
  }) =>
      RoomListState(
        rooms: rooms ?? this.rooms,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

// ─── Room List Notifier ───────────────────────────────────────────

class RoomListNotifier extends StateNotifier<RoomListState> {
  final Ref _ref;

  RoomListNotifier(this._ref) : super(const RoomListState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final uid = _ref.read(authProvider).userId;
      final repo = _ref.read(roomRepositoryProvider);

      // Get user's location for proximity sorting
      double? userLat, userLng;
      if (!isMockMode && uid != null) {
        try {
          final profile = await Supabase.instance.client
              .from('profiles')
              .select('location_lat, location_lng')
              .eq('id', uid)
              .maybeSingle();
          userLat = (profile?['location_lat'] as num?)?.toDouble();
          userLng = (profile?['location_lng'] as num?)?.toDouble();
        } catch (_) {}
      }

      final rooms = await repo.fetchRooms(userLat: userLat, userLng: userLng);
      state = state.copyWith(rooms: rooms, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<String> joinRoom(String roomId) async {
    final repo = _ref.read(roomRepositoryProvider);
    try {
      final result = await repo.joinRoom(roomId);
      if (result == 'joined') await load();
      return result;
    } catch (e) {
      return e.toString();
    }
  }

  Future<Room?> createRoom({
    required String title,
    String? description,
    required List<String> topicTags,
    int maxParticipants = 10,
    int qualityScore = 50,
  }) async {
    final uid = _ref.read(authProvider).userId;
    if (uid == null) return null;

    final repo = _ref.read(roomRepositoryProvider);

    // Get host location
    double? hostLat, hostLng;
    if (!isMockMode) {
      try {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('location_lat, location_lng')
            .eq('id', uid)
            .maybeSingle();
        hostLat = (profile?['location_lat'] as num?)?.toDouble();
        hostLng = (profile?['location_lng'] as num?)?.toDouble();
      } catch (_) {}
    }

    final room = await repo.createRoom(
      hostId: uid,
      title: title,
      description: description,
      topicTags: topicTags,
      maxParticipants: maxParticipants,
      qualityScore: qualityScore,
      hostLat: hostLat,
      hostLng: hostLng,
    );

    await load();
    return room;
  }
}

final roomListProvider =
    StateNotifierProvider<RoomListNotifier, RoomListState>((ref) {
  return RoomListNotifier(ref);
});

// ─── Room Chat State ──────────────────────────────────────────────

class RoomChatState {
  final List<RoomMessage> messages;
  final List<RoomParticipant> participants;
  final bool isLoading;

  const RoomChatState({
    this.messages = const [],
    this.participants = const [],
    this.isLoading = false,
  });

  RoomChatState copyWith({
    List<RoomMessage>? messages,
    List<RoomParticipant>? participants,
    bool? isLoading,
  }) =>
      RoomChatState(
        messages: messages ?? this.messages,
        participants: participants ?? this.participants,
        isLoading: isLoading ?? this.isLoading,
      );

  List<RoomMessage> get pinnedMessages =>
      messages.where((m) => m.goldFlagged || m.blueFlagged).toList();
}

// ─── Room Chat Notifier ───────────────────────────────────────────

class RoomChatNotifier extends StateNotifier<RoomChatState> {
  final Ref _ref;
  final String roomId;
  final String hostId;
  StreamSubscription? _msgSub;
  StreamSubscription? _partSub;

  RoomChatNotifier(this._ref, this.roomId, this.hostId)
      : super(const RoomChatState()) {
    _init();
  }

  Future<void> _init() async {
    state = state.copyWith(isLoading: true);
    final repo = _ref.read(roomRepositoryProvider);

    // Load initial data
    try {
      final messages = await repo.fetchMessages(roomId, hostId: hostId);
      final participants = await repo.fetchParticipants(roomId);
      state = state.copyWith(
        messages: messages,
        participants: participants,
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }

    // Subscribe to realtime messages — enrich with participant profile cache
    _msgSub = repo.watchRoomMessages(roomId).listen(
      (rows) {
        if (!mounted) return;
        final msgs = rows.map((r) {
          final msg = RoomMessage.fromJson(r, hostId: hostId);
          // If stream data lacks profile info, fill from participant cache
          if (msg.senderName == null && state.participants.isNotEmpty) {
            final p = state.participants
                .where((p) => p.userId == msg.senderId)
                .firstOrNull;
            if (p != null) {
              return RoomMessage(
                id: msg.id,
                roomId: msg.roomId,
                senderId: msg.senderId,
                content: msg.content,
                goldFlagged: msg.goldFlagged,
                blueFlagged: msg.blueFlagged,
                blueFlaggedBy: msg.blueFlaggedBy,
                createdAt: msg.createdAt,
                senderName: p.displayName,
                senderAvatarUrl: p.avatarUrl,
                isHost: msg.isHost,
              );
            }
          }
          return msg;
        }).toList();
        state = state.copyWith(messages: msgs);
      },
      onError: (Object e) {},
    );

    // Subscribe to realtime participants — re-fetch full data with profile JOIN
    _partSub = repo.watchRoomParticipants(roomId).listen(
      (rows) async {
        if (!mounted) return;
        // Stream data lacks profile JOIN; re-fetch with proper query
        try {
          final participants = await repo.fetchParticipants(roomId);
          if (mounted) state = state.copyWith(participants: participants);
        } catch (_) {
          // Fallback: use raw stream data
          final parts = rows.map((r) => RoomParticipant.fromJson(r)).toList();
          if (mounted) state = state.copyWith(participants: parts);
        }
      },
      onError: (Object e) {},
    );
  }

  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;
    await _ref.read(roomRepositoryProvider).sendMessage(roomId, content);
  }

  Future<String> flagGold(String messageId) async {
    return _ref.read(roomRepositoryProvider).flagMessageGold(messageId);
  }

  Future<String> flagBlue(String messageId) async {
    return _ref.read(roomRepositoryProvider).flagMessageBlue(messageId);
  }

  Future<String> leaveRoom() async {
    return _ref.read(roomRepositoryProvider).leaveRoom(roomId);
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _partSub?.cancel();
    super.dispose();
  }
}

final roomChatProvider = StateNotifierProvider.autoDispose
    .family<RoomChatNotifier, RoomChatState, ({String roomId, String hostId})>(
  (ref, args) => RoomChatNotifier(ref, args.roomId, args.hostId),
);
