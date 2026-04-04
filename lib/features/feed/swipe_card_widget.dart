import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/enums/noble_mode.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/models/post.dart';
import '../../data/models/profile_card.dart';
import '../../providers/posts_provider.dart';

class SwipeCardWidget extends StatefulWidget {
  final ProfileCard card;
  final bool isTop;
  final NobleMode mode;
  final VoidCallback onSwipeRight;
  final VoidCallback onSwipeLeft;

  const SwipeCardWidget({
    super.key,
    required this.card,
    required this.isTop,
    required this.mode,
    required this.onSwipeRight,
    required this.onSwipeLeft,
  });

  @override
  State<SwipeCardWidget> createState() => _SwipeCardWidgetState();
}

class _SwipeCardWidgetState extends State<SwipeCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _animation;
  Offset _offset = Offset.zero;
  bool _isDragging = false;

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

  void _onPanUpdate(DragUpdateDetails details) {
    if (!widget.isTop) return;
    setState(() {
      _offset += details.delta;
      _isDragging = true;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (!widget.isTop) return;
    final screenW = MediaQuery.of(context).size.width;
    final threshold = screenW * 0.3;

    if (_offset.dx > threshold) {
      _flyOff(Offset(screenW * 2.5, _offset.dy));
      widget.onSwipeRight();
    } else if (_offset.dx < -threshold) {
      _flyOff(Offset(-screenW * 2.5, _offset.dy));
      widget.onSwipeLeft();
    } else {
      _springBack();
    }
  }

  void _flyOff(Offset target) {
    _animation = Tween<Offset>(begin: _offset, end: target).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    )..addListener(() => setState(() => _offset = _animation.value));
    _ctrl.forward(from: 0);
    setState(() => _isDragging = false);
  }

  void _springBack() {
    _animation = Tween<Offset>(begin: _offset, end: Offset.zero).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
    )..addListener(() => setState(() => _offset = _animation.value));
    _ctrl.forward(from: 0);
    setState(() => _isDragging = false);
  }

  double get _rotationAngle {
    final screenW = MediaQuery.of(context).size.width;
    return _offset.dx / screenW * 0.4;
  }

  double get _swipeProgress {
    final screenW = MediaQuery.of(context).size.width;
    return (_offset.dx / (screenW * 0.4)).clamp(-1.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: Transform.translate(
        offset: _offset,
        child: Transform.rotate(
          angle: widget.isTop ? _rotationAngle : 0,
          child: Stack(
            children: [
              _CardBody(card: widget.card, mode: widget.mode),
              if (widget.isTop && _isDragging) ...[
                // SELECT overlay
                Positioned.fill(
                  child: Opacity(
                    opacity: _swipeProgress.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.selectOverlay,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Align(
                        alignment: const Alignment(0.85, -0.8),
                        child: _SwipeLabel(
                          text: widget.mode == NobleMode.date
                              ? 'LIKE'
                              : widget.mode == NobleMode.bff
                                  ? 'CONNECT'
                                  : 'JOIN',
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ),
                ),
                // PASS overlay
                Positioned.fill(
                  child: Opacity(
                    opacity: (-_swipeProgress).clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.passOverlay,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Align(
                        alignment: Alignment(-0.85, -0.8),
                        child: _SwipeLabel(text: 'PASS', color: Colors.red),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card body — routes to BFF or Date layout
// ---------------------------------------------------------------------------

class _CardBody extends StatelessWidget {
  final ProfileCard card;
  final NobleMode mode;

  const _CardBody({required this.card, required this.mode});

  @override
  Widget build(BuildContext context) {
    if (mode == NobleMode.bff) return _BffCardBody(card: card);

    final size = MediaQuery.of(context).size;
    final cardH = size.height * 0.78;

    return Container(
      width: size.width - 40,
      height: cardH,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.borderSubtleColor, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Photo fills entire card
            CachedNetworkImage(
              imageUrl: card.photoUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                color: context.surfaceColor,
                child: Center(child: CircularProgressIndicator(color: mode.accentColor, strokeWidth: 1.5)),
              ),
              errorWidget: (_, __, ___) => Container(
                color: context.surfaceColor,
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.person_rounded, color: context.textDisabled, size: 48),
                  const SizedBox(height: 8),
                  Text('No photo', style: TextStyle(color: context.textDisabled, fontSize: 12)),
                ]),
              ),
            ),
            // Bottom gradient overlay — cinematic bg-tinted fade
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.4, 1.0],
                    colors: const [
                      Colors.transparent,
                      Color(0x400B0D0C),
                      Color(0xCC0B0D0C),
                    ],
                  ),
                ),
              ),
            ),
            // Verified badge (respects showStatusBadge setting)
            if (card.isVerified && card.showStatusBadge)
              Positioned(
                top: AppSpacing.lg,
                right: AppSpacing.lg,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: mode.accentColor,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusCircle),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_rounded,
                          color: context.bgColor, size: 12),
                      const SizedBox(width: 3),
                      Text(
                        'Verified',
                        style: TextStyle(
                          color: context.bgColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Info overlay
            Positioned(
              left: 20,
              right: 20,
              bottom: 24,
              child: _CardInfo(card: card, mode: mode),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardInfo extends ConsumerWidget {
  final ProfileCard card;
  final NobleMode mode;

  const _CardInfo({required this.card, required this.mode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Load last 3 Nobs for this user
    final nobsAsync = ref.watch(lastNobsProvider(card.id));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Name + age
        Text(
          '${card.name}, ${card.age}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            height: 1.1,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        // Location
        Row(
          children: [
            const Icon(Icons.location_on_rounded, color: AppColors.gold, size: 14),
            const SizedBox(width: AppSpacing.xxs),
            Text(
              card.city,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
            ),
            if (card.profession != null) ...[
              const SizedBox(width: AppSpacing.sm),
              const Text('·', style: TextStyle(color: Colors.white54)),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  card.profession!,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
        if (card.bio != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            card.bio!,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (card.interests.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 28,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: card.interests.length > 5 ? 5 : card.interests.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusCircle),
                ),
                child: Center(
                  child: Text(
                    card.interests[i],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
        // Last 3 Nobs
        ...nobsAsync.when(
          data: (nobs) {
            if (nobs.isEmpty) return <Widget>[];
            return [
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: nobs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () => _showNobDetail(context, nobs[i]),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      constraints: const BoxConstraints(maxWidth: 160),
                      decoration: const BoxDecoration(
                        color: Color(0x1AFFFFFF),
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(6),
                          bottomRight: Radius.circular(6),
                        ),
                        border: Border(
                          left: BorderSide(color: AppColors.gold, width: 2),
                        ),
                      ),
                      child: Text(
                        nobs[i].content.isNotEmpty ? nobs[i].content : (nobs[i].caption ?? ''),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          height: 1.3,
                        ),
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ),
            ];
          },
          loading: () => <Widget>[],
          error: (_, __) => <Widget>[],
        ),
      ],
    );
  }
}

void _showNobDetail(BuildContext context, Post nob) {
  showModalBottomSheet(
    context: context,
    backgroundColor: context.surfaceColor,
    builder: (_) => Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(999))),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(nob.isThought ? 'Thought' : 'Moment',
                    style: TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.w600)),
              ),
              const Spacer(),
              Text(nob.authorName ?? '',
                  style: TextStyle(color: context.textMuted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (nob.isMoment && nob.photoUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              child: Image.network(nob.photoUrl!, height: 200, width: double.infinity, fit: BoxFit.cover),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Text(
            nob.content.isNotEmpty ? nob.content : (nob.caption ?? ''),
            style: TextStyle(color: context.textPrimary, fontSize: 16, height: 1.5),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    ),
  );
}

class _SwipeLabel extends StatelessWidget {
  final String text;
  final Color color;
  const _SwipeLabel({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
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
    );
  }
}

// ---------------------------------------------------------------------------
// BFF card body — split layout: photo top (58%) + networking panel (42%)
// ---------------------------------------------------------------------------

class _BffCardBody extends StatelessWidget {
  final ProfileCard card;

  const _BffCardBody({required this.card});

  static const _mode = NobleMode.bff;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final cardH = size.height * 0.62;

    return Container(
      width: size.width - AppSpacing.xxxl * 2,
      height: cardH,
      decoration: BoxDecoration(
        color: context.bgColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        boxShadow: [
          BoxShadow(
            color: _mode.accentColor.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Photo area (58%)
            SizedBox(
              height: cardH * 0.58,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: card.photoUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        Container(color: context.bgColor),
                    errorWidget: (_, __, ___) =>
                        Container(color: context.bgColor),
                  ),
                  // Gradient fading into dark panel below
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.55, 1.0],
                          colors: [
                            Colors.transparent,
                            Colors.transparent,
                            context.bgColor,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Verified badge
                  if (card.isVerified)
                    Positioned(
                      top: AppSpacing.md,
                      right: AppSpacing.md,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xxs),
                        decoration: BoxDecoration(
                          color: _mode.accentColor,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusCircle),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_rounded,
                                color: context.bgColor, size: 12),
                            const SizedBox(width: 3),
                            Text(
                              'Verified',
                              style: TextStyle(
                                color: context.bgColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Networking Profile panel (42%)
            Expanded(
              child: Container(
                color: context.surfaceColor,
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.lg),
                child: _NetworkingPanel(card: card),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Networking panel — professional identity block
// ---------------------------------------------------------------------------

class _NetworkingPanel extends StatelessWidget {
  final ProfileCard card;

  const _NetworkingPanel({required this.card});

  static const _teal = Color(0xFF1BA3B0);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section label
        Row(
          children: [
            const Icon(Icons.business_center_rounded, color: _teal, size: 10),
            const SizedBox(width: 4),
            Text(
              'NETWORKING PROFILE',
              style: TextStyle(
                color: _teal,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        // Name + Age
        Text(
          '${card.name}, ${card.age}',
          style: TextStyle(
            color: context.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        // Industry + City pills
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            if (card.industry != null)
              _ProfessionalPill(label: card.industry!, color: _teal),
            _ProfessionalPill(
              label: card.city,
              color: context.textMuted,
              icon: Icons.location_on_rounded,
            ),
          ],
        ),
        // Expertise row
        if (card.expertise != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(Icons.star_outline_rounded,
                  color: _teal.withValues(alpha: 0.7), size: 12),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  card.expertise!,
                  style: TextStyle(
                    color: context.textSecondary,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
        const Spacer(),
        // Connection Goal — highlighted teal box
        if (card.connectionGoal != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: _teal.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              border:
                  Border.all(color: _teal.withValues(alpha: 0.22), width: 1),
            ),
            child: Row(
              children: [
                const Icon(Icons.handshake_outlined, color: _teal, size: 14),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    card.connectionGoal!,
                    style: const TextStyle(
                      color: _teal,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ProfessionalPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _ProfessionalPill({
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusCircle),
        border: Border.all(color: color.withValues(alpha: 0.30), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 10),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
