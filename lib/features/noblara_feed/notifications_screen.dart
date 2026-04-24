import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/mock_mode.dart';

// ---------------------------------------------------------------------------
// NoblaraNotification model + provider
// ---------------------------------------------------------------------------

class NoblaraNotification {
  final String id;
  final String kind; // 'reply' | 'reaction' | 'echo'
  final String? postId;
  final String? commentId;
  final bool sourceAnonymous;
  final String? preview;
  final bool isRead;
  final DateTime createdAt;

  const NoblaraNotification({
    required this.id,
    required this.kind,
    required this.postId,
    required this.commentId,
    required this.sourceAnonymous,
    required this.preview,
    required this.isRead,
    required this.createdAt,
  });

  factory NoblaraNotification.fromJson(Map<String, dynamic> j) =>
      NoblaraNotification(
        id: j['id'] as String,
        kind: j['kind'] as String,
        postId: j['post_id'] as String?,
        commentId: j['comment_id'] as String?,
        sourceAnonymous: (j['source_anonymous'] as bool?) ?? false,
        preview: j['preview'] as String?,
        isRead: (j['is_read'] as bool?) ?? false,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

final noblaraNotificationsProvider =
    FutureProvider.autoDispose<List<NoblaraNotification>>((ref) async {
  if (isMockMode) return const [];
  final rows = await Supabase.instance.client
      .from('noblara_notifications')
      .select()
      .order('created_at', ascending: false)
      .limit(100);
  return rows
      .map((r) => NoblaraNotification.fromJson(Map<String, dynamic>.from(r)))
      .toList();
});

final noblaraUnreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  if (isMockMode) return 0;
  try {
    final res = await Supabase.instance.client
        .rpc('fetch_noblara_unread_count');
    if (res is num) return res.toInt();
    return 0;
  } catch (_) {
    return 0;
  }
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Mark all read on open — fire and forget.
    Future.microtask(() async {
      if (isMockMode) return;
      try {
        await Supabase.instance.client
            .rpc('mark_noblara_notifications_read');
        if (mounted) {
          ref.invalidate(noblaraUnreadCountProvider);
          ref.invalidate(noblaraNotificationsProvider);
        }
      } catch (e) {
        debugPrint('[notif] mark-read failed: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final asyncList = ref.watch(noblaraNotificationsProvider);
    return Scaffold(
      backgroundColor: AppColors.nobBackground,
      appBar: AppBar(
        backgroundColor: AppColors.nobBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(),
        title: Text(
          'Notifications',
          style: TextStyle(
            color: context.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: asyncList.when(
          loading: () => const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 1.5, color: AppColors.emerald600),
            ),
          ),
          error: (e, _) => Center(
            child: Text('Could not load notifications.',
                style: TextStyle(color: context.textMuted, fontSize: 13)),
          ),
          data: (list) {
            if (list.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.emerald600.withValues(alpha: 0.08),
                          border: Border.all(
                              color: AppColors.emerald600
                                  .withValues(alpha: 0.18)),
                        ),
                        child: Icon(Icons.notifications_none_rounded,
                            color: AppColors.emerald600.withValues(alpha: 0.5),
                            size: 28),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'No activity yet',
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Replies, echoes and reactions to your\nNobs will land here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: context.textMuted,
                            fontSize: 13,
                            height: 1.5),
                      ),
                    ],
                  ),
                ),
              );
            }
            return RefreshIndicator(
              color: AppColors.emerald600,
              backgroundColor: AppColors.nobSurface,
              onRefresh: () async {
                ref.invalidate(noblaraNotificationsProvider);
              },
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _NotificationTile(item: list[i]),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tile
// ---------------------------------------------------------------------------

class _NotificationTile extends StatelessWidget {
  final NoblaraNotification item;
  const _NotificationTile({required this.item});

  IconData get _icon {
    switch (item.kind) {
      case 'reply':
        return Icons.chat_bubble_outline_rounded;
      case 'reaction':
        return Icons.waving_hand_outlined;
      case 'echo':
        return Icons.graphic_eq_rounded;
      case 'second_thought':
        return Icons.auto_fix_high_rounded;
      case 'future_nob_due':
        return Icons.schedule_rounded;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  String get _title {
    const actor = 'Someone'; // Always anonymous in Noblara notifications
    switch (item.kind) {
      case 'reply':
        return '$actor replied to your Nob';
      case 'reaction':
        return '$actor reacted to your Nob';
      case 'echo':
        return '$actor echoed your Nob';
      case 'second_thought':
        return 'A Nob you engaged with was revised';
      case 'future_nob_due':
        return 'Time to revisit a thought';
      default:
        return '$actor reacted';
    }
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    if (d.inDays < 7) return '${d.inDays}d';
    return '${t.day}/${t.month}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.nobSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: item.isRead
              ? AppColors.nobBorder.withValues(alpha: 0.55)
              : AppColors.emerald600.withValues(alpha: 0.65),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.emerald600.withValues(alpha: 0.12),
              border: Border.all(
                  color: AppColors.emerald600.withValues(alpha: 0.30)),
            ),
            child: Icon(_icon, color: AppColors.emerald350, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _title,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 13,
                          fontWeight: item.isRead
                              ? FontWeight.w500
                              : FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      _ago(item.createdAt),
                      style: TextStyle(
                          color: context.textMuted, fontSize: 11),
                    ),
                  ],
                ),
                if (item.preview != null && item.preview!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.preview!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: context.textMuted,
                        fontSize: 12,
                        height: 1.4),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
