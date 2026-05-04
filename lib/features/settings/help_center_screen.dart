import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_tokens.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Help Center — full-screen, searchable, category-based help system
// ═══════════════════════════════════════════════════════════════════════════════

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? _categories
        : _categories
            .map((c) {
              final matchingItems = c.items.where((item) =>
                  item.title.toLowerCase().contains(_query) ||
                  item.body.toLowerCase().contains(_query)).toList();
              if (matchingItems.isEmpty &&
                  !c.title.toLowerCase().contains(_query)) {
                return null;
              }
              return _HelpCategory(
                icon: c.icon,
                title: c.title,
                subtitle: c.subtitle,
                items: matchingItems.isEmpty ? c.items : matchingItems,
              );
            })
            .whereType<_HelpCategory>()
            .toList();

    return Scaffold(
      backgroundColor: context.bgColor,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──
          SliverAppBar(
            pinned: true,
            backgroundColor: context.bgColor,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: context.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text('Help Center',
                style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v.toLowerCase()),
                  style: TextStyle(color: context.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search help topics...',
                    hintStyle: TextStyle(color: context.textDisabled, fontSize: 14),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: context.textDisabled, size: 20),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear_rounded,
                                color: context.textDisabled, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: context.surfaceColor,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
              ),
            ),
          ),

          // ── Content ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: Column(children: [
                          Icon(Icons.search_off_rounded,
                              color: context.textDisabled, size: 40),
                          const SizedBox(height: 12),
                          Text('No results for "$_query"',
                              style: TextStyle(
                                  color: context.textMuted, fontSize: 14)),
                          const SizedBox(height: 4),
                          Text('Try different keywords',
                              style: TextStyle(
                                  color: context.textDisabled, fontSize: 12)),
                        ]),
                      ),
                    )
                  else
                    ...filtered.map((cat) => _CategoryCard(category: cat)),

                  // ── Contact footer ──
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: context.accent.withValues(alpha: 0.12)),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.support_agent_rounded,
                            color: context.accent, size: 28),
                        const SizedBox(height: 12),
                        Text('Still need help?',
                            style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text(
                            'Email us at support@noblara.com with your account email and a description of the issue.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: context.textMuted,
                                fontSize: 13,
                                height: 1.5)),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: Icon(Icons.copy_rounded, size: 16),
                            label: const Text('Copy email address'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: context.accent,
                              side: BorderSide(
                                  color:
                                      context.accent.withValues(alpha: 0.3)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () {
                              Clipboard.setData(const ClipboardData(
                                  text: 'support@noblara.com'));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Email copied to clipboard')),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('We typically respond within 24 hours.',
                            style: TextStyle(
                                color: context.textDisabled, fontSize: 11)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Category Card — expandable section with items
// ═══════════════════════════════════════════════════════════════════════════════

class _CategoryCard extends StatelessWidget {
  final _HelpCategory category;
  const _CategoryCard({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor.withValues(alpha: 0.5)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: context.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(category.icon, color: context.accent, size: 18),
          ),
          title: Text(category.title,
              style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          subtitle: Text(category.subtitle,
              style: TextStyle(
                  color: context.textDisabled,
                  fontSize: 11,
                  height: 1.3)),
          collapsedIconColor: context.textDisabled,
          iconColor: context.accent,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding:
              const EdgeInsets.fromLTRB(14, 0, 14, 14),
          children: category.items
              .map((item) => _HelpItemTile(item: item))
              .toList(),
        ),
      ),
    );
  }
}

class _HelpItemTile extends StatelessWidget {
  final _HelpItem item;
  const _HelpItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: context.bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(item.title,
              style: TextStyle(
                  color: context.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
          collapsedIconColor: context.textDisabled,
          iconColor: context.accent,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
          children: [
            Text(item.body,
                style: TextStyle(
                    color: context.textMuted,
                    fontSize: 13,
                    height: 1.65)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Data Model
// ═══════════════════════════════════════════════════════════════════════════════

class _HelpCategory {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<_HelpItem> items;
  const _HelpCategory({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.items,
  });
}

class _HelpItem {
  final String title;
  final String body;
  const _HelpItem({required this.title, required this.body});
}

// ═══════════════════════════════════════════════════════════════════════════════
// Content — real, accurate, matches actual app behavior
// ═══════════════════════════════════════════════════════════════════════════════

const _categories = [
  // ── A. GETTING STARTED ──
  _HelpCategory(
    icon: Icons.rocket_launch_outlined,
    title: 'Getting Started',
    subtitle: 'What Noblara is and how it works',
    items: [
      _HelpItem(
        title: 'What is Noblara?',
        body: 'Noblara is a connection platform with three modes:\n\n'
            '• Noble Date — find romantic matches through a guided flow: mutual like → mini intro → video call → real meeting.\n\n'
            '• Noble BFF — discover potential friends based on shared interests and compatibility. Accept suggestions to start planning activities.\n\n'
            '• Noblara Feed — share thoughts, moments, and photos with the community. No matching required. Open to all users based on their tier.',
      ),
      _HelpItem(
        title: 'How does matching work?',
        body: 'In Noble Date, you see one profile at a time. Swipe right to like, left to pass.\n\n'
            'When two people like each other, a match is created. You then have a limited window to schedule a video call. After the call, both sides decide whether to continue.\n\n'
            'In Noble BFF, the app suggests compatible people. You can accept or skip suggestions.',
      ),
      _HelpItem(
        title: 'What should I do first?',
        body: '1. Complete your profile — add at least one photo and fill in the basics.\n'
            '2. Choose your modes — enable Dating, BFF, or both in your profile settings.\n'
            '3. Start discovering — swipe through profiles or check your BFF suggestions.\n'
            '4. Post on Noblara Feed — share a thought or moment to engage with the community.',
      ),
      _HelpItem(
        title: 'Do I need to use all modes?',
        body: 'No. You can enable or disable Dating and BFF modes independently. You can even turn off both and use only the Noblara Feed. Your choice is saved and persists across sessions.',
      ),
    ],
  ),

  // ── B. PROFILE & PHOTOS ──
  _HelpCategory(
    icon: Icons.person_outlined,
    title: 'Profile & Photos',
    subtitle: 'Building and managing your profile',
    items: [
      _HelpItem(
        title: 'How do I complete my profile?',
        body: 'Go to the Profile tab and tap "Edit Profile." You\'ll see 13 sections covering basics, bio, interests, lifestyle, career, and more.\n\n'
            'Each section shows a completion indicator. Filling more sections increases your profile score, which directly affects your visibility in discovery.',
      ),
      _HelpItem(
        title: 'How do I add or remove photos?',
        body: 'In Edit Profile, the photo grid at the top lets you:\n\n'
            '• Tap an empty slot to add a photo from your gallery.\n'
            '• Tap an existing photo to view it full-screen.\n'
            '• Long-press or use the remove option to delete a photo.\n\n'
            'You can have up to 6 photos. The first photo is your main profile photo. Photos are uploaded to secure cloud storage.',
      ),
      _HelpItem(
        title: 'Why is my profile important?',
        body: 'Your profile completeness score affects:\n\n'
            '• How high you appear in discovery feeds.\n'
            '• Your tier progression (Observer → Explorer → Noble).\n'
            '• Whether other users find you interesting enough to connect.\n\n'
            'Profiles with photos, a bio, and filled sections get significantly more attention.',
      ),
      _HelpItem(
        title: 'My changes don\'t seem to save',
        body: 'Profile changes save to the server when you navigate back from a section. If you see the old data:\n\n'
            '• Check your internet connection.\n'
            '• Pull to refresh on the Profile screen.\n'
            '• Close and reopen the app.\n\n'
            'If the problem persists, contact support.',
      ),
    ],
  ),

  // ── C. MATCHING & CONVERSATIONS ──
  _HelpCategory(
    icon: Icons.favorite_outlined,
    title: 'Matching & Conversations',
    subtitle: 'Likes, matches, chat, and video calls',
    items: [
      _HelpItem(
        title: 'How do I match with someone?',
        body: 'In the Discover tab, swipe right on profiles you like and left on those you want to pass. When two people like each other, a match is created.\n\n'
            'You\'ll be notified and can find the match in your Matches tab.',
      ),
      _HelpItem(
        title: 'How does chat work?',
        body: 'Once matched, a conversation opens. Messages are delivered in real-time. You can:\n\n'
            '• Send text messages\n'
            '• Share images\n'
            '• React to messages with emojis\n'
            '• See read receipts and typing indicators\n\n'
            'Conversations have a time window tied to the match flow. If neither side schedules a video call within the deadline, the conversation expires.',
      ),
      _HelpItem(
        title: 'What happens when a conversation expires?',
        body: 'Expired conversations are locked — you can no longer send messages. The chat history remains visible but the input is disabled.\n\n'
            'This is by design: Noblara encourages moving from text to real interaction (video calls and meetings) rather than endless texting.',
      ),
      _HelpItem(
        title: 'Why can\'t I interact with some users?',
        body: 'There are several reasons:\n\n'
            '• You need at least one photo to use Dating and BFF modes.\n'
            '• The other user may have their profile paused.\n'
            '• The other user may have blocked or hidden you.\n'
            '• Their privacy settings may restrict who can reach them.\n'
            '• You may have reached your daily swipe or connection limit.',
      ),
      _HelpItem(
        title: 'How do I report or block someone?',
        body: 'In a chat conversation or match detail screen, tap the three-dot menu (⋮) and select "Report user." Choose a reason and submit.\n\n'
            'To block someone, go to Settings → Blocked Users. Blocked users cannot see your profile or contact you.\n\n'
            'Reports are confidential. Our team reviews every report.',
      ),
    ],
  ),

  // ── D. GATING, VERIFICATION & TIERS ──
  _HelpCategory(
    icon: Icons.lock_outline_rounded,
    title: 'Gating, Verification & Tiers',
    subtitle: 'Why some features are locked',
    items: [
      _HelpItem(
        title: 'Why are some features locked?',
        body: 'Noblara uses a gating system to keep the community safe and high-quality:\n\n'
            '• Photo required — you need at least one photo to use Dating and BFF modes. This ensures everyone in the feed is a real person.\n\n'
            '• Noble tier — some premium accent colors and features are available only to Noble tier users.',
      ),
      _HelpItem(
        title: 'How does photo verification work?',
        body: 'When prompted, take a selfie following the on-screen instructions. Our system compares your selfie to your profile photos to confirm they match.\n\n'
            'Verified users get:\n'
            '• A verified badge on their profile\n'
            '• Higher trust and maturity scores\n'
            '• Access to more features',
      ),
      _HelpItem(
        title: 'What are the tiers?',
        body: 'Noblara has three user tiers:\n\n'
            '• Observer — new or incomplete profiles. Basic access.\n'
            '• Explorer — active users with good profiles. Broader access.\n'
            '• Noble — top-tier users with high completeness, activity, and trust scores. Full access.\n\n'
            'Tiers are recalculated automatically every 6 hours based on your profile completeness, community score, and engagement.',
      ),
      _HelpItem(
        title: 'How do I unlock more features?',
        body: '1. Add a profile photo (unlocks Dating and BFF).\n'
            '2. Complete your profile sections (improves tier score).\n'
            '3. Verify your photo (unlocks Social features).\n'
            '4. Stay active and engage genuinely (improves vitality and community scores).',
      ),
    ],
  ),

  // ── E. ACCOUNT, PAUSE & DELETE ──
  _HelpCategory(
    icon: Icons.manage_accounts_outlined,
    title: 'Account, Pause & Delete',
    subtitle: 'Managing your account lifecycle',
    items: [
      _HelpItem(
        title: 'What does pausing my account do?',
        body: 'Pausing hides your profile from discovery. Other users will not see you in their feed or receive matches with you.\n\n'
            'Your data stays safe. Your conversations, matches, and posts remain intact. You can resume at any time and everything will be exactly as you left it.',
      ),
      _HelpItem(
        title: 'What happens when I request deletion?',
        body: 'When you request account deletion:\n\n'
            '1. Your account is paused immediately — you\'re hidden from discovery.\n'
            '2. You are signed out.\n'
            '3. A 30-day grace period begins.\n'
            '4. After 30 days, all your data is permanently and irreversibly deleted — profile, photos, messages, matches, posts, and all associated files.\n\n'
            'During the 30-day window, you can sign back in and cancel the deletion.',
      ),
      _HelpItem(
        title: 'How do I cancel deletion?',
        body: 'Sign back in with your account within 30 days of the deletion request. You\'ll see a banner at the top of Settings saying "Account deletion requested." Tap "Cancel Deletion" to restore your account.\n\n'
            'Your account will be unpaused and fully restored.',
      ),
      _HelpItem(
        title: 'What data is deleted?',
        body: 'After the 30-day grace period, the following is permanently removed:\n\n'
            '• Your profile and all personal information\n'
            '• All photos (profile, verification, galleries)\n'
            '• All messages and conversations\n'
            '• All matches, swipes, and interactions\n'
            '• All posts and reactions\n'
            '• Push notification tokens and device records\n\n'
            'This action is irreversible after the grace period.',
      ),
      _HelpItem(
        title: 'Can I request my data?',
        body: 'Yes. Under GDPR and KVKK regulations, you have the right to request a copy of your data. Send an email to privacy@noblara.com with your account email address.',
      ),
    ],
  ),

  // ── F. SAFETY & REPORTING ──
  _HelpCategory(
    icon: Icons.shield_outlined,
    title: 'Safety & Reporting',
    subtitle: 'Staying safe and reporting issues',
    items: [
      _HelpItem(
        title: 'How do I report a user?',
        body: 'You can report a user from two places:\n\n'
            '• In a chat conversation — tap the three-dot menu (⋮) at the top right and select "Report user."\n'
            '• In the match detail screen — tap the three-dot menu (⋮) and select "Report user."\n\n'
            'Choose a reason, and the report will be submitted confidentially. Our team reviews all reports.',
      ),
      _HelpItem(
        title: 'What\'s the difference between block and hide?',
        body: '• Block — the user cannot see your profile, send you messages, or interact with you in any way. They won\'t know they\'ve been blocked.\n\n'
            '• Hide — the user is removed from your feed. They can still see your profile, but you won\'t see theirs. Useful for people you\'re not interested in but don\'t need to block.',
      ),
      _HelpItem(
        title: 'Safety tips',
        body: '• Trust your instincts. If something feels off, it probably is.\n'
            '• Meet in public places for first meetings.\n'
            '• Tell a friend where you\'re going and who you\'re meeting.\n'
            '• Don\'t share personal information (address, financial details) early on.\n'
            '• Use the in-app video call before meeting in person.\n'
            '• Report any suspicious or inappropriate behavior immediately.',
      ),
      _HelpItem(
        title: 'When should I contact support?',
        body: 'Contact support if:\n\n'
            '• You feel unsafe or threatened by another user.\n'
            '• Someone is impersonating you or using your photos.\n'
            '• You encounter a bug that prevents you from using the app.\n'
            '• You need help with your account that self-service can\'t resolve.\n\n'
            'For urgent safety concerns, include "URGENT" in the subject line when emailing support@noblara.com.',
      ),
    ],
  ),

  // ── G. NOTIFICATIONS ──
  _HelpCategory(
    icon: Icons.notifications_outlined,
    title: 'Notifications & App Behavior',
    subtitle: 'How notifications and sessions work',
    items: [
      _HelpItem(
        title: 'How do notifications work?',
        body: 'Noblara sends push notifications for:\n\n'
            '• New matches\n'
            '• New messages\n'
            '• Video call scheduling updates\n'
            '• Match expirations\n'
            '• Community interactions\n\n'
            'Notifications require Firebase Cloud Messaging to be properly configured on your device.',
      ),
      _HelpItem(
        title: 'Why am I not receiving notifications?',
        body: 'Check the following:\n\n'
            '• Ensure notifications are enabled for Noblara in your device settings (Settings → Apps → Noblara → Notifications).\n'
            '• Check that Do Not Disturb is not active.\n'
            '• Make sure you have a stable internet connection.\n'
            '• Try signing out and back in to refresh your push token.',
      ),
      _HelpItem(
        title: 'What does the unread badge mean?',
        body: 'The badge on the Chat tab shows the total number of unread messages across all your conversations. It updates in real-time as you receive and read messages.',
      ),
      _HelpItem(
        title: 'Will I stay logged in?',
        body: 'Yes. Noblara keeps your session active. Your authentication token refreshes automatically every 30 minutes.\n\n'
            'If your session ever expires unexpectedly, the app will redirect you to the login screen. Simply sign in again.',
      ),
    ],
  ),

  // ── H. TROUBLESHOOTING ──
  _HelpCategory(
    icon: Icons.build_outlined,
    title: 'Troubleshooting',
    subtitle: 'Common issues and how to fix them',
    items: [
      _HelpItem(
        title: 'Photo won\'t upload',
        body: '• Make sure the file is JPG, PNG, or WebP format.\n'
            '• Maximum file size is 10 MB.\n'
            '• Check your internet connection.\n'
            '• Try a different photo to rule out file corruption.\n'
            '• If the problem persists, close the app completely and try again.',
      ),
      _HelpItem(
        title: 'Profile changes won\'t save',
        body: '• Ensure you have a stable internet connection.\n'
            '• Navigate back from the section to trigger the save.\n'
            '• Pull to refresh on the Profile screen.\n'
            '• If changes still don\'t appear, sign out and back in.\n'
            '• Contact support if the issue continues.',
      ),
      _HelpItem(
        title: 'Chat messages not loading',
        body: '• Check your internet connection.\n'
            '• The conversation may have expired — look for the "This conversation has closed" banner.\n'
            '• Pull down to refresh the messages.\n'
            '• If messages still don\'t load, close and reopen the app.',
      ),
      _HelpItem(
        title: 'App is slow or freezing',
        body: '• Close other apps running in the background.\n'
            '• Clear the app cache in your device settings.\n'
            '• Make sure you\'re running the latest version of Noblara.\n'
            '• Restart your device.\n'
            '• If the problem persists, report a bug through Settings → Report a Bug.',
      ),
      _HelpItem(
        title: 'I can\'t sign in',
        body: '• Double-check your email address for typos.\n'
            '• Check your email inbox (and spam folder) for the sign-in link.\n'
            '• The sign-in link expires after a short time — request a new one if needed.\n'
            '• Make sure you\'re using the same email you registered with.\n'
            '• Contact support if you\'re locked out.',
      ),
    ],
  ),

  // ── I. NOBLARA FEED ──
  _HelpCategory(
    icon: Icons.article_outlined,
    title: 'Noblara Feed',
    subtitle: 'Posting, drafts, and community',
    items: [
      _HelpItem(
        title: 'What is the Noblara Feed?',
        body: 'The Noblara Feed is a community space where you can share thoughts, moments, and photos. It\'s separate from dating and BFF — think of it as your social expression layer.\n\n'
            'Posts are visible to all users. Your tier determines how many posts you can share per day and week.',
      ),
      _HelpItem(
        title: 'How do I create a post?',
        body: 'Tap the compose button on the Noblara Feed tab. You can:\n\n'
            '• Write a text-based thought or moment.\n'
            '• Attach a photo.\n'
            '• Save as draft and publish later.\n\n'
            'Posts go through a quality check to maintain community standards.',
      ),
      _HelpItem(
        title: 'What are posting limits?',
        body: 'Posting limits depend on your tier:\n\n'
            '• Observer — limited daily and weekly posts.\n'
            '• Explorer — higher limits.\n'
            '• Noble — highest limits.\n\n'
            'Limits reset daily at midnight and weekly on Mondays. Your current usage is tracked automatically.',
      ),
    ],
  ),
];
