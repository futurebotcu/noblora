import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/premium.dart';
import '../../data/models/bff_suggestion.dart';
import '../noblara_feed/user_profile_screen.dart';

const _accent = AppColors.emerald500;
const _accentLight = AppColors.emerald350;

class BffSuggestionCard extends StatelessWidget {
  final BffSuggestion suggestion;
  final VoidCallback onConnect;
  final VoidCallback onPass;
  final VoidCallback? onReachOut;
  final VoidCallback? onNote;
  final bool showCommonGround;

  const BffSuggestionCard({
    super.key,
    required this.suggestion,
    required this.onConnect,
    required this.onPass,
    this.onReachOut,
    this.onNote,
    this.showCommonGround = true,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = suggestion.timeRemaining;
    final hoursLeft = remaining.inHours;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: Premium.cardDecoration(radius: AppSpacing.radiusLg, withGlow: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: photo + name + label ──
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                final uid = suggestion.otherUserId(suggestion.userAId);
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => UserProfileScreen(
                    userId: uid,
                    initialName: suggestion.otherUserName,
                    initialAvatarUrl: suggestion.otherUserPhotoUrl,
                  ),
                ));
              },
              child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: Premium.shadowSm,
                  ),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: _accent.withValues(alpha: 0.2),
                    backgroundImage: suggestion.otherUserPhotoUrl != null
                        ? NetworkImage(suggestion.otherUserPhotoUrl!)
                        : null,
                    child: suggestion.otherUserPhotoUrl == null
                        ? Text(
                            (suggestion.otherUserName ?? '?')[0].toUpperCase(),
                            style: const TextStyle(
                              color: _accent,
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(child: Text(
                            suggestion.otherUserName ?? 'Someone',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: context.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                          )),
                          const SizedBox(width: 4),
                          Icon(Icons.open_in_new_rounded, color: context.textMuted, size: 12),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Suggested for you',
                        style: TextStyle(
                          color: _accent.withValues(alpha: 0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: context.bgColor,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Text(
                    '${hoursLeft}h left',
                    style: TextStyle(
                      color: hoursLeft < 6
                          ? AppColors.warning
                          : context.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            ),
          ),

          // ── Bio ──
          if (suggestion.otherUserBio != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                suggestion.otherUserBio!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.textMuted,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          const SizedBox(height: AppSpacing.md),

          // ── Common Ground (gated by AI suggestion explanations setting) ──
          if (showCommonGround) Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You might get along',
                  style: TextStyle(
                    color: _accentLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ...suggestion.commonGround.map((g) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline_rounded,
                              color: _accent.withValues(alpha: 0.6), size: 16),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              g,
                              style: TextStyle(
                                color: context.textSecondary,
                                fontSize: 13,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),

          // ── Nob Posts ──
          if (suggestion.otherUserNobPosts.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                'Recent Nobs',
                style: TextStyle(
                  color: context.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              height: 56,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                itemCount: suggestion.otherUserNobPosts.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, i) {
                  final text = suggestion.otherUserNobPosts[i];
                  return GestureDetector(
                    onTap: () => _showNobContent(context, text),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      constraints: const BoxConstraints(maxWidth: 200),
                      decoration: BoxDecoration(
                        color: context.bgColor,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSm),
                        border: Border.all(color: context.borderColor),
                      ),
                      child: Text(
                        text,
                        style: TextStyle(
                          color: context.textMuted,
                          fontSize: 12,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.lg),

          // ── Action Buttons ──
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: context.textMuted.withValues(alpha: 0.2)),
                      foregroundColor: context.textMuted,
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                    ),
                    onPressed: onPass,
                    child: const Text('Pass'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      boxShadow: Premium.emeraldGlow(intensity: 0.5),
                    ),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.people_rounded, size: 18),
                      label: const Text('Connect'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                      ),
                      onPressed: onConnect,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ── Secondary actions: Reach Out + Note ──
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  icon: Icon(Icons.waving_hand_rounded, size: 14, color: _accent.withValues(alpha: 0.7)),
                  label: Text('Reach Out', style: TextStyle(color: _accent.withValues(alpha: 0.7), fontSize: 12)),
                  onPressed: onReachOut,
                ),
                const SizedBox(width: AppSpacing.lg),
                TextButton.icon(
                  icon: Icon(Icons.mail_outline_rounded, size: 14, color: _accent.withValues(alpha: 0.7)),
                  label: Text('Note', style: TextStyle(color: _accent.withValues(alpha: 0.7), fontSize: 12)),
                  onPressed: onNote,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static void _showNobContent(BuildContext context, String content) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: Premium.sheetHandle())),
            const SizedBox(height: AppSpacing.xxl),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.emerald500.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('Nob', style: TextStyle(color: _accent, fontSize: 10, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(content, style: TextStyle(color: context.textPrimary, fontSize: 16, height: 1.5)),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}
