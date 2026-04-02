import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_tokens.dart';
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
import 'individual_chat_screen.dart';

/// Reads message_preview setting for current user
final _messagePreviewProvider = FutureProvider<bool>((ref) async {
  if (isMockMode) return true;
  final uid = ref.watch(authProvider).userId;
  if (uid == null) return true;
  try {
    final row = await Supabase.instance.client.from('profiles')
        .select('message_preview').eq('id', uid).maybeSingle();
    return row?['message_preview'] as bool? ?? true;
  } catch (_) { return true; }
});

// ---------------------------------------------------------------------------
// Grand Inbox — 3-tab unified messaging hub
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
    lastMessage: _statusLabel(match),
    ago: DateTime.now().difference(match.matchedAt),
    mode: mode,
    type: ConversationType.alliance,
    isUnread: match.status == 'pending_intro' || match.status == 'pending_video',
  );
}

String _statusLabel(NobleMatch match) {
  switch (match.status) {
    case 'pending_intro':
      return 'Send a mini intro';
    case 'pending_video':
      return 'Schedule Short Intro';
    case 'video_scheduled':
      return 'Short Intro scheduled';
    case 'video_completed':
      return 'Awaiting decision';
    case 'chatting':
      return 'Chat is open';
    case 'expired':
      return 'Expired';
    case 'closed':
      return 'Closed';
    default:
      return match.status;
  }
}

class MatchesScreen extends ConsumerStatefulWidget {
  const MatchesScreen({super.key});

  @override
  ConsumerState<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends ConsumerState<MatchesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(matchProvider.notifier).load();
    });
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

    final circles = allMatches
        .where((m) => m.mode == 'social')
        .map(_matchToInboxItem)
        .toList();

    const requests = <InboxItem>[];

    final totalUnread = [
      ...alliances,
      ...circles,
    ].where((i) => i.isUnread).length;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: context.bgColor,
        appBar: AppBar(
          backgroundColor: context.bgColor,
          titleSpacing: AppSpacing.lg,
          title: Row(
            children: [
              Text(
                'Inbox',
                style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              if (totalUnread > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusCircle),
                    border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '$totalUnread new',
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(44),
            child: Container(
              color: context.surfaceColor,
              child: TabBar(
                indicatorColor: AppColors.gold,
                indicatorWeight: 2,
                labelColor: context.textPrimary,
                unselectedLabelColor: context.textMuted,
                labelStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
                unselectedLabelStyle:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
                tabs: [
                  Tab(
                    child: _TabLabel(
                      label: 'Alliances',
                      count: alliances.length,
                      color: AppColors.gold,
                    ),
                  ),
                  Tab(
                    child: _TabLabel(
                      label: 'Circles',
                      count: circles.length,
                      color: NobleMode.social.accentColor,
                    ),
                  ),
                  Tab(
                    child: _TabLabel(
                      label: 'Requests',
                      count: requests.length,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: matchState.isLoading && allMatches.isEmpty
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              )
            : TabBarView(
                children: [
                  _AlliancesTab(
                    items: alliances,
                    matchesByItemId: {
                      for (final m in allMatches
                          .where((m) =>
                              (m.mode == 'date' || m.mode == 'bff') &&
                              m.status != 'expired'))
                        m.id: m,
                    },
                  ),
                  _CirclesTab(circles: circles),
                  _RequestsTab(requests: requests),
                ],
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab label with count badge
// ---------------------------------------------------------------------------

class _TabLabel extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _TabLabel({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        const SizedBox(width: 5),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            '$count',
            style: TextStyle(
                color: color, fontSize: 9, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Alliances tab — Date & BFF 1-on-1 conversations
// ---------------------------------------------------------------------------

class _AlliancesTab extends ConsumerStatefulWidget {
  final List<InboxItem> items;
  final Map<String, NobleMatch> matchesByItemId;
  const _AlliancesTab({required this.items, required this.matchesByItemId});

  @override
  ConsumerState<_AlliancesTab> createState() => _AlliancesTabState();
}

class _AlliancesTabState extends ConsumerState<_AlliancesTab> {
  NobleMode? _filter; // null = All

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
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => CheckInScreen(meetingId: meetingId, otherUserName: 'your match'),
                    ));
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  margin: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.rate_review_rounded, color: AppColors.gold, size: 20),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text('You have a pending check-in. How did it go?',
                            style: TextStyle(color: AppColors.gold, fontSize: 13)),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.gold, size: 18),
                    ],
                  ),
                ),
              ),
            ];
          },
          loading: () => <Widget>[],
          error: (_, __) => <Widget>[],
        ),
        // Mode filter pills
        _FilterRow(
          selected: _filter,
          onAll: () => setState(() => _filter = null),
          onDate: () => setState(
              () => _filter = _filter == NobleMode.date ? null : NobleMode.date),
          onBff: () => setState(
              () => _filter = _filter == NobleMode.bff ? null : NobleMode.bff),
        ),
        Divider(height: 0, color: context.borderColor),
        // Conversation list
        Expanded(
          child: _filtered.isEmpty
              ? _EmptyInbox(
                  icon: Icons.favorite_outline_rounded,
                  message:
                      'No alliances yet.\nStart swiping to make connections.',
                )
              : ListView.separated(
                  itemCount: _filtered.length,
                  separatorBuilder: (context, __) =>
                      Divider(height: 0, color: context.borderColor),
                  itemBuilder: (context, i) {
                    final item = _filtered[i];
                    return _InboxTile(
                      item: item,
                      onTap: () => _onTapItem(context, item),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Circles tab — Social group table conversations
// ---------------------------------------------------------------------------

class _CirclesTab extends StatelessWidget {
  final List<InboxItem> circles;
  const _CirclesTab({required this.circles});

  @override
  Widget build(BuildContext context) {
    if (circles.isEmpty) {
      return _EmptyInbox(
        icon: Icons.explore_outlined,
        message: 'No circles yet.\nJoin a table to start.',
      );
    }
    return ListView.separated(
      itemCount: circles.length,
      separatorBuilder: (context, __) =>
          Divider(height: 0, color: context.borderColor),
      itemBuilder: (context, i) {
        final circle = circles[i];
        return _CircleTile(
          circle: circle,
          onTap: () {
            // TODO: fetch real table from DB by circle.tableId
            ToastService.show(context, message: 'Group chat — coming soon', type: ToastType.system);
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Requests tab — pending connection requests
// ---------------------------------------------------------------------------

class _RequestsTab extends StatelessWidget {
  final List<InboxItem> requests;
  const _RequestsTab({required this.requests});

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return _EmptyInbox(
        icon: Icons.inbox_outlined,
        message: "No pending requests.\nYou're all caught up!",
      );
    }
    return ListView.separated(
      itemCount: requests.length,
      separatorBuilder: (context, __) =>
          Divider(height: 0, color: context.borderColor),
      itemBuilder: (context, i) => _RequestTile(item: requests[i]),
    );
  }
}

// ---------------------------------------------------------------------------
// Mode filter row (Alliances tab)
// ---------------------------------------------------------------------------

class _FilterRow extends StatelessWidget {
  final NobleMode? selected;
  final VoidCallback onAll;
  final VoidCallback onDate;
  final VoidCallback onBff;

  const _FilterRow({
    required this.selected,
    required this.onAll,
    required this.onDate,
    required this.onBff,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Row(
        children: [
          _FilterPill(
              label: 'All',
              isActive: selected == null,
              color: context.textPrimary,
              onTap: onAll),
          const SizedBox(width: AppSpacing.sm),
          _FilterPill(
              label: 'Date',
              isActive: selected == NobleMode.date,
              color: AppColors.gold,
              dot: true,
              onTap: onDate),
          const SizedBox(width: AppSpacing.sm),
          _FilterPill(
              label: 'BFF',
              isActive: selected == NobleMode.bff,
              color: const Color(0xFF26C6DA),
              dot: true,
              onTap: onBff),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color color;
  final bool dot;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.isActive,
    required this.color,
    this.dot = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: isActive
              ? color.withValues(alpha: 0.18)
              : context.surfaceAltColor,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCircle),
          border: Border.all(
              color: isActive
                  ? color.withValues(alpha: 0.55)
                  : context.borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dot) ...[
              Container(
                width: 6,
                height: 6,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: isActive ? color : context.textMuted,
                fontSize: 12,
                fontWeight:
                    isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Inbox conversation tile (alliances)
// ---------------------------------------------------------------------------

class _InboxTile extends StatelessWidget {
  final InboxItem item;
  final VoidCallback onTap;

  const _InboxTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = item.mode.accentColor;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Row(
          children: [
            // Avatar + mode dot
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipOval(
                  child: Image.network(
                    'https://picsum.photos/seed/${item.avatarSeed}/80/80',
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => CircleAvatar(
                      radius: 26,
                      backgroundColor: accent.withValues(alpha: 0.2),
                      child: Text(
                        item.name[0],
                        style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.w700,
                            fontSize: 18),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: context.bgColor, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.md),
            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 15,
                            fontWeight: item.isUnread
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        item.timeLabel,
                        style: TextStyle(
                          color: item.isUnread
                              ? accent
                              : context.textMuted,
                          fontSize: 11,
                          fontWeight: item.isUnread
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  if (item.profession != null)
                    Text(
                      item.profession!,
                      style: TextStyle(
                          color: context.textMuted, fontSize: 11),
                    ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Consumer(builder: (context, cRef, __) {
                          final preview = cRef.watch(_messagePreviewProvider).valueOrNull ?? true;
                          return Text(
                            preview ? item.lastMessage : 'New activity',
                            style: TextStyle(
                              color: item.isUnread
                                  ? context.textSecondary
                                  : context.textMuted,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        }),
                      ),
                      if (item.isUnread)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: accent, shape: BoxShape.circle),
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
// Circle tile (group tables)
// ---------------------------------------------------------------------------

class _CircleTile extends StatelessWidget {
  final InboxItem circle;
  final VoidCallback onTap;

  const _CircleTile({required this.circle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = NobleMode.social.accentColor;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Row(
          children: [
            // Cover thumbnail + mode dot
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusSm),
                  child: Image.network(
                    'https://picsum.photos/seed/${circle.avatarSeed}/80/80',
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 52,
                      height: 52,
                      color: context.surfaceAltColor,
                      child:
                          Icon(Icons.table_bar_rounded, color: accent),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: context.bgColor, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.md),
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
                            fontWeight: circle.isUnread
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        circle.timeLabel,
                        style: TextStyle(
                          color: circle.isUnread
                              ? accent
                              : context.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  if (circle.participantCount != null &&
                      circle.maxParticipants != null)
                    Text(
                      '${circle.participantCount}/${circle.maxParticipants} members',
                      style: TextStyle(
                          color: accent.withValues(alpha: 0.7),
                          fontSize: 11),
                    ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          circle.lastMessage,
                          style: TextStyle(
                            color: circle.isUnread
                                ? context.textSecondary
                                : context.textMuted,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (circle.isUnread)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: accent, shape: BoxShape.circle),
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
// Request tile (pending connections)
// ---------------------------------------------------------------------------

class _RequestTile extends StatelessWidget {
  final InboxItem item;

  const _RequestTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final accent = item.mode.accentColor;

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Row(
        children: [
          // Avatar + mode dot
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipOval(
                child: Image.network(
                  'https://picsum.photos/seed/${item.avatarSeed}/80/80',
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => CircleAvatar(
                    radius: 26,
                    backgroundColor: accent.withValues(alpha: 0.2),
                    child: Text(
                      item.name[0],
                      style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w700,
                          fontSize: 18),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: context.bgColor, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          // Name + message
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600),
                ),
                if (item.profession != null)
                  Text(
                    item.profession!,
                    style: TextStyle(
                        color: context.textMuted, fontSize: 11),
                  ),
                const SizedBox(height: 2),
                Text(
                  item.lastMessage,
                  style: TextStyle(
                      color: accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Accept / Decline
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () => ToastService.show(context, message: '${item.name} accepted!', type: ToastType.match),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusCircle),
                  ),
                  child: Text(
                    'Accept',
                    style: TextStyle(
                        color: context.bgColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              GestureDetector(
                onTap: () {},
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  decoration: BoxDecoration(
                    border: Border.all(color: context.borderColor),
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusCircle),
                  ),
                  child: Text(
                    'Decline',
                    style: TextStyle(
                        color: context.textMuted, fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyInbox extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyInbox({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: context.textDisabled, size: 48),
          const SizedBox(height: AppSpacing.lg),
          Text(
            message,
            style: TextStyle(
                color: context.textMuted, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
