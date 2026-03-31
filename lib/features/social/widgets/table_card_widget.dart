import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/enums/noble_mode.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/table_card.dart';

// ---------------------------------------------------------------------------
// SwipeableTableCard — wraps gesture detection + overlays
// ---------------------------------------------------------------------------

class SwipeableTableCard extends StatefulWidget {
  final TableCard table;
  final bool isTop;
  final bool hasJoined;
  final VoidCallback onJoin;
  final VoidCallback onPass;

  const SwipeableTableCard({
    super.key,
    required this.table,
    required this.isTop,
    required this.hasJoined,
    required this.onJoin,
    required this.onPass,
  });

  @override
  State<SwipeableTableCard> createState() => _SwipeableTableCardState();
}

class _SwipeableTableCardState extends State<SwipeableTableCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _anim;
  Offset _offset = Offset.zero;
  bool _dragging = false;

  static const _mode = NobleMode.social;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _swipeDisabled =>
      !widget.isTop || (widget.table.isFull && !widget.hasJoined);

  void _onPanUpdate(DragUpdateDetails d) {
    if (_swipeDisabled) return;
    setState(() {
      _offset += d.delta;
      _dragging = true;
    });
  }

  void _onPanEnd(DragEndDetails _) {
    if (_swipeDisabled) return;
    final sw = MediaQuery.of(context).size.width;
    if (_offset.dx > sw * 0.3) {
      _flyOff(Offset(sw * 2.5, _offset.dy), widget.onJoin);
    } else if (_offset.dx < -sw * 0.3) {
      _flyOff(Offset(-sw * 2.5, _offset.dy), widget.onPass);
    } else {
      _spring();
    }
  }

  void _flyOff(Offset target, VoidCallback cb) {
    _anim = Tween<Offset>(begin: _offset, end: target).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    )..addListener(() => setState(() => _offset = _anim.value));
    _ctrl.forward(from: 0).then((_) => cb());
    setState(() => _dragging = false);
  }

  void _spring() {
    _anim = Tween<Offset>(begin: _offset, end: Offset.zero).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
    )..addListener(() => setState(() => _offset = _anim.value));
    _ctrl.forward(from: 0);
    setState(() => _dragging = false);
  }

  double get _progress {
    final sw = MediaQuery.of(context).size.width;
    return (_offset.dx / (sw * 0.4)).clamp(-1.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: Transform.translate(
        offset: _offset,
        child: Transform.rotate(
          angle: widget.isTop && !_swipeDisabled
              ? (_offset.dx / MediaQuery.of(context).size.width) * 0.35
              : 0,
          child: Stack(
            children: [
              _TableCardBody(table: widget.table, hasJoined: widget.hasJoined),
              // JOIN overlay (right swipe)
              if (_dragging && widget.isTop && !widget.table.isFull)
                Positioned.fill(
                  child: Opacity(
                    opacity: _progress.clamp(0.0, 1.0),
                    child: _SwipeOverlay(
                      text: 'JOIN',
                      color: _mode.accentColor,
                      align: const Alignment(0.85, -0.8),
                    ),
                  ),
                ),
              // PASS overlay (left swipe)
              if (_dragging && widget.isTop)
                Positioned.fill(
                  child: Opacity(
                    opacity: (-_progress).clamp(0.0, 1.0),
                    child: const _SwipeOverlay(
                      text: 'PASS',
                      color: AppColors.error,
                      align: Alignment(-0.85, -0.8),
                    ),
                  ),
                ),
              // Full overlay
              if (widget.table.isFull && widget.isTop && !widget.hasJoined)
                const Positioned.fill(child: _FullOverlay()),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card body — Premium Invitation design
// ---------------------------------------------------------------------------

class _TableCardBody extends StatelessWidget {
  final TableCard table;
  final bool hasJoined;

  const _TableCardBody({required this.table, required this.hasJoined});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final cardH = size.height * 0.62;
    final mode = NobleMode.social;

    return Stack(
      children: [
        // Card content (clipped to rounded corners)
        Container(
          width: size.width - AppSpacing.xxxl * 2,
          height: cardH,
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F0F), // Obsidian Black base
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.12),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Cover photo
                CachedNetworkImage(
                  imageUrl: table.coverPhotoUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      Container(color: const Color(0xFF0F0F0F)),
                  errorWidget: (_, __, ___) =>
                      Container(color: const Color(0xFF0F0F0F)),
                ),
                // Gradient — deeper black at top and bottom
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.38, 1.0],
                        colors: [
                          Colors.black.withValues(alpha: 0.42),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.96),
                        ],
                      ),
                    ),
                  ),
                ),
                // Top row: [Host badge] · · · [EventTag][Live][Joined]
                Positioned(
                  top: AppSpacing.lg,
                  left: AppSpacing.lg,
                  right: AppSpacing.lg,
                  child: Row(
                    children: [
                      _HostBadge(table: table),
                      const Spacer(),
                      _EventTag(tag: table.eventTag),
                      if (table.isLive) ...[
                        const SizedBox(width: AppSpacing.xs),
                        const _LiveBadge(),
                      ],
                      if (hasJoined) ...[
                        const SizedBox(width: AppSpacing.xs),
                        _JoinedBadge(mode: mode),
                      ],
                    ],
                  ),
                ),
                // Center: Discussion topics — glassmorphism pill panel
                if (table.discussionTopics.isNotEmpty)
                  Positioned.fill(
                    top: 88,
                    bottom: 192,
                    child: Align(
                      alignment: Alignment.center,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xl),
                        child: _DiscussionTopicsCenter(
                          topics: table.discussionTopics,
                        ),
                      ),
                    ),
                  ),
                // Bottom info block
                Positioned(
                  left: AppSpacing.xl,
                  right: AppSpacing.xl,
                  bottom: AppSpacing.xl,
                  child: _CardInfo(table: table),
                ),
              ],
            ),
          ),
        ),
        // Gold foil border — painted over the clipped card
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.48),
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Host badge — avatar + first name + verified gold checkmark
// ---------------------------------------------------------------------------

class _HostBadge extends StatelessWidget {
  final TableCard table;
  const _HostBadge({required this.table});

  @override
  Widget build(BuildContext context) {
    final host = table.participants.where((p) => p.isHost).firstOrNull;
    final avatarUrl = host != null
        ? 'https://picsum.photos/seed/${host.avatarSeed}/80/80'
        : null;
    final displayName = table.hostName.split(',').first.split(' ').first;

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(AppSpacing.radiusCircle),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.38),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar with gold ring
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gold, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.4),
                  blurRadius: 6,
                ),
              ],
            ),
            child: ClipOval(
              child: avatarUrl != null
                  ? CachedNetworkImage(
                      imageUrl: avatarUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          _HostInitial(name: table.hostName),
                    )
                  : _HostInitial(name: table.hostName),
            ),
          ),
          const SizedBox(width: 6),
          // First name
          Text(
            displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(width: 5),
          // Verified checkmark
          Container(
            width: 14,
            height: 14,
            decoration: const BoxDecoration(
              color: AppColors.gold,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, color: Colors.black, size: 10),
          ),
        ],
      ),
    );
  }
}

class _HostInitial extends StatelessWidget {
  final String name;
  const _HostInitial({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.gold.withValues(alpha: 0.18),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: AppColors.gold,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Discussion topics — center glassmorphism pill panel
// ---------------------------------------------------------------------------

class _DiscussionTopicsCenter extends StatelessWidget {
  final List<String> topics;
  const _DiscussionTopicsCenter({required this.topics});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.32),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: AppColors.gold.withValues(alpha: 0.22),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section label
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: AppColors.gold,
                    size: 10,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'ON THE TABLE',
                    style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              // Topic pills
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: topics.take(3).map((topic) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusCircle),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      topic,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card info — bottom block (title, location, goal, eligibility, slots)
// ---------------------------------------------------------------------------

class _CardInfo extends StatelessWidget {
  final TableCard table;

  const _CardInfo({required this.table});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title
        Text(
          table.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        // Location
        Row(
          children: [
            const Icon(Icons.location_on_rounded,
                color: AppColors.gold, size: 13),
            const SizedBox(width: AppSpacing.xxs),
            Flexible(
              child: Text(
                table.location,
                style: const TextStyle(color: AppColors.gold, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        // Table goal
        if (table.tableGoal != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            '"${table.tableGoal}"',
            style: TextStyle(
              color: AppColors.gold.withValues(alpha: 0.85),
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        // Eligibility gate
        if (table.minEligibility != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              const Icon(Icons.lock_outline_rounded,
                  color: AppColors.gold, size: 12),
              const SizedBox(width: AppSpacing.xxs),
              Flexible(
                child: Text(
                  table.minEligibility!,
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        // Slot indicator row
        _SlotRow(table: table),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Slot indicator row — gold filled circles, thin ring for empty
// ---------------------------------------------------------------------------

class _SlotRow extends StatelessWidget {
  final TableCard table;

  const _SlotRow({required this.table});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ...List.generate(table.maxParticipants, (i) {
          final filled = i < table.currentCount;
          final participant = filled ? table.participants[i] : null;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: _SlotCircle(filled: filled, participant: participant),
          );
        }),
        const Spacer(),
        Text(
          '${table.currentCount}/${table.maxParticipants} joined',
          style: TextStyle(
            color: table.isFull
                ? AppColors.gold
                : Colors.white.withValues(alpha: 0.55),
            fontSize: 11,
            fontWeight: table.isFull ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _SlotCircle extends StatelessWidget {
  final bool filled;
  final TableParticipant? participant;

  const _SlotCircle({required this.filled, required this.participant});

  @override
  Widget build(BuildContext context) {
    if (filled && participant != null) {
      return Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.gold, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.5),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl:
                'https://picsum.photos/seed/${participant!.avatarSeed}/80/80',
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => Container(
              color: AppColors.gold.withValues(alpha: 0.25),
              child: Center(
                child: Text(
                  participant!.name[0],
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Empty slot — thin gold ring only
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.30),
          width: 1.5,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Badges
// ---------------------------------------------------------------------------

class _EventTag extends StatelessWidget {
  final String tag;
  const _EventTag({required this.tag});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xxs),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppSpacing.radiusCircle),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Text(
        tag,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _LiveBadge extends StatefulWidget {
  const _LiveBadge();

  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.5, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xxs),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(AppSpacing.radiusCircle),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: _pulse.value),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              'Live Now',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JoinedBadge extends StatelessWidget {
  final NobleMode mode;
  const _JoinedBadge({required this.mode});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xxs),
      decoration: BoxDecoration(
        color: mode.accentColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCircle),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_rounded, color: AppColors.bg, size: 12),
          SizedBox(width: 3),
          Text(
            'Joined',
            style: TextStyle(
              color: AppColors.bg,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Full overlay — "Maximum Capacity Reached" with glassmorphism
// ---------------------------------------------------------------------------

class _FullOverlay extends StatelessWidget {
  const _FullOverlay();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.70),
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          ),
          child: Center(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Decorative gold rule — top
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: AppColors.gold.withValues(alpha: 0.45),
                          thickness: 0.5,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md),
                        child: Icon(
                          Icons.diamond_outlined,
                          color: AppColors.gold,
                          size: 14,
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: AppColors.gold.withValues(alpha: 0.45),
                          thickness: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  // "MAXIMUM CAPACITY"
                  Text(
                    'MAXIMUM CAPACITY',
                    style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  // "REACHED"
                  const Text(
                    'REACHED',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w200,
                      letterSpacing: 7,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  // Decorative gold rule — bottom
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: AppColors.gold.withValues(alpha: 0.45),
                          thickness: 0.5,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm),
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: AppColors.gold.withValues(alpha: 0.45),
                          thickness: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Waitlist hint
                  Text(
                    'Notify me when a seat opens',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.48),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Swipe overlay label
// ---------------------------------------------------------------------------

class _SwipeOverlay extends StatelessWidget {
  final String text;
  final Color color;
  final Alignment align;

  const _SwipeOverlay({
    required this.text,
    required this.color,
    required this.align,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      child: Align(
        alignment: align,
        child: Container(
          margin: const EdgeInsets.all(AppSpacing.lg),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 3),
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }
}
