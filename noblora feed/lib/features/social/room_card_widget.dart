import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/premium.dart';
import '../../data/models/room.dart';

const _accent = AppColors.emerald700;

class RoomCardWidget extends StatelessWidget {
  final Room room;
  final VoidCallback onTap;
  final VoidCallback? onJoin;

  const RoomCardWidget({
    super.key,
    required this.room,
    required this.onTap,
    this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    return PressEffect(
      onTap: onTap,
      scale: 0.98,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: Premium.cardDecoration(radius: AppSpacing.radiusLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm,
              ),
              child: Row(
                children: [
                  // Host avatar with glow
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: Premium.shadowSm,
                    ),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: _accent.withValues(alpha: 0.2),
                      backgroundImage: room.hostPhotoUrl != null
                          ? NetworkImage(room.hostPhotoUrl!)
                          : null,
                      child: room.hostPhotoUrl == null
                          ? Text(
                              (room.hostName ?? '?')[0].toUpperCase(),
                              style: const TextStyle(
                                color: _accent,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              room.hostName ?? 'Host',
                              style: TextStyle(
                                color: context.textMuted,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: _accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Host',
                                style: TextStyle(
                                  color: _accent,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          room.title,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: context.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Age label
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Text(
                      room.ageLabel,
                      style: const TextStyle(
                        color: _accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Description ──
            if (room.description != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text(
                  room.description!,
                  style: TextStyle(
                    color: context.textMuted,
                    fontSize: 13,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            const SizedBox(height: AppSpacing.sm),

            // ── Topic tags ──
            if (room.topicTags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: room.topicTags.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusCircle),
                        border: Border.all(
                          color: _accent.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          color: _accent.withValues(alpha: 0.7),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

            const SizedBox(height: AppSpacing.sm),

            // ── Distance + Participants ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  Icon(Icons.near_me_outlined, color: _accent.withValues(alpha: 0.5), size: 13),
                  const SizedBox(width: 4),
                  Text(
                    room.distanceLabel,
                    style: TextStyle(
                      color: _accent.withValues(alpha: 0.6),
                      fontSize: 11,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.people_outline_rounded, color: _accent.withValues(alpha: 0.6), size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '${room.participantCount}/${room.maxParticipants}',
                    style: TextStyle(
                      color: _accent.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.sm),

            // ── Fill bar ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: room.fillPercent,
                  minHeight: 3,
                  backgroundColor: context.borderColor,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    room.fillPercent > 0.8 ? AppColors.warning : _accent,
                  ),
                ),
              ),
            ),

            // ── Action row ──
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg,
              ),
              child: Row(
                children: [
                  if (room.isFull)
                    Text(
                      'Full',
                      style: TextStyle(color: context.textMuted, fontSize: 12),
                    )
                  else if (onJoin != null)
                    TextButton.icon(
                      onPressed: onJoin,
                      icon: const Icon(Icons.login_rounded, size: 16),
                      label: const Text('Join'),
                      style: TextButton.styleFrom(
                        foregroundColor: _accent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: onTap,
                    style: TextButton.styleFrom(
                      foregroundColor: context.textMuted,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Open', style: TextStyle(fontSize: 12)),
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
