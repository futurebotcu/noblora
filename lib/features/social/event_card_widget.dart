import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/models/event.dart';

const _violet = Color(0xFFAB47BC);
const _violetLight = Color(0xFFCE93D8);

class EventCardWidget extends StatelessWidget {
  final NobEvent event;
  final VoidCallback onTap;
  final VoidCallback? onJoin;

  const EventCardWidget({
    super.key,
    required this.event,
    required this.onTap,
    this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: context.borderSubtleColor, width: 0.5),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ──
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
                      boxShadow: [
                        BoxShadow(
                          color: _violet.withValues(alpha: 0.3),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: _violet.withValues(alpha: 0.3),
                      backgroundImage: event.hostPhotoUrl != null
                          ? NetworkImage(event.hostPhotoUrl!)
                          : null,
                      child: event.hostPhotoUrl == null
                          ? Text(
                              (event.hostName ?? '?')[0].toUpperCase(),
                              style: const TextStyle(color: _violet, fontSize: 14, fontWeight: FontWeight.w600),
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
                              event.hostName ?? 'Host',
                              style: TextStyle(color: context.textMuted, fontSize: 12),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: _violet.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('Host', style: TextStyle(color: _violet, fontSize: 9, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                        Text(
                          event.title,
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: event.isUpcoming ? _violet.withValues(alpha: 0.1) : AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Text(
                      event.timeLabel,
                      style: TextStyle(
                        color: event.isUpcoming ? _violet : AppColors.error,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Description ──
            if (event.description != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text(
                  event.description!,
                  style: TextStyle(color: context.textMuted, fontSize: 13, height: 1.3),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            const SizedBox(height: AppSpacing.md),

            // ── Location + Vibe bar ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  if (event.locationText != null) ...[
                    Icon(Icons.location_on_outlined, color: context.textMuted, size: 14),
                    const SizedBox(width: 4),
                    Text(event.locationText!, style: TextStyle(color: context.textMuted, fontSize: 12)),
                    const Spacer(),
                  ],
                  // Attendee count
                  Icon(Icons.people_outline_rounded, color: _violetLight, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '${event.attendeeCount}/${event.maxAttendees}',
                    style: TextStyle(color: _violetLight, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.sm),

            // ── Vibe fill bar ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: event.fillPercent,
                  minHeight: 3,
                  backgroundColor: context.borderColor,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    event.fillPercent > 0.8 ? AppColors.warning : _violet,
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
                  if (event.isFull)
                    Text('Full', style: TextStyle(color: context.textMuted, fontSize: 12))
                  else if (onJoin != null)
                    TextButton.icon(
                      onPressed: onJoin,
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Going'),
                      style: TextButton.styleFrom(
                        foregroundColor: _violet,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
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
