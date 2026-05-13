import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/enums/noble_mode.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/premium.dart';
import '../../data/models/profile_card.dart';
import '../profile/user_profile_screen.dart';

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
  bool _hasTriggeredHaptic = false;
  double _screenW = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _screenW = MediaQuery.of(context).size.width;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!widget.isTop) return;
    final threshold = _screenW * 0.3;
    final wasOverThreshold = _offset.dx.abs() > threshold;

    setState(() {
      _offset += details.delta;
      _isDragging = true;
    });

    // Haptic tick when crossing the swipe threshold
    final isOverThreshold = _offset.dx.abs() > threshold;
    if (isOverThreshold && !wasOverThreshold && !_hasTriggeredHaptic) {
      HapticFeedback.mediumImpact();
      _hasTriggeredHaptic = true;
    } else if (!isOverThreshold) {
      _hasTriggeredHaptic = false;
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (!widget.isTop) return;
    final threshold = _screenW * 0.3;
    _hasTriggeredHaptic = false;

    if (_offset.dx > threshold) {
      HapticFeedback.lightImpact();
      _flyOff(Offset(_screenW * 2.5, _offset.dy));
      widget.onSwipeRight();
    } else if (_offset.dx < -threshold) {
      HapticFeedback.lightImpact();
      _flyOff(Offset(-_screenW * 2.5, _offset.dy));
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
    return _offset.dx / _screenW * 0.4;
  }

  double get _swipeProgress {
    return (_offset.dx / (_screenW * 0.4)).clamp(-1.0, 1.0);
  }

  /// Subtle scale-down while dragging (max 3% shrink at full swipe)
  double get _dragScale {
    if (!_isDragging) return 1.0;
    final progress = _swipeProgress.abs();
    return 1.0 - (progress * 0.03);
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
          child: Transform.scale(
            scale: widget.isTop ? _dragScale : 1.0,
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
                            // R18 — BFF 'CONNECT' branch removed.
                            text: widget.mode == NobleMode.date
                                ? 'LIKE'
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
                          child: _SwipeLabel(text: 'PASS', color: AppColors.textMuted),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
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
    // R18 — _BffCardBody branch removed; date is the only swipe mode in V1.

    final size = MediaQuery.of(context).size;
    final cardH = size.height * 0.78;

    return Container(
      width: size.width - 40,
      height: cardH,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: AppColors.card,
        border: Border.all(
          color: AppColors.border,
          width: 0.5,
        ),
        boxShadow: Premium.shadowLg,
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
              memCacheWidth: 800,
              placeholder: (_, __) => Container(
                decoration: BoxDecoration(gradient: Premium.cardGradient),
                child: Center(
                  child: SizedBox(
                    width: 32, height: 32,
                    child: CircularProgressIndicator(
                      color: mode.accentColor.withValues(alpha: 0.4),
                      strokeWidth: 1.5,
                    ),
                  ),
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                decoration: BoxDecoration(gradient: Premium.cardGradient),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.emerald600.withValues(alpha: 0.06),
                    ),
                    child: Icon(Icons.person_rounded, color: context.textDisabled, size: 32),
                  ),
                  const SizedBox(height: 12),
                  Text('No photo', style: TextStyle(color: context.textDisabled, fontSize: 12)),
                ]),
              ),
            ),
            // Cinematic gradient overlay — rich 4-stop fade
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: Premium.photoOverlay),
              ),
            ),
            // Subtle top vignette for depth
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.2,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.15),
                    ],
                    stops: const [0.6, 1.0],
                  ),
                ),
              ),
            ),
            // Verified badge — frosted light pill, modern theme-aligned
            if (card.isVerified)
              Positioned(
                top: AppSpacing.lg,
                right: AppSpacing.lg,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusCircle),
                    border: Border.all(
                      color: AppColors.burgundy600.withValues(alpha: 0.20),
                      width: 0.5,
                    ),
                    boxShadow: Premium.shadowSm,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_rounded,
                          color: AppColors.burgundy600, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        'Verified',
                        style: TextStyle(
                          color: AppColors.burgundy700,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Info overlay — bottom aligned
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Name + age — hero text (tap to view full profile)
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => UserProfileScreen(
              userId: card.id,
              initialName: card.name,
            ),
          )),
          child: Row(
            children: [
              Text('${card.name}, ${card.age}', style: Premium.cardName),
              const SizedBox(width: 6),
              Icon(Icons.open_in_new_rounded, color: Colors.white.withValues(alpha: 0.5), size: 14),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // Location + profession — refined secondary line
        Row(
          children: [
            Icon(Icons.location_on_rounded,
                color: AppColors.emerald500.withValues(alpha: 0.9), size: 13),
            const SizedBox(width: 3),
            Text(
              card.city,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (card.profession != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text('·', style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35), fontSize: 13)),
              ),
              Flexible(
                child: Text(
                  card.profession!,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            // R17B-fix(C) — last-active timestamp render removed. Users
            // have no Settings toggle for `show_last_active` after R17B,
            // so surfacing the relative timestamp to other users would
            // be an uncontrolled privacy leak. Kept the helper `_timeAgo`
            // off the call graph — analyzer will flag it if no other
            // caller exists; deleted if so.
          ],
        ),
        if (card.bio != null) ...[
          const SizedBox(height: 8),
          Text(
            card.bio!,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (card.interests.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 30,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: card.interests.length > 5 ? 5 : card.interests.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusCircle),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                    width: 0.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    card.interests[i],
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SwipeLabel extends StatelessWidget {
  final String text;
  final Color color;
  const _SwipeLabel({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color, width: 2.5),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.25),
            blurRadius: 16,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: 3,
        ),
      ),
    );
  }
}

