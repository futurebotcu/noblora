import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_tokens.dart';
import '../core/utils/mock_mode.dart';
import '../providers/auth_provider.dart';
import '../services/push_notification_service.dart';
import '../features/admin/admin_screen.dart';
import '../features/feed/feed_screen.dart';
import '../features/matches/matches_screen.dart';
import '../features/noblara_feed/noblara_feed_screen.dart';
import '../features/status/status_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/profile/tier_promotion_screen.dart';
import '../features/verification/verification_hub_screen.dart';
import '../features/entry_gate/entry_gate_screen.dart';
import '../data/models/post.dart';
import '../providers/messages_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/posts_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/verification_provider.dart';
import '../providers/gating_provider.dart';
import '../core/services/toast_service.dart';

class MainTabNavigator extends ConsumerStatefulWidget {
  const MainTabNavigator({super.key});

  static final navigatorKey = GlobalKey<_MainTabNavigatorState>();

  /// Switch to a tab by index from anywhere in the app.
  static void switchTab(int index) {
    navigatorKey.currentState?._switchTo(index);
  }

  @override
  ConsumerState<MainTabNavigator> createState() => _MainTabNavigatorState();
}

class _MainTabNavigatorState extends ConsumerState<MainTabNavigator> {
  // Tabs that require verification + entry-gate approval before access.
  // Noblara (1), Status (3), Profile (4) are always open.
  static const _secureTabs = {0, 2}; // Discover, Chats

  int _currentIndex = 0;
  // Tracks which tab indices have been visited — unvisited tabs are not built
  final Set<int> _visitedTabs = {0};
  static bool _welcomeShown = false;

  @override
  void initState() {
    super.initState();
    // If verification or entry-gate is still pending, land on Noblara (the
    // open expression layer) instead of Discover. User can still tap secure
    // tabs and will be shown the gate prompt.
    final verif = ref.read(verificationProvider);
    final gating = ref.read(gatingProvider);
    if (_needsSecureGate(verif, gating)) {
      _currentIndex = 1;
      _visitedTabs
        ..clear()
        ..add(1);
    }

    // Push notification tap routing
    PushNotificationService.onNotificationTapped = _handleNotificationTap;
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    final type = data['type'] as String? ?? '';
    switch (type) {
      case 'new_message':
      case 'chat_opened':
        _switchTo(2); // Chats tab
      case 'video_proposed':
      case 'video_confirmed':
        _switchTo(2); // Chats tab (scheduling is inside chat)
      case 'note_received':
      case 'signal_received':
        _switchTo(2); // Requests tab inside Chats
      case 'tier_promoted':
        _switchTo(4); // Profile tab
      default:
        _switchTo(2); // Default to Chats
    }
  }

  bool _needsSecureGate(VerificationState verif, GatingState gating) {
    return verif.verificationStatus != VerificationStatus.approved ||
        !gating.isEntryApproved;
  }

  void _showWelcomeToast() {
    final name = ref.read(profileProvider).profile?.displayName;
    if (name == null || name.trim().isEmpty) return;
    final firstName = name.trim().split(' ').first;
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      ToastService.show(context, message: 'Welcome back, $firstName', type: ToastType.system);
    });
  }

  void _switchTo(int index) {
    // Respect the same security gate programmatic switches rely on.
    if (_secureTabs.contains(index)) {
      final verif = ref.read(verificationProvider);
      final gating = ref.read(gatingProvider);
      if (_needsSecureGate(verif, gating)) {
        _showSecureTabGate(context, verif, gating);
        return;
      }
    }
    setState(() {
      _currentIndex = index;
      _visitedTabs.add(index);
    });
  }

  void _showSecureTabGate(
    BuildContext context,
    VerificationState verif,
    GatingState gating,
  ) {
    final needsVerification =
        verif.verificationStatus != VerificationStatus.approved;
    final title = needsVerification ? 'Verify to meet people' : 'Access pending';
    final message = needsVerification
        ? 'Finish photo verification to unlock Discover and Chats. This keeps direct interactions safer for everyone.'
        : 'Your account is waiting for approval before Discover and Chats unlock.';
    final buttonLabel = needsVerification ? 'Verify now' : 'Open access';
    final icon = needsVerification
        ? Icons.verified_outlined
        : Icons.hourglass_bottom_rounded;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.fromLTRB(28, 16, 28, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 32),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.emerald600.withValues(alpha: 0.08),
                border: Border.all(
                    color: AppColors.emerald600.withValues(alpha: 0.2)),
              ),
              child: Icon(icon, color: AppColors.emerald600, size: 28),
            ),
            const SizedBox(height: 20),
            Text(title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                )),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 14,
                  height: 1.5,
                )),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emerald600,
                  foregroundColor: AppColors.textOnEmerald,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () {
                  Navigator.pop(sheetCtx);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => needsVerification
                          ? const VerificationHubScreen()
                          : const EntryGateScreen(),
                    ),
                  );
                },
                child: Text(buttonLabel,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, letterSpacing: 0.3)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _baseTabs = [
    _TabItem(label: 'Discover', icon: Icons.explore_outlined, activeIcon: Icons.explore_rounded),
    _TabItem(label: 'Noblara', icon: Icons.auto_awesome_outlined, activeIcon: Icons.auto_awesome_rounded),
    _TabItem(label: 'Chats', icon: Icons.chat_bubble_outline_rounded, activeIcon: Icons.chat_bubble_rounded),
    _TabItem(label: 'Status', icon: Icons.bar_chart_rounded, activeIcon: Icons.bar_chart_rounded),
    _TabItem(label: 'Profile', icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded),
  ];

  static const _adminTab = _TabItem(
    label: 'Admin',
    icon: Icons.admin_panel_settings_outlined,
    activeIcon: Icons.admin_panel_settings_rounded,
  );

  static const _baseScreens = [
    FeedScreen(),
    NoblaraFeedScreen(),
    MatchesScreen(),
    StatusScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // Welcome toast — once per session
    if (!_welcomeShown) {
      _welcomeShown = true;
      _showWelcomeToast();
    }

    final isAdmin =
        ref.watch(isAdminProvider).maybeWhen(data: (v) => v, orElse: () => false);
    final tabs = isAdmin ? [..._baseTabs, _adminTab] : _baseTabs;
    final screens = isAdmin
        ? [..._baseScreens, const AdminScreen()]
        : _baseScreens;

    ref.watch(notificationProvider); // keep realtime subscription alive

    // Show in-app banner when a new notification arrives
    ref.listen<NotificationState>(notificationProvider, (prev, next) async {
      final latest = next.latestUnread;
      if (latest == null) return;
      if (prev?.latestUnread?.id == latest.id) return;

      ref.read(notificationProvider.notifier).clearLatest();

      // Gate by notification category preferences
      if (!isMockMode) {
        try {
          final uid = ref.read(authProvider).userId;
          if (uid != null) {
            final row = await Supabase.instance.client.from('profiles')
                .select('notification_preferences').eq('id', uid).maybeSingle();
            final prefs = row?['notification_preferences'] as Map<String, dynamic>?;
            if (prefs != null) {
              final typeToCategory = {
                'new_match': 'new_match', 'bff_connected': 'new_match', 'connection_closed': 'new_match',
                'new_message': 'new_message', 'chat_opened': 'new_message',
                'signal_received': 'signals', 'note_received': 'notes',
                'bff_reach_out': 'bff_suggestion',
                'video_proposed': 'new_match', 'video_confirmed': 'new_match',
                if (kSocialEnabled) 'event_farewell': 'event_activity',
              };
              final category = typeToCategory[latest.type];
              if (category != null && prefs[category] == false) return; // Suppressed by user
            }
          }
        } catch (e) { debugPrint('[nav] Notification prefs check failed: $e'); }
      }

      // Tier promotion → show celebration screen
      if (latest.type == 'tier_promoted') {
        final newTier = latest.data?['new_tier'] as String?;
        if (newTier != null && (newTier == 'noble' || newTier == 'explorer') && context.mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TierPromotionScreen(
                newTier: NobTier.fromString(newTier),
              ),
            ),
          );
          return;
        }
      }

      final isVideoProposed = latest.type == 'video_proposed' ||
          latest.type == 'video_confirmed';

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
          padding: EdgeInsets.zero,
          backgroundColor: Colors.transparent,
          elevation: 0,
          duration: const Duration(seconds: 5),
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.emerald600.withValues(alpha: 0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.emerald600.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
            children: [
              // Noblara branded icon container
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.emerald600.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    'N',
                    style: TextStyle(
                      color: AppColors.emerald500,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'serif',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      latest.title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      latest.body,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isVideoProposed)
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    setState(() => _currentIndex = 2); // Go to Chats tab
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.emerald500,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('View',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          ), // Container
        ),
      );
    });

    // Chat badge: show unread message count, not notification count
    final unreadMessages = ref.watch(unreadMessageCountProvider).valueOrNull ?? 0;
    final unreadCount = unreadMessages;

    // Clamp index when admin tab appears/disappears
    final safeIndex = _currentIndex.clamp(0, screens.length - 1);

    return Scaffold(
      body: Stack(
        children: screens.asMap().entries.map((entry) {
          final i = entry.key;
          final screen = entry.value;
          final isActive = i == safeIndex;
          if (!_visitedTabs.contains(i)) return const SizedBox.shrink();
          return Offstage(
            offstage: !isActive,
            child: TickerMode(enabled: isActive, child: screen),
          );
        }).toList(),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              context.bgColor.withValues(alpha: 0.0),
              context.bgColor.withValues(alpha: 0.85),
              context.surfaceColor,
            ],
            stops: const [0.0, 0.25, 1.0],
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, -4)),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: safeIndex,
          elevation: 0,
          backgroundColor: Colors.transparent,
          selectedItemColor: AppColors.emerald500,
          unselectedItemColor: AppColors.textSecondary,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          type: BottomNavigationBarType.fixed,
          onTap: (i) {
            // Secure tabs (Discover, Chats) require verification + entry-gate.
            // Noblara, Status, Profile, Admin are always reachable.
            if (_secureTabs.contains(i)) {
              final verif = ref.read(verificationProvider);
              final gating = ref.read(gatingProvider);
              if (_needsSecureGate(verif, gating)) {
                _showSecureTabGate(context, verif, gating);
                return;
              }
            }
            setState(() {
              _currentIndex = i;
              _visitedTabs.add(i);
            });
          },
          items: tabs.asMap().entries.map((entry) {
            final i = entry.key;
            final t = entry.value;
            // Show badge only on "Chats" tab (index 2)
            final showBadge = i == 2 && unreadCount > 0;
            return BottomNavigationBarItem(
              icon: showBadge
                  ? Badge(
                      label: Text('$unreadCount'),
                      backgroundColor: AppColors.emerald600,
                      child: Icon(t.icon),
                    )
                  : Icon(t.icon),
              activeIcon: showBadge
                  ? Badge(
                      label: Text('$unreadCount'),
                      backgroundColor: AppColors.emerald600,
                      child: Icon(t.activeIcon),
                    )
                  : Icon(t.activeIcon),
              label: t.label,
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _TabItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const _TabItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}
