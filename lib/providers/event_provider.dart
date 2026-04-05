import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/utils/mock_mode.dart' show isMockMode, kSocialEnabled;
import '../data/models/event.dart';
import '../data/models/event_participant.dart';
import '../data/models/event_message.dart';
import '../data/models/filter_state.dart';
import '../data/repositories/event_repository.dart';
import 'auth_provider.dart';
import 'filter_provider.dart';

// ─── State ─────────────────────────────────────────────────────────

class EventListState {
  final List<NobEvent> events;
  final bool isLoading;
  final String? error;

  const EventListState({
    this.events = const [],
    this.isLoading = false,
    this.error,
  });

  EventListState copyWith({
    List<NobEvent>? events,
    bool? isLoading,
    String? error,
  }) =>
      EventListState(
        events: events ?? this.events,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

// ─── Repository provider ───────────────────────────────────────────

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  if (isMockMode) return EventRepository();
  return EventRepository(supabase: Supabase.instance.client);
});

// ─── Event list notifier ───────────────────────────────────────────

class EventListNotifier extends StateNotifier<EventListState> {
  final Ref _ref;

  EventListNotifier(this._ref) : super(const EventListState()) {
    // When Social is disabled, skip the filter listener so no background
    // reloads fire when the user toggles date/BFF filters.
    if (kSocialEnabled) {
      _ref.listen<FilterState>(filterProvider, (_, __) => load());
    }
  }

  Future<void> load() async {
    // Social disabled → stay in the empty default state, no network calls.
    if (!kSocialEnabled) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final uid = _ref.read(authProvider).userId;
      final repo = _ref.read(eventRepositoryProvider);
      final events = await repo.fetchEvents(userId: uid);
      state = state.copyWith(events: events, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<NobEvent?> createEvent({
    required String title,
    String? description,
    required DateTime eventDate,
    String? locationText,
    int maxAttendees = 10,
    bool plus3Enabled = false,
    bool companionEnabled = true,
    int qualityScore = 50,
  }) async {
    final uid = _ref.read(authProvider).userId;
    if (uid == null) return null;

    final repo = _ref.read(eventRepositoryProvider);
    final event = await repo.createEvent(
      hostId: uid,
      title: title,
      description: description,
      eventDate: eventDate,
      locationText: locationText,
      maxAttendees: maxAttendees,
      plus3Enabled: plus3Enabled,
      companionEnabled: companionEnabled,
      qualityScore: qualityScore,
    );

    state = state.copyWith(events: [event, ...state.events]);
    return event;
  }

  Future<String> joinEvent(String eventId, {int companionCount = 0}) async {
    final repo = _ref.read(eventRepositoryProvider);
    final result = await repo.joinEvent(eventId, companionCount: companionCount);
    if (result['result'] == 'joined') await load();
    return result['result'] as String? ?? 'error';
  }

  Future<void> leaveEvent(String eventId) async {
    final repo = _ref.read(eventRepositoryProvider);
    await repo.leaveEvent(eventId);
    await load();
  }
}

final eventListProvider =
    StateNotifierProvider<EventListNotifier, EventListState>((ref) {
  return EventListNotifier(ref);
});

// ─── Single event detail provider ──────────────────────────────────

class EventDetailState {
  final NobEvent? event;
  final List<EventParticipant> participants;
  final List<EventMessage> messages;
  final bool isLoading;

  const EventDetailState({
    this.event,
    this.participants = const [],
    this.messages = const [],
    this.isLoading = false,
  });
}

class EventDetailNotifier extends StateNotifier<EventDetailState> {
  final Ref _ref;
  final String eventId;

  EventDetailNotifier(this._ref, this.eventId) : super(const EventDetailState());

  Future<void> load() async {
    // Social disabled → skip all fetches; screen is navigationally unreachable.
    if (!kSocialEnabled) return;
    state = const EventDetailState(isLoading: true);
    final repo = _ref.read(eventRepositoryProvider);
    final event = await repo.fetchEvent(eventId);
    final participants = await repo.fetchParticipants(eventId, hostId: event?.hostId);
    final messages = await repo.fetchMessages(eventId, hostId: event?.hostId);
    state = EventDetailState(
      event: event,
      participants: participants,
      messages: messages,
    );

    // Auto-leave ended events if user has leave_event_chat_auto ON
    if (event != null && event.isLocked && !isMockMode) {
      final uid = _ref.read(authProvider).userId;
      if (uid != null) {
        try {
          final row = await Supabase.instance.client.from('profiles')
              .select('leave_event_chat_auto').eq('id', uid).maybeSingle();
          if (row?['leave_event_chat_auto'] == true) {
            await repo.updateAttendance(eventId, uid, 'out');
          }
        } catch (_) {}
      }
    }
  }

  /// Reload only the messages list (not event + participants).
  Future<void> refreshMessages() async {
    final repo = _ref.read(eventRepositoryProvider);
    final messages = await repo.fetchMessages(eventId, hostId: state.event?.hostId);
    state = EventDetailState(
      event: state.event,
      participants: state.participants,
      messages: messages,
    );
  }

  Future<void> sendMessage(String content) async {
    final uid = _ref.read(authProvider).userId;
    if (uid == null) return;
    final repo = _ref.read(eventRepositoryProvider);
    await repo.sendMessage(eventId, uid, content);
    // Only refresh messages, not the entire event+participants
    await refreshMessages();
  }

  Future<void> flagGold(String messageId) async {
    final repo = _ref.read(eventRepositoryProvider);
    await repo.flagGold(messageId);
    await refreshMessages();
  }

  Future<void> flagBlue(String messageId) async {
    final repo = _ref.read(eventRepositoryProvider);
    await repo.flagBlue(messageId);
    await refreshMessages();
  }

  Future<void> updateMyAttendance(String status) async {
    final uid = _ref.read(authProvider).userId;
    if (uid == null) return;
    final repo = _ref.read(eventRepositoryProvider);
    await repo.updateAttendance(eventId, uid, status);
    await load();
  }

  Future<void> submitCheckin({required bool wasReal, required bool hostRating, required bool noshow}) async {
    final repo = _ref.read(eventRepositoryProvider);
    await repo.submitCheckin(eventId: eventId, wasReal: wasReal, hostRating: hostRating, noshow: noshow);
  }
}

final eventDetailProvider =
    StateNotifierProvider.family<EventDetailNotifier, EventDetailState, String>(
        (ref, eventId) => EventDetailNotifier(ref, eventId));
