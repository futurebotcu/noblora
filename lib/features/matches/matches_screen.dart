import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/premium.dart';
import '../../core/enums/noble_mode.dart';
import '../../core/utils/mock_mode.dart';
import '../../data/models/inbox_item.dart';
import '../../data/models/match.dart';
import '../../features/match/match_detail_screen.dart';
import '../../providers/auth_provider.dart';
import '../../providers/check_in_provider.dart';
import '../../providers/match_provider.dart';
import '../match/check_in_screen.dart';
import '../../core/services/toast_service.dart';
import '../../navigation/main_tab_navigator.dart';
import 'individual_chat_screen.dart';
import '../../data/models/note.dart';
import '../../providers/bff_provider.dart';
import '../../providers/note_provider.dart';

// Number of tabs in the inbox: Alliances + Requests (+ Circles if Social is on).
const int _inboxTabCount = kSocialEnabled ? 3 : 2;

/// Reads message_preview setting for current user — autoDispose so it refreshes per user.
final _messagePreviewProvider = FutureProvider.autoDispose<bool>((ref) async {
  if (isMockMode) return true;
  final uid = ref.watch(authProvider).userId;
  if (uid == null) return true;
  try {
    final row = await Supabase.instance.client.from('profiles')
        .select('message_preview').eq('id', uid).maybeSingle();
    return row?['message_preview'] as bool? ?? true;
  } catch (e) {
    debugPrint('[matches] message_preview fetch failed: $e');
    return true;
  }
});

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

InboxItem _matchToInboxItem(NobleMatch match) {
  final mode = NobleMode.values.firstWhere(
    (m) => m.name == match.mode,
    orElse: () => NobleMode.date,
  );
  return InboxItem(
    id: match.id,
    name: match.otherUserName ?? 'Unknown',
    avatarSeed: match.otherUserId ?? match.id,
    photoUrl: match.otherUserPhotoUrl,
    lastMessage: _statusLabel(match),
    ago: DateTime.now().difference(match.matchedAt),
    mode: mode,
    type: ConversationType.alliance,
    isUnread: match.status == 'pending_intro' ||
        match.status == 'pending_video' ||
        match.status == 'video_completed',
  );
}

String _statusLabel(NobleMatch match) => switch (match.status) {
  'pending_intro' => 'Send a mini intro to get started',
  'pending_video' => 'Ready for a Short Intro?',
  'video_scheduled' => 'Short Intro is on the calendar',
  'video_completed' => 'How did it go?',
  'chatting' => 'Conversation is open',
  'expired' => 'Connection expired',
  'closed' => 'Connection ended',
  _ => match.status,
};

// ---------------------------------------------------------------------------
// Grand Inbox
// ---------------------------------------------------------------------------

class MatchesScreen extends ConsumerStatefulWidget {
  const MatchesScreen({super.key});

  @override
  ConsumerState<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends ConsumerState<MatchesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _inboxTabCount, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(matchProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matchState = ref.watch(matchProvider);
    final allMatches = matchState.matches;

    final alliances = allMatches
        .where((m) =>
            (m.mode == 'date' || m.mode == 'bff') && m.status != 'expired')
        .map(_matchToInboxItem)
        .toList();

    final circles = kSocialEnabled
        ? allMatches
            .where((m) => m.mode == 'social')
            .map(_matchToInboxItem)
            .toList()
        : const <InboxItem>[];

    final totalUnread =
        [...alliances, ...circles].where((i) => i.isUnread).length;

    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Inbox',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  if (totalUnread > 0) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.emerald600.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.emerald600.withValues(alpha: 0.15),
                          width: 0.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.emerald600.withValues(alpha: 0.08),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Text(
                        '$totalUnread new',
                        style: const TextStyle(
                          color: AppColors.emerald500,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  // Refresh
                  PressEffect(
                    onTap: () => ref.read(matchProvider.notifier).load(),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: context.borderSubtleColor,
                          width: 0.5,
                        ),
                      ),
                      child: Icon(
                        Icons.refresh_rounded,
                        color: context.textDisabled,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Tabs ──
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(3),
              child: TabBar(
                controller: _tabCtrl,
                indicator: BoxDecoration(
                  color: context.elevatedColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: context.borderSubtleColor,
                    width: 0.5,
                  ),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: context.textPrimary,
                unselectedLabelColor: context.textMuted,
                labelStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
                unselectedLabelStyle:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
                splashBorderRadius: BorderRadius.circular(10),
                tabs: [
                  Tab(
                    height: 36,
                    child: _TabChip(
                      label: 'Alliances',
                      count: alliances.length,
                    ),
                  ),
                  if (kSocialEnabled)
                    Tab(
                      height: 36,
                      child: _TabChip(
                        label: 'Circles',
                        count: circles.length,
                      ),
                    ),
                  const Tab(height: 36, child: Text('Requests')),
                ],
              ),
            ),

            const SizedBox(height: 4),

            // ── Body ──
            Expanded(
              child: matchState.isLoading && allMatches.isEmpty
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.emerald600),
                    )
                  : TabBarView(
                      controller: _tabCtrl,
                      children: [
                        _AlliancesTab(
                          items: alliances,
                          matchesByItemId: {
                            for (final m in allMatches.where((m) =>
                                (m.mode == 'date' || m.mode == 'bff') &&
                                m.status != 'expired'))
                              m.id: m,
                          },
                        ),
                        if (kSocialEnabled) _CirclesTab(circles: circles),
                        const _RequestsTab(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab chip (label + count)
// ---------------------------------------------------------------------------

class _TabChip extends StatelessWidget {
  final String label;
  final int count;

  const _TabChip({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        if (count > 0) ...[
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.emerald600.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: AppColors.emerald500,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Alliances tab
// ---------------------------------------------------------------------------

class _AlliancesTab extends ConsumerStatefulWidget {
  final List<InboxItem> items;
  final Map<String, NobleMatch> matchesByItemId;
  const _AlliancesTab({required this.items, required this.matchesByItemId});

  @override
  ConsumerState<_AlliancesTab> createState() => _AlliancesTabState();
}

class _AlliancesTabState extends ConsumerState<_AlliancesTab> {
  NobleMode? _filter;

  List<InboxItem> get _filtered {
    if (_filter == null) return widget.items;
    return widget.items.where((i) => i.mode == _filter).toList();
  }

  void _onTapItem(BuildContext context, InboxItem item) {
    final match = widget.matchesByItemId[item.id];
    if (match == null) return;

    if (match.status == 'chatting' && match.conversationId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => IndividualChatScreen(
            item: item,
            conversationId: match.conversationId!,
            matchId: match.id,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MatchDetailScreen(match: match),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authProvider).userId;
    final pendingCheckIns = uid != null
        ? ref.watch(pendingCheckInsProvider(uid))
        : const AsyncValue<List<Map<String, dynamic>>>.data([]);

    return Column(
      children: [
        // Pending check-in banner
        ...pendingCheckIns.when(
          data: (pending) {
            if (pending.isEmpty) return <Widget>[];
            return [
              GestureDetector(
                onTap: () {
                  final meetingId = pending.first['id'] as String?;
                  if (meetingId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CheckInScreen(
                            meetingId: meetingId,
                            otherUserName: 'your match'),
                      ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  decoration: BoxDecoration(
                    color: AppColors.emerald600.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.emerald600.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.rate_review_rounded,
                          color: AppColors.emerald500, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'You have a pending check-in',
                          style: TextStyle(
                              color: AppColors.emerald500, fontSize: 13),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color: AppColors.emerald500, size: 18),
                    ],
                  ),
                ),
              ),
            ];
          },
          loading: () => <Widget>[],
          error: (_, __) => <Widget>[],
        ),

        // ── Filter chips ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(
            children: [
              _FilterChip(
                label: 'All',
                isActive: _filter == null,
                onTap: () => setState(() => _filter = null),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Date',
                isActive: _filter == NobleMode.date,
                dotColor: AppColors.emerald600,
                onTap: () => setState(() =>
                    _filter = _filter == NobleMode.date ? null : NobleMode.date),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'BFF',
                isActive: _filter == NobleMode.bff,
                dotColor: AppColors.emerald500,
                onTap: () => setState(() =>
                    _filter = _filter == NobleMode.bff ? null : NobleMode.bff),
              ),
            ],
          ),
        ),

        // ── List ──
        Expanded(
          child: _filtered.isEmpty
              ? _EmptyInbox(
                  icon: Icons.favorite_outline_rounded,
                  title: 'Your world is quiet',
                  subtitle: 'Meaningful connections will appear here',
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: _filtered.length + 1, // +1 for footer
                  itemBuilder: (context, i) {
                    if (i < _filtered.length) {
                      final item = _filtered[i];
                      return _InboxTile(
                        item: item,
                        onTap: () => _onTapItem(context, item),
                      );
                    }
                    // Footer hint when list is short
                    return _ListFooter(itemCount: _filtered.length);
                  },
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Filter chip (premium pill)
// ---------------------------------------------------------------------------

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color? dotColor;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isActive,
    this.dotColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: Premium.dFast,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.emerald600.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? AppColors.emerald600.withValues(alpha: 0.35)
                : context.borderSubtleColor,
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null) ...[
              Container(
                width: 6,
                height: 6,
                decoration:
                    BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                color: isActive ? AppColors.emerald500 : context.textMuted,
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Inbox tile (alliance row)
// ---------------------------------------------------------------------------

class _InboxTile extends StatelessWidget {
  final InboxItem item;
  final VoidCallback onTap;

  const _InboxTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = item.mode.accentColor;

    return PressEffect(
      onTap: onTap,
      scale: 0.98,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            // ── Avatar ──
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: item.isUnread
                          ? accent.withValues(alpha: 0.6)
                          : context.borderSubtleColor.withValues(alpha: 0.4),
                      width: item.isUnread ? 2 : 0.5,
                    ),
                    boxShadow: item.isUnread
                        ? [BoxShadow(
                            color: accent.withValues(alpha: 0.15),
                            blurRadius: 12,
                            spreadRadius: 1,
                          )]
                        : null,
                  ),
                  child: ClipOval(
                    child: item.photoUrl != null && item.photoUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: item.photoUrl!,
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                            memCacheWidth: 156,
                            errorWidget: (_, __, ___) => _AvatarFallback(
                                initial: item.name[0], color: accent),
                          )
                        : _AvatarFallback(
                            initial: item.name[0], color: accent),
                  ),
                ),
                // Mode dot
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.bgColor, width: 2.5),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(width: 14),

            // ── Content ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + time row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 15,
                            fontWeight:
                                item.isUnread ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        item.timeLabel,
                        style: TextStyle(
                          color: item.isUnread ? accent : context.textDisabled,
                          fontSize: 11,
                          fontWeight:
                              item.isUnread ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Status + unread dot
                  Row(
                    children: [
                      Expanded(
                        child: Consumer(builder: (context, cRef, __) {
                          final preview =
                              cRef.watch(_messagePreviewProvider).valueOrNull ??
                                  true;
                          return Text(
                            preview ? item.lastMessage : 'New activity',
                            style: TextStyle(
                              color: item.isUnread
                                  ? context.textSecondary
                                  : context.textMuted,
                              fontSize: 13,
                              height: 1.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        }),
                      ),
                      if (item.isUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Avatar fallback
// ---------------------------------------------------------------------------

class _AvatarFallback extends StatelessWidget {
  final String initial;
  final Color color;
  const _AvatarFallback({required this.initial, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      color: color.withValues(alpha: 0.15),
      child: Center(
        child: Text(
          initial.toUpperCase(),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Circles tab
// ---------------------------------------------------------------------------

class _CirclesTab extends StatelessWidget {
  final List<InboxItem> circles;
  const _CirclesTab({required this.circles});

  @override
  Widget build(BuildContext context) {
    if (circles.isEmpty) {
      return _EmptyInbox(
        icon: Icons.forum_outlined,
        title: 'No circles yet',
        subtitle: 'Event and room chats will show up here',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: circles.length,
      itemBuilder: (context, i) {
        final circle = circles[i];
        return _CircleTile(
          circle: circle,
          onTap: () {
            ToastService.show(context,
                message: 'Group chat — coming soon', type: ToastType.system);
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Circle tile
// ---------------------------------------------------------------------------

class _CircleTile extends StatelessWidget {
  final InboxItem circle;
  final VoidCallback onTap;

  const _CircleTile({required this.circle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = NobleMode.social.accentColor;

    return PressEffect(
      onTap: onTap,
      scale: 0.98,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: circle.photoUrl != null && circle.photoUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: circle.photoUrl!,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      memCacheWidth: 156,
                      errorWidget: (_, __, ___) => _CircleFallback(color: accent),
                    )
                  : _CircleFallback(color: accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          circle.name,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        circle.timeLabel,
                        style: TextStyle(
                          color: context.textDisabled,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    circle.lastMessage,
                    style: TextStyle(
                      color: context.textMuted,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleFallback extends StatelessWidget {
  final Color color;
  const _CircleFallback({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.forum_rounded, color: color.withValues(alpha: 0.5), size: 22),
    );
  }
}

// ---------------------------------------------------------------------------
// List footer — fills empty space when few conversations exist
// ---------------------------------------------------------------------------

class _ListFooter extends StatelessWidget {
  final int itemCount;
  const _ListFooter({required this.itemCount});

  @override
  Widget build(BuildContext context) {
    // Only show when list is short (< 5 items)
    if (itemCount >= 5) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
      child: Column(
        children: [
          // Subtle divider
          Container(
            width: 40,
            height: 1,
            color: context.borderSubtleColor,
          ),
          const SizedBox(height: 24),
          // Hint card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: Premium.cardDecoration(radius: 16, withGlow: true),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.emerald600.withValues(alpha: 0.08),
                  ),
                  child: Icon(
                    Icons.auto_awesome_outlined,
                    color: AppColors.emerald600.withValues(alpha: 0.5),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'That\u2019s everyone for now',
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'New people appear as you connect',
                        style: TextStyle(
                          color: context.textDisabled,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => MainTabNavigator.switchTab(0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: AppColors.emerald600.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      'Discover',
                      style: TextStyle(
                        color: AppColors.emerald500,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Requests tab
// ---------------------------------------------------------------------------

class _RequestsTab extends ConsumerStatefulWidget {
  const _RequestsTab();

  @override
  ConsumerState<_RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends ConsumerState<_RequestsTab> {
  List<Map<String, dynamic>> _reachOuts = [];
  List<Note> _notes = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final uid = ref.read(authProvider).userId;
    if (uid == null) { setState(() => _loading = false); return; }
    try {
      final repo = ref.read(bffRepositoryProvider);
      final noteRepo = ref.read(noteRepositoryProvider);
      final results = await Future.wait([
        repo.fetchReachOutsReceived(uid),
        noteRepo.fetchReceivedNotes(uid),
      ]);
      if (mounted) {
        setState(() {
          _reachOuts = results[0] as List<Map<String, dynamic>>;
          _notes = results[1] as List<Note>;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[requests] Load failed: $e');
      if (mounted) setState(() { _loading = false; _error = 'Could not load requests'; });
    }
  }

  Future<void> _acceptReachOut(String id) async {
    final repo = ref.read(bffRepositoryProvider);
    try {
      final result = await repo.acceptReachOut(id);
      if (result['result'] == 'connected') {
        if (mounted) {
          ToastService.show(context, message: 'Connected!', type: ToastType.match);
        }
        ref.read(matchProvider.notifier).load();
        _load();
      } else {
        if (mounted) {
          ToastService.show(context, message: 'Could not accept request', type: ToastType.error);
        }
      }
    } catch (e) {
      debugPrint('[matches] acceptReachOut failed: $e');
      if (mounted) {
        ToastService.show(context, message: 'Could not accept request', type: ToastType.error);
      }
    }
  }

  Future<void> _declineReachOut(String id) async {
    try {
      await ref.read(bffRepositoryProvider).markReachOutIgnored(id);
      if (mounted) {
        ToastService.show(context, message: 'Request declined', type: ToastType.system);
        _load();
      }
    } catch (e) {
      debugPrint('[matches] declineReachOut failed: $e');
      if (mounted) {
        ToastService.show(context, message: 'Could not decline', type: ToastType.error);
      }
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppColors.emerald600,
          ),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Something went wrong',
                style: TextStyle(color: context.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: context.textMuted, fontSize: 13),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _load,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    border: Border.all(color: AppColors.emerald600.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'Retry',
                    style: TextStyle(color: AppColors.emerald500, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_reachOuts.isEmpty && _notes.isEmpty) {
      return _EmptyInbox(
        icon: Icons.mail_outline_rounded,
        title: 'Nothing pending',
        subtitle: 'Incoming requests will land here',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.emerald600,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          if (_reachOuts.isNotEmpty) ...[
            _SectionHeader(title: 'Reach Outs', count: _reachOuts.length),
            ..._reachOuts.map((ro) => _ReachOutTile(
              reachOut: ro,
              onAccept: () => _acceptReachOut(ro['id'] as String),
              onDecline: () => _declineReachOut(ro['id'] as String),
              timeAgo: _timeAgo(DateTime.parse(ro['created_at'] as String)),
            )),
          ],
          if (_notes.isNotEmpty) ...[
            _SectionHeader(title: 'Notes', count: _notes.length),
            ..._notes.map((note) => _NoteTile(
              note: note,
              timeAgo: _timeAgo(note.createdAt),
            )),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.emerald600.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: AppColors.emerald500,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reach-out tile
// ---------------------------------------------------------------------------

class _ReachOutTile extends StatelessWidget {
  final Map<String, dynamic> reachOut;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final String timeAgo;

  const _ReachOutTile({
    required this.reachOut,
    required this.onAccept,
    required this.onDecline,
    required this.timeAgo,
  });

  @override
  Widget build(BuildContext context) {
    final profile = reachOut['profiles'] as Map<String, dynamic>?;
    final name = profile?['display_name'] as String? ?? 'Someone';
    final photoUrl = profile?['date_avatar_url'] as String?;
    final bio = profile?['bio'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: context.borderSubtleColor),
          boxShadow: Premium.shadowSm,
        ),
        child: Row(
          children: [
            // Avatar
            ClipOval(
              child: photoUrl != null && photoUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: photoUrl,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      memCacheWidth: 120,
                      errorWidget: (_, __, ___) => _RequestAvatarFallback(name: name),
                    )
                  : _RequestAvatarFallback(name: name),
            ),
            const SizedBox(width: 12),
            // Name + bio
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        timeAgo,
                        style: TextStyle(
                          color: context.textDisabled,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  if (bio.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      bio,
                      style: TextStyle(
                        color: context.textMuted,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      // Accept
                      GestureDetector(
                        onTap: onAccept,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppColors.emerald600,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                          ),
                          child: const Text(
                            'Accept',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Decline
                      GestureDetector(
                        onTap: onDecline,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                            border: Border.all(color: context.textMuted.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            'Decline',
                            style: TextStyle(
                              color: context.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Note tile
// ---------------------------------------------------------------------------

class _NoteTile extends StatelessWidget {
  final Note note;
  final String timeAgo;

  const _NoteTile({required this.note, required this.timeAgo});

  @override
  Widget build(BuildContext context) {
    final name = note.senderName ?? 'Someone';
    final photoUrl = note.senderPhotoUrl;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: context.borderSubtleColor),
          boxShadow: Premium.shadowSm,
        ),
        child: Row(
          children: [
            // Avatar
            ClipOval(
              child: photoUrl != null && photoUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: photoUrl,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      memCacheWidth: 120,
                      errorWidget: (_, __, ___) => _RequestAvatarFallback(name: name),
                    )
                  : _RequestAvatarFallback(name: name),
            ),
            const SizedBox(width: 12),
            // Name + content preview
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        timeAgo,
                        style: TextStyle(
                          color: context.textDisabled,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    note.content,
                    style: TextStyle(
                      color: context.textMuted,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (!note.isRead) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.emerald600,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Request avatar fallback
// ---------------------------------------------------------------------------

class _RequestAvatarFallback extends StatelessWidget {
  final String name;
  const _RequestAvatarFallback({required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0] : '?';
    return Container(
      width: 40,
      height: 40,
      color: AppColors.emerald600.withValues(alpha: 0.15),
      child: Center(
        child: Text(
          initial.toUpperCase(),
          style: const TextStyle(
            color: AppColors.emerald500,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state (shared)
// ---------------------------------------------------------------------------

class _EmptyInbox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyInbox({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
          decoration: Premium.emptyStateDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.emerald600.withValues(alpha: 0.10),
                      AppColors.emerald600.withValues(alpha: 0.04),
                    ],
                  ),
                  border: Border.all(
                      color: AppColors.emerald600.withValues(alpha: 0.12),
                      width: 0.5),
                ),
                child: Icon(icon,
                    color: AppColors.emerald600.withValues(alpha: 0.45), size: 24),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  color: context.textMuted,
                  fontSize: 13,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              PressEffect(
                onTap: () => MainTabNavigator.switchTab(0),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.emerald600.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.emerald600.withValues(alpha: 0.20),
                        width: 0.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.explore_outlined,
                          color: AppColors.emerald500, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Explore',
                        style: TextStyle(
                          color: AppColors.emerald500,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
