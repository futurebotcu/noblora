import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/utils/mock_mode.dart';
import '../data/models/app_notification.dart';
import '../data/repositories/notification_repository.dart';
import 'auth_provider.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  if (isMockMode) return NotificationRepository();
  return NotificationRepository(supabase: Supabase.instance.client);
});

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class NotificationState {
  final List<AppNotification> notifications;
  final bool isLoading;
  final AppNotification? latestUnread; // triggers in-app banner

  const NotificationState({
    this.notifications = const [],
    this.isLoading = false,
    this.latestUnread,
  });

  int get unreadCount => notifications.where((n) => n.isUnread).length;

  NotificationState copyWith({
    List<AppNotification>? notifications,
    bool? isLoading,
    AppNotification? latestUnread,
    bool clearLatest = false,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      latestUnread: clearLatest ? null : (latestUnread ?? this.latestUnread),
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class NotificationNotifier extends StateNotifier<NotificationState> {
  final NotificationRepository _repo;
  StreamSubscription<List<AppNotification>>? _sub;
  Set<String> _seenIds = {};

  NotificationNotifier(this._repo) : super(const NotificationState());

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> init(String userId) async {
    if (isMockMode) return;
    state = state.copyWith(isLoading: true);

    // Load initial unread notifications
    try {
      final initial = await _repo.fetchUnread(userId);
      _seenIds = initial.map((n) => n.id).toSet();
      state = state.copyWith(notifications: initial, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }

    // Subscribe to realtime updates
    _sub?.cancel();
    _sub = _repo.notificationsStream(userId).listen(
      (all) {
        if (!mounted) return;
        // Detect newly arrived unread notifications
        AppNotification? newest;
        for (final n in all) {
          if (n.isUnread && !_seenIds.contains(n.id)) {
            if (newest == null || n.createdAt.isAfter(newest.createdAt)) {
              newest = n;
            }
          }
        }
        _seenIds = all.map((n) => n.id).toSet();
        state = state.copyWith(
          notifications: all,
          isLoading: false,
          latestUnread: newest,
        );
      },
      onError: (Object e) {
        if (mounted) state = state.copyWith(isLoading: false);
      },
    );
  }

  Future<void> markRead(String notificationId) async {
    await _repo.markRead(notificationId);
    // Optimistic update
    final updated = state.notifications
        .map((n) => n.id == notificationId
            ? AppNotification(
                id: n.id,
                userId: n.userId,
                type: n.type,
                title: n.title,
                body: n.body,
                data: n.data,
                readAt: DateTime.now(),
                createdAt: n.createdAt,
              )
            : n)
        .toList();
    state = state.copyWith(notifications: updated);
  }

  /// Call after showing the banner so it doesn't re-trigger
  void clearLatest() {
    state = state.copyWith(clearLatest: true);
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  final repo = ref.watch(notificationRepositoryProvider);
  final notifier = NotificationNotifier(repo);

  // Auto-init when userId is available
  final userId = ref.watch(authProvider).userId;
  if (userId != null) {
    notifier.init(userId);
  }

  return notifier;
});
