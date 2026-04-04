import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/mock_mode.dart';
import '../../data/models/post.dart';
import '../../data/models/profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/match_provider.dart';
import '../../providers/bff_provider.dart';
import '../../providers/event_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/profile_provider.dart';
import '../../shared/widgets/tier_badge.dart';
import '../../services/gemini_service.dart';
import '../noblara_feed/nob_compose_screen.dart';
import '../noblara_feed/note_inbox_screen.dart';

// ═══════════════════════════════════════════════════════════════════
// Status Hub — 5-tab private master panel
// ═══════════════════════════════════════════════════════════════════

class StatusScreen extends ConsumerStatefulWidget {
  const StatusScreen({super.key});
  @override
  ConsumerState<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends ConsumerState<StatusScreen> with TickerProviderStateMixin {
  late final TabController _tabs;
  bool _animate = false;
  String? _ai;
  bool _aiLoading = false;

  // Lazy data
  int _notesReceived = 0;
  int _signalsReceived = 0;
  int _signalsSent = 0;
  int _notesSent = 0;
  int _connectionCount = 0;
  List<Map<String, dynamic>> _recentActivity = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _animate = true);
    });
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _loadData() async {
    if (_loaded || isMockMode) { _loaded = true; return; }
    final uid = ref.read(authProvider).userId;
    if (uid == null) return;
    try {
      final c = Supabase.instance.client;
      _notesReceived = (await c.from('notes').select('id').eq('receiver_id', uid)).length;
      _notesSent = (await c.from('notes').select('id').eq('sender_id', uid)).length;
      _signalsReceived = (await c.from('signals').select('id').eq('receiver_id', uid)).length;
      _signalsSent = (await c.from('signals').select('id').eq('sender_id', uid)).length;
      _connectionCount = (await c.from('matches').select('id').or('user1_id.eq.$uid,user2_id.eq.$uid')
          .neq('status', 'expired').neq('status', 'closed')).length;

      // Recent activity from notifications
      final notifs = await c.from('notifications').select().eq('user_id', uid)
          .order('created_at', ascending: false).limit(20);
      _recentActivity = List<Map<String, dynamic>>.from(notifs);

      _loaded = true;
      if (mounted) setState(() {});
    } catch (_) { _loaded = true; }
  }

  Future<void> _loadAi(Profile p) async {
    if (_aiLoading || _ai != null) return;
    _aiLoading = true;
    try {
      _ai = await GeminiService.getTierExplanation(
        tier: p.nobTier.name, profileCompleteness: p.profileCompletenessScore,
        communityScore: p.communityScore, depthScore: p.depthScore, followThrough: p.followThroughScore);
    } catch (_) {
      _ai = '[AI unavailable] Keep engaging — your profile grows naturally.';
    }
    if (mounted) setState(() => _aiLoading = false);
  }

  String _statusLine(Profile p) {
    final n = ref.read(notificationProvider).notifications.where((n) => n.isUnread).length;
    if (n > 0) return '$n new things in your world.';
    if (p.maturityScore > 60) return 'Quiet momentum. Growing steadily.';
    if (p.maturityScore > 30) return 'Building up. A few things moving.';
    return 'Your private overview.';
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(profileProvider).profile;
    if (p == null) {
      return Scaffold(backgroundColor: context.bgColor,
          body: Center(child: CircularProgressIndicator(color: AppColors.emerald500)));
    }
    if (!_loaded) WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
    if (_ai == null && !_aiLoading) WidgetsBinding.instance.addPostFrameCallback((_) => _loadAi(p));

    final tc = switch (p.nobTier) { NobTier.noble => AppColors.emerald500, NobTier.explorer => AppColors.info, NobTier.observer => context.textMuted };

    return Scaffold(
      backgroundColor: context.bgColor,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, inner) => [
          SliverAppBar(
            backgroundColor: context.bgColor, surfaceTintColor: Colors.transparent, pinned: true, floating: false,
            expandedHeight: 120, collapsedHeight: 60,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [tc.withValues(alpha: 0.04), context.bgColor]),
                ),
                padding: EdgeInsets.fromLTRB(AppSpacing.xxl, MediaQuery.of(ctx).padding.top + 12, AppSpacing.xxl, 0),
                child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: tc.withValues(alpha: 0.08),
                      border: Border.all(color: tc.withValues(alpha: 0.2), width: 1.5),
                    ),
                    child: Center(child: Text((p.displayName.isNotEmpty ? p.displayName[0] : 'N').toUpperCase(),
                        style: TextStyle(color: tc, fontWeight: FontWeight.w700, fontSize: 18))),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(p.displayName.isNotEmpty ? p.displayName : 'You',
                        style: TextStyle(color: context.textPrimary, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                    const SizedBox(height: 2),
                    Text(_statusLine(p), style: TextStyle(color: context.textMuted, fontSize: 12, letterSpacing: 0.1)),
                  ])),
                  TierBadge(tier: p.nobTier, size: 28, showLabel: true),
                ]),
              ),
            ),
            bottom: TabBar(controller: _tabs, isScrollable: true,
              indicatorColor: tc, indicatorWeight: 2,
              labelColor: tc, unselectedLabelColor: context.textDisabled,
              dividerColor: context.borderSubtleColor, tabAlignment: TabAlignment.start,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.3),
              unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
              tabs: const [Tab(text: 'Overview'), Tab(text: 'Interest'), Tab(text: 'Social'), Tab(text: 'Activity'), Tab(text: 'Market')],
            ),
          ),
        ],
        body: TabBarView(controller: _tabs, children: [
          _OverviewTab(p: p, tc: tc, animate: _animate, ai: _ai, aiLoading: _aiLoading,
            matchState: ref.watch(matchProvider), eventState: ref.watch(eventListProvider)),
          _InterestTab(p: p, tc: tc, matchState: ref.watch(matchProvider),
            signalsReceived: _signalsReceived, signalsSent: _signalsSent,
            notesReceived: _notesReceived, notesSent: _notesSent, connections: _connectionCount),
          _SocialTab(bffState: ref.watch(bffProvider), eventState: ref.watch(eventListProvider)),
          _ActivityTab(activity: _recentActivity),
          const _MarketTab(),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// TAB 1: OVERVIEW
// ═══════════════════════════════════════════════════════════════════

class _OverviewTab extends StatelessWidget {
  final Profile p; final Color tc; final bool animate; final String? ai; final bool aiLoading;
  final MatchListState matchState; final EventListState eventState;
  const _OverviewTab({required this.p, required this.tc, required this.animate,
      this.ai, this.aiLoading = false, required this.matchState, required this.eventState});

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(AppSpacing.xxl), children: [
      // Hero
      _Card(child: Column(children: [
        TierBadge(tier: p.nobTier, size: 44),
        const SizedBox(height: AppSpacing.md),
        Text(p.nobTier.label, style: TextStyle(color: tc, fontSize: 20, fontWeight: FontWeight.w700)),
        Text(p.strengthLabel, style: TextStyle(color: context.textMuted, fontSize: 12)),
        const SizedBox(height: AppSpacing.md),
        _Bar(value: (p.maturityScore / 100).clamp(0, 1), color: tc, animate: animate, height: 6),
      ])),
      const SizedBox(height: AppSpacing.xxl),

      // Growth
      _Sec('Where you stand'),
      _GrowthRow('Profile', p.profileCompletenessScore / 100, tc, animate),
      _GrowthRow('Community', p.communityScore / 100, tc, animate),
      _GrowthRow('Depth', p.depthScore / 100, tc, animate),
      _GrowthRow('Trust', p.trustScore / 100, tc, animate),
      _GrowthRow('Follow-through', p.followThroughScore / 100, tc, animate),
      _GrowthRow('Activity', p.vitalityScore / 100, tc, animate),
      const SizedBox(height: AppSpacing.xxl),

      // Tips
      if (p.profileTips.isNotEmpty) ...[
        _Sec('What would help next'),
        ...p.profileTips.take(3).map((t) => _Tip(t)),
        const SizedBox(height: AppSpacing.xxl),
      ],

      // Upcoming
      if (matchState.matches.any((m) => m.status == 'video_scheduled') || eventState.events.isNotEmpty) ...[
        _Sec('Coming up'),
        ...matchState.matches.where((m) => m.status == 'video_scheduled').take(2).map((m) =>
            _Upcoming(Icons.videocam_rounded, 'Intro with ${m.otherUserName ?? "match"}', 'Scheduled', AppColors.emerald500)),
        ...eventState.events.take(2).map((e) =>
            _Upcoming(Icons.event_rounded, e.title, '${e.timeLabel} · ${e.locationText ?? ""}', const Color(0xFFAB47BC))),
        const SizedBox(height: AppSpacing.xxl),
      ],

      // AI Guide
      _Card(borderColor: AppColors.emerald600.withValues(alpha: 0.25), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(Icons.auto_awesome_rounded, color: tc, size: 16), const SizedBox(width: 6),
          Text('Your guide', style: TextStyle(color: tc, fontSize: 13, fontWeight: FontWeight.w600))]),
        const SizedBox(height: AppSpacing.md),
        if (aiLoading) const SizedBox(height: 30, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.emerald500)))
        else Text(ai ?? '', style: TextStyle(color: context.textSecondary, fontSize: 13, height: 1.5)),
      ])),
      const SizedBox(height: AppSpacing.xxl),

      // Quick Actions
      _Sec('Quick Actions'),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
        _QA(Icons.edit_rounded, 'Add Nob', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NobComposeScreen()))),
        _QA(Icons.mail_outline_rounded, 'Notes', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NoteInboxScreen()))),
      ])),
      const SizedBox(height: AppSpacing.xxxxl),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════
// TAB 2: INTEREST (discreet dating/connection interest)
// ═══════════════════════════════════════════════════════════════════

class _InterestTab extends StatelessWidget {
  final Profile p; final Color tc; final MatchListState matchState;
  final int signalsReceived, signalsSent, notesReceived, notesSent, connections;
  const _InterestTab({required this.p, required this.tc, required this.matchState,
      required this.signalsReceived, required this.signalsSent, required this.notesReceived,
      required this.notesSent, required this.connections});

  @override
  Widget build(BuildContext context) {
    final pending = matchState.matches.where((m) => m.mode == 'date' && (m.status == 'pending_intro' || m.status == 'pending_video')).length;
    final chatting = matchState.matches.where((m) => m.mode == 'date' && m.status == 'chatting').length;

    final hasAny = signalsReceived + notesReceived + pending + signalsSent + notesSent + connections + chatting > 0;

    return ListView(padding: const EdgeInsets.all(AppSpacing.xxl), children: [
      if (!hasAny) ...[
        const SizedBox(height: AppSpacing.xxxxl),
        Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.radio_button_unchecked_rounded, color: context.textMuted.withValues(alpha: 0.2), size: 48),
          const SizedBox(height: AppSpacing.lg),
          Text('Quiet for now', style: TextStyle(color: context.textMuted, fontSize: 14)),
          const SizedBox(height: AppSpacing.xs),
          Text('Interest will appear as people engage with you.', style: TextStyle(color: context.textMuted.withValues(alpha: 0.6), fontSize: 12)),
        ])),
      ] else ...[
        _Sec('Reaching toward you'),
        _Stat(Icons.bolt_rounded, 'Signals', '$signalsReceived'),
        _Stat(Icons.mail_outline_rounded, 'Notes', '$notesReceived'),
        if (pending > 0) _Stat(Icons.schedule_rounded, 'Intros waiting', '$pending'),
        const SizedBox(height: AppSpacing.xxl),

        _Sec('Your movement'),
        _Stat(Icons.bolt_outlined, 'Signals sent', '$signalsSent'),
        _Stat(Icons.mail_outlined, 'Notes sent', '$notesSent'),
        const SizedBox(height: AppSpacing.xxl),

        _Sec('Open threads'),
        _Stat(Icons.people_outline_rounded, 'Connections', '$connections'),
        if (chatting > 0) _Stat(Icons.chat_bubble_outline_rounded, 'Conversations', '$chatting'),
        if (pending > 0) _Stat(Icons.videocam_outlined, 'Pending intros', '$pending'),
      ],
      const SizedBox(height: AppSpacing.xxxxl),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════
// TAB 3: SOCIAL (BFF + Events)
// ═══════════════════════════════════════════════════════════════════

class _SocialTab extends StatelessWidget {
  final BffState bffState; final EventListState eventState;
  const _SocialTab({required this.bffState, required this.eventState});

  @override
  Widget build(BuildContext context) {
    final hasAny = bffState.suggestions.isNotEmpty || bffState.reachOuts.isNotEmpty || eventState.events.isNotEmpty;

    return ListView(padding: const EdgeInsets.all(AppSpacing.xxl), children: [
      if (!hasAny) ...[
        const SizedBox(height: AppSpacing.xxxxl),
        Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.groups_outlined, color: context.textMuted.withValues(alpha: 0.2), size: 48),
          const SizedBox(height: AppSpacing.lg),
          Text('Nothing scheduled right now', style: TextStyle(color: context.textMuted, fontSize: 14)),
          const SizedBox(height: AppSpacing.xs),
          Text('Social plans and BFF activity will show here.', style: TextStyle(color: context.textMuted.withValues(alpha: 0.6), fontSize: 12)),
        ])),
      ] else ...[
        _Sec('Friendship circle'),
        _Stat(Icons.auto_awesome_rounded, 'Suggestions for you', '${bffState.suggestions.length}'),
        if (bffState.reachOuts.isNotEmpty)
          _Stat(Icons.waving_hand_rounded, 'Reach outs', '${bffState.reachOuts.length}'),
        const SizedBox(height: AppSpacing.xxl),

        _Sec('Your events'),
        _Stat(Icons.event_rounded, 'Upcoming', '${eventState.events.length}'),
        if (eventState.events.isNotEmpty)
          ...eventState.events.take(3).map((e) =>
              _Upcoming(Icons.event_rounded, e.title, '${e.timeLabel} \u00B7 ${e.attendeeCount}/${e.maxAttendees}', const Color(0xFFAB47BC))),
      ],
      const SizedBox(height: AppSpacing.xxxxl),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════
// TAB 4: ACTIVITY (private movement log)
// ═══════════════════════════════════════════════════════════════════

class _ActivityTab extends StatelessWidget {
  final List<Map<String, dynamic>> activity;
  const _ActivityTab({required this.activity});

  @override
  Widget build(BuildContext context) {
    if (activity.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.history_rounded, color: context.textMuted.withValues(alpha: 0.2), size: 48),
        const SizedBox(height: AppSpacing.lg),
        Text('This space is clear', style: TextStyle(color: context.textMuted, fontSize: 14)),
        const SizedBox(height: AppSpacing.xs),
        Text('Your recent movement will appear here.', style: TextStyle(color: context.textMuted.withValues(alpha: 0.6), fontSize: 12)),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      itemCount: activity.length,
      itemBuilder: (_, i) {
        final a = activity[i];
        final dt = DateTime.tryParse(a['created_at'] as String? ?? '');
        return Padding(padding: const EdgeInsets.only(bottom: AppSpacing.md), child: Row(children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(
            color: a['read_at'] == null ? AppColors.emerald500 : context.borderColor, shape: BoxShape.circle)),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a['title'] as String? ?? '', style: TextStyle(color: context.textPrimary, fontSize: 13)),
            Text(a['body'] as String? ?? '', style: TextStyle(color: context.textMuted, fontSize: 11),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          if (dt != null) Text(_ago(dt), style: TextStyle(color: context.textMuted, fontSize: 10)),
        ]));
      },
    );
  }

  String _ago(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    return '${d.inDays}d';
  }
}

// ═══════════════════════════════════════════════════════════════════
// TAB 5: MARKET (premium empty shell)
// ═══════════════════════════════════════════════════════════════════

class _MarketTab extends StatelessWidget {
  const _MarketTab();

  @override
  Widget build(BuildContext context) {
    return Center(child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.emerald500.withValues(alpha: 0.04),
            border: Border.all(color: AppColors.emerald500.withValues(alpha: 0.1)),
            boxShadow: [BoxShadow(color: AppColors.emerald500.withValues(alpha: 0.05), blurRadius: 40)],
          ),
          child: const Icon(Icons.diamond_outlined, color: AppColors.emerald500, size: 30),
        ),
        const SizedBox(height: AppSpacing.xxxl),
        Text('Market', style: TextStyle(color: AppColors.emerald500.withValues(alpha: 0.5), fontSize: 20, fontWeight: FontWeight.w300, letterSpacing: 3)),
        const SizedBox(height: AppSpacing.md),
        Text('Reserved for private tools and access.',
            style: TextStyle(color: context.textMuted.withValues(alpha: 0.5), fontSize: 13),
            textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.sm),
        Text('This space will stay quiet until it matters.',
            style: TextStyle(color: context.textMuted.withValues(alpha: 0.35), fontSize: 11),
            textAlign: TextAlign.center),
      ]),
    ));
  }
}

// ═══════════════════════════════════════════════════════════════════
// Shared widgets
// ═══════════════════════════════════════════════════════════════════

class _Card extends StatelessWidget {
  final Widget child; final Color? borderColor;
  const _Card({required this.child, this.borderColor});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.xxl),
    decoration: BoxDecoration(
      color: context.surfaceColor,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      border: Border.all(color: borderColor ?? context.borderSubtleColor, width: 0.5),
      boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 24, offset: Offset(0, 8))],
    ),
    child: child);
}

class _Sec extends StatelessWidget {
  final String t; const _Sec(this.t);
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(t, style: TextStyle(color: context.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)));
}

class _Bar extends StatelessWidget {
  final double value; final Color color; final bool animate; final double height;
  const _Bar({required this.value, required this.color, required this.animate, this.height = 4});
  @override
  Widget build(BuildContext context) => ClipRRect(borderRadius: BorderRadius.circular(height / 2),
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: animate ? value : 0), duration: const Duration(milliseconds: 900), curve: Curves.easeOutCubic,
      builder: (_, v, __) => LinearProgressIndicator(value: v, minHeight: height,
          backgroundColor: context.surfaceAltColor, valueColor: AlwaysStoppedAnimation(color))));
}

class _GrowthRow extends StatelessWidget {
  final String label; final double value; final Color color; final bool animate;
  const _GrowthRow(this.label, this.value, this.color, this.animate);
  String get _q => value >= 0.8 ? 'Solid' : value >= 0.5 ? 'Healthy' : value >= 0.2 ? 'Building' : 'Early';
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Text(label, style: TextStyle(color: context.textSecondary, fontSize: 11)),
        const Spacer(), Text(_q, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w500))]),
      const SizedBox(height: 2),
      _Bar(value: value.clamp(0, 1), color: color, animate: animate, height: 3),
    ]));
}

class _Tip extends StatelessWidget {
  final String t; const _Tip(this.t);
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.lightbulb_outline_rounded, color: AppColors.emerald500, size: 14),
      const SizedBox(width: AppSpacing.sm),
      Expanded(child: Text(t, style: TextStyle(color: context.textMuted, fontSize: 12, height: 1.4))),
    ]));
}

class _Stat extends StatelessWidget {
  final IconData icon; final String label; final String value;
  const _Stat(this.icon, this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Row(children: [Icon(icon, color: context.textMuted, size: 16), const SizedBox(width: AppSpacing.md),
      Expanded(child: Text(label, style: TextStyle(color: context.textSecondary, fontSize: 13))),
      Text(value, style: TextStyle(color: context.textPrimary, fontSize: 13, fontWeight: FontWeight.w600))]));
}

class _Upcoming extends StatelessWidget {
  final IconData icon; final String title; final String sub; final Color color;
  const _Upcoming(this.icon, this.title, this.sub, this.color);
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.12))),
    child: Row(children: [Icon(icon, color: color, size: 18), const SizedBox(width: AppSpacing.md),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(color: context.textPrimary, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(sub, style: TextStyle(color: context.textMuted, fontSize: 11))]))]),
  );
}

class _QA extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap;
  const _QA(this.icon, this.label, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap, child: Container(
    margin: const EdgeInsets.only(right: AppSpacing.md),
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
    decoration: BoxDecoration(color: context.surfaceColor, borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: context.borderColor)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: AppColors.emerald500, size: 15), const SizedBox(width: 6),
      Text(label, style: TextStyle(color: context.textPrimary, fontSize: 12))])));
}
