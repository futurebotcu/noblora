import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
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

class StatusScreen extends ConsumerStatefulWidget {
  const StatusScreen({super.key});
  @override
  ConsumerState<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends ConsumerState<StatusScreen> {
  bool _animate = false;
  String? _aiText;
  bool _aiLoading = false;

  // Lazy-loaded data
  int _nobReactionsReceived = 0;
  int _notesReceived = 0;
  int _signalsReceived = 0;
  int _connectionsCount = 0;
  bool _dataLoaded = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _animate = true);
    });
  }

  Future<void> _loadExtraData() async {
    if (_dataLoaded || isMockMode) { _dataLoaded = true; return; }
    final uid = ref.read(authProvider).userId;
    if (uid == null) return;
    try {
      // Reactions on my posts
      final reactions = await Supabase.instance.client
          .from('post_reactions')
          .select('id')
          .inFilter('post_id', (await Supabase.instance.client
              .from('posts').select('id').eq('user_id', uid)).map((r) => r['id'] as String).toList());
      _nobReactionsReceived = reactions.length;

      // Notes received
      final notes = await Supabase.instance.client
          .from('notes').select('id').eq('receiver_id', uid);
      _notesReceived = notes.length;

      // Signals received
      final signals = await Supabase.instance.client
          .from('signals').select('id').eq('receiver_id', uid);
      _signalsReceived = signals.length;

      // Connections
      final matches = await Supabase.instance.client
          .from('matches').select('id')
          .or('user1_id.eq.$uid,user2_id.eq.$uid')
          .neq('status', 'expired').neq('status', 'closed');
      _connectionsCount = matches.length;

      _dataLoaded = true;
      if (mounted) setState(() {});
    } catch (_) { _dataLoaded = true; }
  }

  Future<void> _loadAi(Profile p) async {
    if (_aiLoading || _aiText != null) return;
    _aiLoading = true;
    try {
      _aiText = await GeminiService.getTierExplanation(
        tier: p.nobTier.name,
        profileCompleteness: p.profileCompletenessScore,
        communityScore: p.communityScore,
        depthScore: p.depthScore,
        followThrough: p.followThroughScore,
      );
    } catch (_) {
      _aiText = 'Keep engaging — your profile grows with every interaction.';
    }
    if (mounted) setState(() => _aiLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(profileProvider).profile;
    final matchState = ref.watch(matchProvider);
    final bffState = ref.watch(bffProvider);
    final eventState = ref.watch(eventListProvider);
    final notifState = ref.watch(notificationProvider);

    if (p == null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(backgroundColor: AppColors.bg, surfaceTintColor: Colors.transparent,
            title: const Text('Status', style: TextStyle(color: AppColors.textPrimary))),
        body: const Center(child: CircularProgressIndicator(color: AppColors.gold)),
      );
    }

    if (!_dataLoaded) WidgetsBinding.instance.addPostFrameCallback((_) => _loadExtraData());
    if (_aiText == null && !_aiLoading) WidgetsBinding.instance.addPostFrameCallback((_) => _loadAi(p));

    final tierColor = switch (p.nobTier) {
      NobTier.noble => AppColors.gold,
      NobTier.explorer => const Color(0xFF26C6DA),
      NobTier.observer => AppColors.textMuted,
    };

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(backgroundColor: AppColors.bg, surfaceTintColor: Colors.transparent,
          title: const Text('Your Status', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700))),
      body: RefreshIndicator(
        color: AppColors.gold,
        onRefresh: () async {
          _dataLoaded = false;
          _aiText = null;
          await _loadExtraData();
          await _loadAi(p);
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.md),
          children: [
            // ═══ BLOCK 1: TIER HERO ═══
            _TierHero(p: p, tierColor: tierColor, animate: _animate),
            const SizedBox(height: AppSpacing.xxl),

            // ═══ BLOCK 2: GROWTH SIGNALS ═══
            _SectionTitle('Profile Growth'),
            const SizedBox(height: AppSpacing.md),
            _GrowthBar('Profile', p.profileCompletenessScore / 100, tierColor, _animate),
            _GrowthBar('Community', p.communityScore / 100, tierColor, _animate),
            _GrowthBar('Depth', p.depthScore / 100, tierColor, _animate),
            _GrowthBar('Trust', p.trustScore / 100, tierColor, _animate),
            _GrowthBar('Follow-through', p.followThroughScore / 100, tierColor, _animate),
            _GrowthBar('Activity', p.vitalityScore / 100, tierColor, _animate),
            const SizedBox(height: AppSpacing.xxl),

            // ═══ BLOCK 3: TIPS ═══
            if (p.profileTips.isNotEmpty) ...[
              _SectionTitle('Next Steps'),
              const SizedBox(height: AppSpacing.sm),
              ...p.profileTips.take(3).map((t) => _TipRow(t)),
              const SizedBox(height: AppSpacing.xxl),
            ],

            // ═══ BLOCK 4: NOB INTERACTIONS ═══
            _SectionTitle('Nob Activity'),
            const SizedBox(height: AppSpacing.sm),
            _StatRow(Icons.favorite_outline_rounded, 'Reactions on your Nobs', '$_nobReactionsReceived'),
            _StatRow(Icons.mail_outline_rounded, 'Notes received', '$_notesReceived'),
            _StatRow(Icons.push_pin_rounded, 'Pinned Nob', p.profileCompletenessScore >= 20 ? 'Active' : 'Not yet'),
            const SizedBox(height: AppSpacing.xxl),

            // ═══ BLOCK 5: DATING INTEREST ═══
            _SectionTitle('Dating Activity'),
            const SizedBox(height: AppSpacing.sm),
            _StatRow(Icons.bolt_rounded, 'Signals received', '$_signalsReceived'),
            _StatRow(Icons.favorite_rounded, 'Active connections', '$_connectionsCount'),
            _StatRow(Icons.videocam_rounded, 'Pending intros',
                '${matchState.matches.where((m) => m.mode == "date" && (m.status == "pending_intro" || m.status == "pending_video")).length}'),
            const SizedBox(height: AppSpacing.xxl),

            // ═══ BLOCK 6: BFF / SOCIAL ═══
            _SectionTitle('BFF & Social'),
            const SizedBox(height: AppSpacing.sm),
            _StatRow(Icons.people_rounded, 'BFF suggestions', '${bffState.suggestions.length}'),
            _StatRow(Icons.waving_hand_rounded, 'Reach outs received', '${bffState.reachOuts.length}'),
            _StatRow(Icons.event_rounded, 'Upcoming events', '${eventState.events.length}'),
            const SizedBox(height: AppSpacing.xxl),

            // ═══ BLOCK 7: UPCOMING / PLANS ═══
            if (matchState.matches.isNotEmpty || eventState.events.isNotEmpty) ...[
              _SectionTitle('Coming Up'),
              const SizedBox(height: AppSpacing.sm),
              ...matchState.matches
                  .where((m) => m.status == 'video_scheduled')
                  .take(2)
                  .map((m) => _UpcomingCard(
                      icon: Icons.videocam_rounded,
                      title: 'Short Intro with ${m.otherUserName ?? "match"}',
                      subtitle: 'Scheduled',
                      color: AppColors.gold)),
              ...eventState.events
                  .take(2)
                  .map((e) => _UpcomingCard(
                      icon: Icons.event_rounded,
                      title: e.title,
                      subtitle: '${e.timeLabel} · ${e.locationText ?? ""}',
                      color: const Color(0xFFAB47BC))),
              const SizedBox(height: AppSpacing.xxl),
            ],

            // ═══ BLOCK 8: ATTENTION SUMMARY ═══
            if (notifState.notifications.isNotEmpty) ...[
              _SectionTitle('Recent Activity'),
              const SizedBox(height: AppSpacing.sm),
              ...notifState.notifications.take(5).map((n) => _AttentionRow(
                  title: n.title,
                  subtitle: n.body,
                  time: _timeAgo(n.createdAt),
                  isUnread: n.isUnread)),
              const SizedBox(height: AppSpacing.xxl),
            ],

            // ═══ BLOCK 9: AI GUIDE ═══
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: tierColor.withValues(alpha: 0.2))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.auto_awesome_rounded, color: tierColor, size: 16),
                  const SizedBox(width: AppSpacing.sm),
                  Text('Noblara Guide', style: TextStyle(color: tierColor, fontSize: 13, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: AppSpacing.md),
                if (_aiLoading)
                  const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold)))
                else
                  Text(_aiText ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5)),
              ]),
            ),
            const SizedBox(height: AppSpacing.xxl),

            // ═══ BLOCK 10: QUICK ACTIONS ═══
            _SectionTitle('Quick Actions'),
            const SizedBox(height: AppSpacing.sm),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _QuickAction(Icons.edit_rounded, 'Add Nob', () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const NobComposeScreen()))),
                _QuickAction(Icons.mail_outline_rounded, 'Notes', () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const NoteInboxScreen()))),
                _QuickAction(Icons.tune_rounded, 'Filters', () => Navigator.pop(context)),
              ]),
            ),
            const SizedBox(height: AppSpacing.xxxxl),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    return '${d.inDays}d';
  }
}

// ═══════════════════════════════════════════════════════════════════
// Tier Hero block
// ═══════════════════════════════════════════════════════════════════

class _TierHero extends StatelessWidget {
  final Profile p; final Color tierColor; final bool animate;
  const _TierHero({required this.p, required this.tierColor, required this.animate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: tierColor.withValues(alpha: 0.15)),
      ),
      child: Column(children: [
        TierBadge(tier: p.nobTier, size: 48),
        const SizedBox(height: AppSpacing.md),
        Text(p.nobTier.label, style: TextStyle(color: tierColor, fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.xs),
        Text(p.strengthLabel, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        const SizedBox(height: AppSpacing.lg),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: animate ? (p.maturityScore / 100).clamp(0, 1) : 0),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => LinearProgressIndicator(value: v, minHeight: 6,
                backgroundColor: AppColors.surfaceAlt, valueColor: AlwaysStoppedAnimation(tierColor)),
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Shared widgets
// ═══════════════════════════════════════════════════════════════════

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600));
}

class _GrowthBar extends StatelessWidget {
  final String label; final double value; final Color color; final bool animate;
  const _GrowthBar(this.label, this.value, this.color, this.animate);

  String get _q => value >= 0.8 ? 'Strong' : value >= 0.5 ? 'Good' : value >= 0.2 ? 'Growing' : 'New';

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.only(bottom: AppSpacing.sm), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const Spacer(),
        Text(_q, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
      ]),
      const SizedBox(height: 3),
      ClipRRect(borderRadius: BorderRadius.circular(2),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: animate ? value.clamp(0, 1) : 0),
          duration: const Duration(milliseconds: 1000), curve: Curves.easeOutCubic,
          builder: (_, v, __) => LinearProgressIndicator(value: v, minHeight: 3,
              backgroundColor: AppColors.surfaceAlt, valueColor: AlwaysStoppedAnimation(color)))),
    ]));
  }
}

class _TipRow extends StatelessWidget {
  final String text;
  const _TipRow(this.text);
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.lightbulb_outline_rounded, color: AppColors.gold, size: 15),
      const SizedBox(width: AppSpacing.sm),
      Expanded(child: Text(text, style: const TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.4))),
    ]));
}

class _StatRow extends StatelessWidget {
  final IconData icon; final String label; final String value;
  const _StatRow(this.icon, this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Row(children: [
      Icon(icon, color: AppColors.textMuted, size: 16),
      const SizedBox(width: AppSpacing.md),
      Expanded(child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
      Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
    ]));
}

class _UpcomingCard extends StatelessWidget {
  final IconData icon; final String title; final String subtitle; final Color color;
  const _UpcomingCard({required this.icon, required this.title, required this.subtitle, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.15))),
    child: Row(children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(width: AppSpacing.md),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
      ])),
    ]),
  );
}

class _AttentionRow extends StatelessWidget {
  final String title; final String subtitle; final String time; final bool isUnread;
  const _AttentionRow({required this.title, required this.subtitle, required this.time, this.isUnread = false});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Row(children: [
      if (isUnread) Container(width: 6, height: 6, margin: const EdgeInsets.only(right: 8),
          decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle)),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(color: AppColors.textPrimary, fontSize: 13,
            fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400)),
        Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
      ])),
      Text(time, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
    ]));
}

class _QuickAction extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap;
  const _QuickAction(this.icon, this.label, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(right: AppSpacing.md),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          border: Border.all(color: AppColors.border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: AppColors.gold, size: 16),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12)),
      ]),
    ));
}
