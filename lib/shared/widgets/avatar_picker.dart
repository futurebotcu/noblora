import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';

/// 12 custom-drawn avatars using CustomPainter.
class AvatarPicker extends StatelessWidget {
  final int? selectedId;
  final ValueChanged<int> onSelected;

  const AvatarPicker({super.key, this.selectedId, required this.onSelected});

  static const avatarCount = 12;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: avatarCount,
      itemBuilder: (context, i) {
        final id = i + 1;
        final sel = selectedId == id;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onSelected(id);
          },
          child: AnimatedScale(
            scale: sel ? 1.08 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: sel
                    ? Border.all(color: Colors.white, width: 3)
                    : Border.all(color: Colors.transparent, width: 3),
                boxShadow: sel
                    ? [BoxShadow(color: AppColors.gold.withValues(alpha: 0.3), blurRadius: 12)]
                    : null,
              ),
              child: ClipOval(
                child: CustomPaint(
                  size: const Size(72, 72),
                  painter: AvatarPainter(avatarId: id),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Renders a single avatar by id. Can be used anywhere in the app.
class AvatarWidget extends StatelessWidget {
  final int avatarId;
  final double size;

  const AvatarWidget({super.key, required this.avatarId, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: CustomPaint(
        size: Size(size, size),
        painter: AvatarPainter(avatarId: avatarId),
      ),
    );
  }
}

class AvatarPainter extends CustomPainter {
  final int avatarId;

  const AvatarPainter({required this.avatarId});

  static const _bgColors = [
    Color(0xFF1A237E), // 1 Architect — deep navy
    Color(0xFF1B5E20), // 2 Artist — forest green
    Color(0xFF4A148C), // 3 Thinker — deep purple
    Color(0xFF004D40), // 4 Explorer — dark teal
    Color(0xFFBF360C), // 5 Creator — deep orange
    Color(0xFF880E4F), // 6 Dreamer — burgundy
    Color(0xFF37474F), // 7 Rebel — slate
    Color(0xFF0D47A1), // 8 Scholar — royal blue
    Color(0xFF33691E), // 9 Wanderer — olive green
    Color(0xFF4E342E), // 10 Visionary — dark brown
    Color(0xFF212121), // 11 Mystic — charcoal
    Color(0xFF827717), // 12 Pioneer — dark gold
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final bg = _bgColors[(avatarId - 1).clamp(0, 11)];

    // Background circle
    canvas.drawCircle(c, r, Paint()..color = bg);

    // Skin tone
    final skin = Paint()..color = const Color(0xFFF5DEB3);
    final skinLight = Paint()..color = const Color(0xFFFFE4C4);
    final skinWarm = Paint()..color = const Color(0xFFDEB887);
    final dark = Paint()..color = const Color(0xFF2C2C2C);
    final whiteFill = Paint()..color = Colors.white;
    final eyePaint = Paint()..color = const Color(0xFF1A1A1A);
    final mouthPaint = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.025
      ..strokeCap = StrokeCap.round;

    final s = size.width; // shorthand

    switch (avatarId) {
      case 1: // Architect — block hair, circle head, dots, line mouth
        // Hair block
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(c.dx, c.dy - s * 0.12), width: s * 0.42, height: s * 0.18), Radius.circular(s * 0.04)),
          dark,
        );
        // Head
        canvas.drawCircle(Offset(c.dx, c.dy + s * 0.06), s * 0.22, skin);
        // Eyes
        canvas.drawCircle(Offset(c.dx - s * 0.08, c.dy + s * 0.02), s * 0.025, eyePaint);
        canvas.drawCircle(Offset(c.dx + s * 0.08, c.dy + s * 0.02), s * 0.025, eyePaint);
        // Mouth
        canvas.drawLine(Offset(c.dx - s * 0.06, c.dy + s * 0.14), Offset(c.dx + s * 0.06, c.dy + s * 0.14), mouthPaint);
        break;

      case 2: // Artist — oval head, wavy hair, curved smile
        // Wavy hair
        final hairPath = Path();
        for (var i = 0; i < 5; i++) {
          final x = c.dx - s * 0.22 + i * s * 0.11;
          hairPath.addOval(Rect.fromCircle(center: Offset(x, c.dy - s * 0.16), radius: s * 0.08));
        }
        canvas.drawPath(hairPath, Paint()..color = const Color(0xFF5D4037));
        // Head oval
        canvas.drawOval(Rect.fromCenter(center: Offset(c.dx, c.dy + s * 0.06), width: s * 0.40, height: s * 0.46), skinLight);
        // Eyes
        canvas.drawCircle(Offset(c.dx - s * 0.08, c.dy + s * 0.02), s * 0.022, eyePaint);
        canvas.drawCircle(Offset(c.dx + s * 0.08, c.dy + s * 0.02), s * 0.022, eyePaint);
        // Smile
        final smile2 = Path()
          ..moveTo(c.dx - s * 0.07, c.dy + s * 0.12)
          ..quadraticBezierTo(c.dx, c.dy + s * 0.19, c.dx + s * 0.07, c.dy + s * 0.12);
        canvas.drawPath(smile2, mouthPaint);
        break;

      case 3: // Thinker — round, glasses, neutral
        // Head
        canvas.drawCircle(Offset(c.dx, c.dy + s * 0.04), s * 0.24, skin);
        // Hair
        canvas.drawArc(Rect.fromCenter(center: Offset(c.dx, c.dy - s * 0.04), width: s * 0.50, height: s * 0.32), 3.14, 3.14, true, dark);
        // Glasses
        final glassPaint = Paint()..color = Colors.white.withValues(alpha: 0.8)..style = PaintingStyle.stroke..strokeWidth = s * 0.02;
        canvas.drawCircle(Offset(c.dx - s * 0.09, c.dy + s * 0.02), s * 0.06, glassPaint);
        canvas.drawCircle(Offset(c.dx + s * 0.09, c.dy + s * 0.02), s * 0.06, glassPaint);
        canvas.drawLine(Offset(c.dx - s * 0.03, c.dy + s * 0.02), Offset(c.dx + s * 0.03, c.dy + s * 0.02), glassPaint);
        // Eyes behind glasses
        canvas.drawCircle(Offset(c.dx - s * 0.09, c.dy + s * 0.02), s * 0.018, eyePaint);
        canvas.drawCircle(Offset(c.dx + s * 0.09, c.dy + s * 0.02), s * 0.018, eyePaint);
        // Neutral mouth
        canvas.drawLine(Offset(c.dx - s * 0.05, c.dy + s * 0.14), Offset(c.dx + s * 0.05, c.dy + s * 0.14), mouthPaint);
        break;

      case 4: // Explorer — square-ish head, determined, short hair
        // Head (rounded rect)
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(c.dx, c.dy + s * 0.06), width: s * 0.42, height: s * 0.44), Radius.circular(s * 0.10)),
          skinWarm,
        );
        // Short hair
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(c.dx, c.dy - s * 0.10), width: s * 0.44, height: s * 0.14), Radius.circular(s * 0.06)),
          dark,
        );
        // Eyes — determined (slight angle)
        canvas.drawCircle(Offset(c.dx - s * 0.09, c.dy + s * 0.02), s * 0.024, eyePaint);
        canvas.drawCircle(Offset(c.dx + s * 0.09, c.dy + s * 0.02), s * 0.024, eyePaint);
        // Determined mouth
        final detMouth = Path()
          ..moveTo(c.dx - s * 0.06, c.dy + s * 0.15)
          ..quadraticBezierTo(c.dx, c.dy + s * 0.13, c.dx + s * 0.06, c.dy + s * 0.15);
        canvas.drawPath(detMouth, mouthPaint);
        break;

      case 5: // Creator — round, big smile, curly hair
        // Curly hair (circles on top)
        final hairColor = Paint()..color = const Color(0xFF3E2723);
        for (var i = 0; i < 6; i++) {
          final angle = -2.6 + i * 0.52;
          final hx = c.dx + s * 0.25 * (angle / 1.5).clamp(-1, 1);
          canvas.drawCircle(Offset(hx, c.dy - s * 0.15 + (i % 2 == 0 ? 0 : -s * 0.04)), s * 0.08, hairColor);
        }
        // Head
        canvas.drawCircle(Offset(c.dx, c.dy + s * 0.06), s * 0.23, skin);
        // Eyes
        canvas.drawCircle(Offset(c.dx - s * 0.08, c.dy + s * 0.02), s * 0.025, eyePaint);
        canvas.drawCircle(Offset(c.dx + s * 0.08, c.dy + s * 0.02), s * 0.025, eyePaint);
        // Big smile
        final bigSmile = Path()
          ..moveTo(c.dx - s * 0.10, c.dy + s * 0.11)
          ..quadraticBezierTo(c.dx, c.dy + s * 0.22, c.dx + s * 0.10, c.dy + s * 0.11);
        canvas.drawPath(bigSmile, mouthPaint);
        break;

      case 6: // Dreamer — oval, closed eyes, soft smile
        // Head oval
        canvas.drawOval(Rect.fromCenter(center: Offset(c.dx, c.dy + s * 0.04), width: s * 0.40, height: s * 0.46), skinLight);
        // Long flowing hair
        final hairPaint = Paint()..color = const Color(0xFF4E342E);
        canvas.drawOval(Rect.fromCenter(center: Offset(c.dx - s * 0.18, c.dy), width: s * 0.16, height: s * 0.50), hairPaint);
        canvas.drawOval(Rect.fromCenter(center: Offset(c.dx + s * 0.18, c.dy), width: s * 0.16, height: s * 0.50), hairPaint);
        canvas.drawArc(Rect.fromCenter(center: Offset(c.dx, c.dy - s * 0.06), width: s * 0.48, height: s * 0.28), 3.14, 3.14, true, hairPaint);
        // Closed eyes (curved lines)
        final closedEye = Paint()..color = const Color(0xFF1A1A1A)..style = PaintingStyle.stroke..strokeWidth = s * 0.02..strokeCap = StrokeCap.round;
        final leftEye = Path()..moveTo(c.dx - s * 0.13, c.dy + s * 0.02)..quadraticBezierTo(c.dx - s * 0.08, c.dy + s * 0.06, c.dx - s * 0.03, c.dy + s * 0.02);
        final rightEye = Path()..moveTo(c.dx + s * 0.03, c.dy + s * 0.02)..quadraticBezierTo(c.dx + s * 0.08, c.dy + s * 0.06, c.dx + s * 0.13, c.dy + s * 0.02);
        canvas.drawPath(leftEye, closedEye);
        canvas.drawPath(rightEye, closedEye);
        // Soft smile
        final softSmile = Path()..moveTo(c.dx - s * 0.05, c.dy + s * 0.14)..quadraticBezierTo(c.dx, c.dy + s * 0.18, c.dx + s * 0.05, c.dy + s * 0.14);
        canvas.drawPath(softSmile, mouthPaint);
        break;

      case 7: // Rebel — angular face, raised brow, cool
        // Angular head (polygon-ish)
        final headPath = Path()
          ..moveTo(c.dx, c.dy - s * 0.16)
          ..lineTo(c.dx + s * 0.20, c.dy - s * 0.04)
          ..lineTo(c.dx + s * 0.18, c.dy + s * 0.18)
          ..lineTo(c.dx - s * 0.18, c.dy + s * 0.18)
          ..lineTo(c.dx - s * 0.20, c.dy - s * 0.04)
          ..close();
        canvas.drawPath(headPath, skinWarm);
        // Spiky hair
        final spike = Paint()..color = const Color(0xFF263238);
        for (var i = 0; i < 4; i++) {
          final sx = c.dx - s * 0.15 + i * s * 0.10;
          canvas.drawPath(
            Path()..moveTo(sx, c.dy - s * 0.14)..lineTo(sx + s * 0.05, c.dy - s * 0.28)..lineTo(sx + s * 0.10, c.dy - s * 0.14)..close(),
            spike,
          );
        }
        // Eyes — one raised brow
        canvas.drawCircle(Offset(c.dx - s * 0.08, c.dy + s * 0.02), s * 0.024, eyePaint);
        canvas.drawCircle(Offset(c.dx + s * 0.08, c.dy + s * 0.01), s * 0.024, eyePaint);
        // Raised eyebrow
        canvas.drawLine(Offset(c.dx + s * 0.04, c.dy - s * 0.04), Offset(c.dx + s * 0.13, c.dy - s * 0.06), mouthPaint);
        // Smirk
        final smirk = Path()..moveTo(c.dx - s * 0.04, c.dy + s * 0.13)..quadraticBezierTo(c.dx + s * 0.04, c.dy + s * 0.15, c.dx + s * 0.08, c.dy + s * 0.11);
        canvas.drawPath(smirk, mouthPaint);
        break;

      case 8: // Scholar — round, small glasses, slight smile, neat hair
        // Neat hair
        canvas.drawArc(Rect.fromCenter(center: Offset(c.dx, c.dy - s * 0.04), width: s * 0.50, height: s * 0.34), 3.14, 3.14, true, Paint()..color = const Color(0xFF1B1B1B));
        // Head
        canvas.drawCircle(Offset(c.dx, c.dy + s * 0.06), s * 0.22, skin);
        // Small glasses
        final sPaint = Paint()..color = const Color(0xFFCCCCCC)..style = PaintingStyle.stroke..strokeWidth = s * 0.015;
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(c.dx - s * 0.08, c.dy + s * 0.04), width: s * 0.11, height: s * 0.08), Radius.circular(s * 0.02)), sPaint);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(c.dx + s * 0.08, c.dy + s * 0.04), width: s * 0.11, height: s * 0.08), Radius.circular(s * 0.02)), sPaint);
        canvas.drawLine(Offset(c.dx - s * 0.025, c.dy + s * 0.04), Offset(c.dx + s * 0.025, c.dy + s * 0.04), sPaint);
        // Eyes
        canvas.drawCircle(Offset(c.dx - s * 0.08, c.dy + s * 0.04), s * 0.016, eyePaint);
        canvas.drawCircle(Offset(c.dx + s * 0.08, c.dy + s * 0.04), s * 0.016, eyePaint);
        // Slight smile
        final sSmile = Path()..moveTo(c.dx - s * 0.05, c.dy + s * 0.14)..quadraticBezierTo(c.dx, c.dy + s * 0.17, c.dx + s * 0.05, c.dy + s * 0.14);
        canvas.drawPath(sSmile, mouthPaint);
        break;

      case 9: // Wanderer — oval, wind-swept hair, open expression
        // Wind-swept hair (diagonal lines)
        final hairP = Paint()..color = const Color(0xFF6D4C41)..strokeWidth = s * 0.035..strokeCap = StrokeCap.round;
        for (var i = 0; i < 5; i++) {
          final y = c.dy - s * 0.22 + i * s * 0.04;
          canvas.drawLine(Offset(c.dx - s * 0.10 + i * s * 0.02, y), Offset(c.dx + s * 0.22, y - s * 0.06), hairP);
        }
        // Head oval
        canvas.drawOval(Rect.fromCenter(center: Offset(c.dx, c.dy + s * 0.06), width: s * 0.40, height: s * 0.44), skin);
        // Eyes — open/wide
        canvas.drawCircle(Offset(c.dx - s * 0.08, c.dy + s * 0.02), s * 0.028, eyePaint);
        canvas.drawCircle(Offset(c.dx + s * 0.08, c.dy + s * 0.02), s * 0.028, eyePaint);
        // White eye highlights
        canvas.drawCircle(Offset(c.dx - s * 0.075, c.dy + s * 0.015), s * 0.008, whiteFill);
        canvas.drawCircle(Offset(c.dx + s * 0.085, c.dy + s * 0.015), s * 0.008, whiteFill);
        // Open mouth
        canvas.drawOval(Rect.fromCenter(center: Offset(c.dx, c.dy + s * 0.15), width: s * 0.08, height: s * 0.05), mouthPaint);
        break;

      case 10: // Visionary — strong jaw, confident, short hair
        // Strong jawline head
        final jawPath = Path()
          ..moveTo(c.dx - s * 0.18, c.dy - s * 0.10)
          ..quadraticBezierTo(c.dx - s * 0.22, c.dy + s * 0.10, c.dx - s * 0.10, c.dy + s * 0.22)
          ..lineTo(c.dx + s * 0.10, c.dy + s * 0.22)
          ..quadraticBezierTo(c.dx + s * 0.22, c.dy + s * 0.10, c.dx + s * 0.18, c.dy - s * 0.10)
          ..close();
        canvas.drawPath(jawPath, skinWarm);
        // Short tight hair
        canvas.drawArc(Rect.fromCenter(center: Offset(c.dx, c.dy - s * 0.06), width: s * 0.44, height: s * 0.28), 3.14, 3.14, true, dark);
        // Confident eyes
        canvas.drawCircle(Offset(c.dx - s * 0.08, c.dy + s * 0.04), s * 0.022, eyePaint);
        canvas.drawCircle(Offset(c.dx + s * 0.08, c.dy + s * 0.04), s * 0.022, eyePaint);
        // Eyebrows
        final browPaint = Paint()..color = const Color(0xFF1A1A1A)..strokeWidth = s * 0.02..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(c.dx - s * 0.12, c.dy - s * 0.02), Offset(c.dx - s * 0.04, c.dy - s * 0.03), browPaint);
        canvas.drawLine(Offset(c.dx + s * 0.04, c.dy - s * 0.03), Offset(c.dx + s * 0.12, c.dy - s * 0.02), browPaint);
        // Confident smile
        final confSmile = Path()..moveTo(c.dx - s * 0.06, c.dy + s * 0.14)..quadraticBezierTo(c.dx, c.dy + s * 0.18, c.dx + s * 0.06, c.dy + s * 0.14);
        canvas.drawPath(confSmile, mouthPaint);
        break;

      case 11: // Mystic — oval, mysterious, long flowing hair
        // Long flowing hair
        final mHair = Paint()..color = const Color(0xFF424242);
        canvas.drawOval(Rect.fromCenter(center: Offset(c.dx - s * 0.16, c.dy + s * 0.04), width: s * 0.18, height: s * 0.56), mHair);
        canvas.drawOval(Rect.fromCenter(center: Offset(c.dx + s * 0.16, c.dy + s * 0.04), width: s * 0.18, height: s * 0.56), mHair);
        canvas.drawArc(Rect.fromCenter(center: Offset(c.dx, c.dy - s * 0.06), width: s * 0.50, height: s * 0.30), 3.14, 3.14, true, mHair);
        // Head oval
        canvas.drawOval(Rect.fromCenter(center: Offset(c.dx, c.dy + s * 0.04), width: s * 0.36, height: s * 0.44), skinLight);
        // Mysterious half-closed eyes
        final halfEye = Paint()..color = const Color(0xFF1A1A1A)..style = PaintingStyle.stroke..strokeWidth = s * 0.02..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(c.dx - s * 0.12, c.dy + s * 0.02), Offset(c.dx - s * 0.04, c.dy + s * 0.02), halfEye);
        canvas.drawLine(Offset(c.dx + s * 0.04, c.dy + s * 0.02), Offset(c.dx + s * 0.12, c.dy + s * 0.02), halfEye);
        // Small pupil dots
        canvas.drawCircle(Offset(c.dx - s * 0.08, c.dy + s * 0.02), s * 0.012, eyePaint);
        canvas.drawCircle(Offset(c.dx + s * 0.08, c.dy + s * 0.02), s * 0.012, eyePaint);
        // Subtle smile
        final subSmile = Path()..moveTo(c.dx - s * 0.04, c.dy + s * 0.14)..quadraticBezierTo(c.dx, c.dy + s * 0.16, c.dx + s * 0.04, c.dy + s * 0.14);
        canvas.drawPath(subSmile, mouthPaint);
        break;

      case 12: // Pioneer — round, bright eyes, big smile, textured hair
        // Textured hair (dots/small circles)
        final tHair = Paint()..color = const Color(0xFF33691E);
        for (var row = 0; row < 3; row++) {
          for (var col = 0; col < 5; col++) {
            final hx = c.dx - s * 0.18 + col * s * 0.09;
            final hy = c.dy - s * 0.22 + row * s * 0.06;
            canvas.drawCircle(Offset(hx, hy), s * 0.04, tHair);
          }
        }
        // Head
        canvas.drawCircle(Offset(c.dx, c.dy + s * 0.06), s * 0.23, skin);
        // Bright eyes (bigger with highlights)
        canvas.drawCircle(Offset(c.dx - s * 0.08, c.dy + s * 0.02), s * 0.032, eyePaint);
        canvas.drawCircle(Offset(c.dx + s * 0.08, c.dy + s * 0.02), s * 0.032, eyePaint);
        canvas.drawCircle(Offset(c.dx - s * 0.075, c.dy + s * 0.014), s * 0.01, whiteFill);
        canvas.drawCircle(Offset(c.dx + s * 0.085, c.dy + s * 0.014), s * 0.01, whiteFill);
        // Big smile
        final pSmile = Path()
          ..moveTo(c.dx - s * 0.10, c.dy + s * 0.11)
          ..quadraticBezierTo(c.dx, c.dy + s * 0.22, c.dx + s * 0.10, c.dy + s * 0.11);
        canvas.drawPath(pSmile, mouthPaint);
        break;

      default:
        // Fallback — simple circle with initial
        canvas.drawCircle(c, s * 0.22, skin);
        canvas.drawCircle(Offset(c.dx - s * 0.06, c.dy), s * 0.02, eyePaint);
        canvas.drawCircle(Offset(c.dx + s * 0.06, c.dy), s * 0.02, eyePaint);
    }
  }

  @override
  bool shouldRepaint(AvatarPainter oldDelegate) => avatarId != oldDelegate.avatarId;
}
