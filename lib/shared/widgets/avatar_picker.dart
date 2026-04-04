import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';

/// 12 custom-drawn character avatars using CustomPainter.
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
                    ? [BoxShadow(color: AppColors.emerald600.withValues(alpha: 0.3), blurRadius: 12)]
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
    Color(0xFF1A1A2E), //  1 Samurai
    Color(0xFF2D1B00), //  2 Janissary
    Color(0xFF1B3A4B), //  3 Viking
    Color(0xFF4A0000), //  4 Spartan
    Color(0xFF1A0A2E), //  5 Witch
    Color(0xFF0A2E1A), //  6 Cleopatra
    Color(0xFF0A0A0A), //  7 Ninja
    Color(0xFF1A2E4A), //  8 Valkyrie
    Color(0xFF2E1A00), //  9 Shaman
    Color(0xFF1A1A1A), // 10 Knight
    Color(0xFF2E2A00), // 11 Pharaoh
    Color(0xFF0A2E0A), // 12 Druid
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final s = size.width;
    final bg = _bgColors[(avatarId - 1).clamp(0, 11)];

    canvas.drawCircle(c, r, Paint()..color = bg);

    final skin = Paint()..color = const Color(0xFFF5DEB3);
    final skinDark = Paint()..color = const Color(0xFFDEB887);
    final eye = Paint()..color = const Color(0xFF1A1A1A);
    final white = Paint()..color = Colors.white;
    final line = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.022
      ..strokeCap = StrokeCap.round;

    switch (avatarId) {
      // ═══════════════════════════════════════════════════════
      case 1: // SAMURAI — kabuto helmet, fierce eyes
        final metal = Paint()..color = const Color(0xFF8B0000);
        final metalDark = Paint()..color = const Color(0xFF5C0000);
        final gold = Paint()..color = const Color(0xFFDAA520);
        // Face
        canvas.drawOval(Rect.fromCenter(center: Offset(c.dx, c.dy + s * 0.10), width: s * 0.38, height: s * 0.32), skin);
        // Kabuto helmet dome
        final helmet = Path()
          ..moveTo(c.dx - s * 0.28, c.dy + s * 0.02)
          ..quadraticBezierTo(c.dx - s * 0.30, c.dy - s * 0.18, c.dx, c.dy - s * 0.28)
          ..quadraticBezierTo(c.dx + s * 0.30, c.dy - s * 0.18, c.dx + s * 0.28, c.dy + s * 0.02)
          ..close();
        canvas.drawPath(helmet, metal);
        // Helmet front crest (maedate)
        final crest = Path()
          ..moveTo(c.dx - s * 0.04, c.dy - s * 0.26)
          ..lineTo(c.dx, c.dy - s * 0.42)
          ..lineTo(c.dx + s * 0.04, c.dy - s * 0.26)
          ..close();
        canvas.drawPath(crest, gold);
        // Helmet brim
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(c.dx, c.dy + s * 0.02), width: s * 0.60, height: s * 0.06), Radius.circular(s * 0.03)),
          metalDark,
        );
        // Gold center emblem
        canvas.drawCircle(Offset(c.dx, c.dy - s * 0.12), s * 0.04, gold);
        // Fierce eyes
        canvas.drawCircle(Offset(c.dx - s * 0.08, c.dy + s * 0.10), s * 0.025, eye);
        canvas.drawCircle(Offset(c.dx + s * 0.08, c.dy + s * 0.10), s * 0.025, eye);
        // Angry brows
        final brow = Paint()..color = const Color(0xFF1A1A1A)..strokeWidth = s * 0.025..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(c.dx - s * 0.14, c.dy + s * 0.04), Offset(c.dx - s * 0.04, c.dy + s * 0.06), brow);
        canvas.drawLine(Offset(c.dx + s * 0.04, c.dy + s * 0.06), Offset(c.dx + s * 0.14, c.dy + s * 0.04), brow);
        // Mouth guard (menpo)
        final menpo = Path()
          ..moveTo(c.dx - s * 0.16, c.dy + s * 0.16)
          ..quadraticBezierTo(c.dx, c.dy + s * 0.28, c.dx + s * 0.16, c.dy + s * 0.16);
        canvas.drawPath(menpo, Paint()..color = const Color(0xFF333333));
        // Mouth slit
        canvas.drawLine(Offset(c.dx - s * 0.08, c.dy + s * 0.20), Offset(c.dx + s * 0.08, c.dy + s * 0.20), Paint()..color = const Color(0xFF111111)..strokeWidth = s * 0.015);
        break;

      // ═══════════════════════════════════════════════════════
      case 2: // JANISSARY — tall börk hat, strong mustache
        final hatColor = Paint()..color = const Color(0xFFE8E8E8);
        // Face
        canvas.drawOval(Rect.fromCenter(center: Offset(c.dx, c.dy + s * 0.12), width: s * 0.38, height: s * 0.34), skinDark);
        // Tall börk hat
        final hat = Path()
          ..moveTo(c.dx - s * 0.14, c.dy + s * 0.02)
          ..lineTo(c.dx - s * 0.12, c.dy - s * 0.32)
          ..quadraticBezierTo(c.dx, c.dy - s * 0.38, c.dx + s * 0.12, c.dy - s * 0.32)
          ..lineTo(c.dx + s * 0.14, c.dy + s * 0.02)
          ..close();
        canvas.drawPath(hat, hatColor);
        // Hat ornament (red feather plume)
        final plume = Path()
          ..moveTo(c.dx, c.dy - s * 0.32)
          ..quadraticBezierTo(c.dx + s * 0.12, c.dy - s * 0.42, c.dx + s * 0.06, c.dy - s * 0.28);
        canvas.drawPath(plume, Paint()..color = const Color(0xFFC62828)..style = PaintingStyle.stroke..strokeWidth = s * 0.04..strokeCap = StrokeCap.round);
        // Gold hat band
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(c.dx, c.dy + s * 0.01), width: s * 0.30, height: s * 0.05), Radius.circular(s * 0.02)),
          Paint()..color = const Color(0xFFDAA520),
        );
        // Determined eyes
        canvas.drawCircle(Offset(c.dx - s * 0.08, c.dy + s * 0.10), s * 0.022, eye);
        canvas.drawCircle(Offset(c.dx + s * 0.08, c.dy + s * 0.10), s * 0.022, eye);
        // Strong mustache
        final must = Paint()..color = const Color(0xFF2C2C2C)..strokeWidth = s * 0.025..strokeCap = StrokeCap.round;
        final leftM = Path()..moveTo(c.dx, c.dy + s * 0.18)..quadraticBezierTo(c.dx - s * 0.08, c.dy + s * 0.20, c.dx - s * 0.16, c.dy + s * 0.16);
        final rightM = Path()..moveTo(c.dx, c.dy + s * 0.18)..quadraticBezierTo(c.dx + s * 0.08, c.dy + s * 0.20, c.dx + s * 0.16, c.dy + s * 0.16);
        canvas.drawPath(leftM, must);
        canvas.drawPath(rightM, must);
        break;

      // ═══════════════════════════════════════════════════════
      case 3: // VIKING — horned helmet, braided beard
        final helmetGray = Paint()..color = const Color(0xFF78909C);
        // Face
        canvas.drawOval(Rect.fromCenter(center: Offset(c.dx, c.dy + s * 0.08), width: s * 0.40, height: s * 0.36), skin);
        // Helmet
        final vikHelmet = Path()
          ..moveTo(c.dx - s * 0.24, c.dy + s * 0.02)
          ..quadraticBezierTo(c.dx - s * 0.26, c.dy - s * 0.14, c.dx, c.dy - s * 0.22)
          ..quadraticBezierTo(c.dx + s * 0.26, c.dy - s * 0.14, c.dx + s * 0.24, c.dy + s * 0.02)
          ..close();
        canvas.drawPath(vikHelmet, helmetGray);
        // Nose guard
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(c.dx, c.dy + s * 0.02), width: s * 0.04, height: s * 0.16), Radius.circular(s * 0.01)),
          Paint()..color = const Color(0xFF607D8B),
        );
        // Horns
        final leftHorn = Path()
          ..moveTo(c.dx - s * 0.22, c.dy - s * 0.06)
          ..quadraticBezierTo(c.dx - s * 0.36, c.dy - s * 0.20, c.dx - s * 0.30, c.dy - s * 0.34);
        final rightHorn = Path()
          ..moveTo(c.dx + s * 0.22, c.dy - s * 0.06)
          ..quadraticBezierTo(c.dx + s * 0.36, c.dy - s * 0.20, c.dx + s * 0.30, c.dy - s * 0.34);
        final hornStroke = Paint()..color = const Color(0xFFF5DEB3)..style = PaintingStyle.stroke..strokeWidth = s * 0.045..strokeCap = StrokeCap.round;
        canvas.drawPath(leftHorn, hornStroke);
        canvas.drawPath(rightHorn, hornStroke);
        // Eyes
        canvas.drawCircle(Offset(c.dx - s * 0.08, c.dy + s * 0.06), s * 0.024, eye);
        canvas.drawCircle(Offset(c.dx + s * 0.08, c.dy + s * 0.06), s * 0.024, eye);
        // Braided beard
        final beard = Paint()..color = const Color(0xFFB0855A);
        for (var i = 0; i < 3; i++) {
          final bx = c.dx - s * 0.06 + i * s * 0.06;
          canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(bx - s * 0.02, c.dy + s * 0.18, s * 0.04, s * 0.16), Radius.circular(s * 0.02)),
            beard,
          );
        }
        break;

      // ═══════════════════════════════════════════════════════
      case 4: // SPARTAN — helmet with crest, strong jaw
        final bronze = Paint()..color = const Color(0xFFCD7F32);
        final crestRed = Paint()..color = const Color(0xFFD32F2F);
        // Face visible through helmet opening
        canvas.drawOval(Rect.fromCenter(center: Offset(c.dx, c.dy + s * 0.10), width: s * 0.26, height: s * 0.28), skin);
        // Helmet main shape
        final spartHelmet = Path()
          ..moveTo(c.dx - s * 0.10, c.dy + s * 0.26)
          ..lineTo(c.dx - s * 0.26, c.dy + s * 0.06)
          ..quadraticBezierTo(c.dx - s * 0.28, c.dy - s * 0.18, c.dx, c.dy - s * 0.24)
          ..quadraticBezierTo(c.dx + s * 0.28, c.dy - s * 0.18, c.dx + s * 0.26, c.dy + s * 0.06)
          ..lineTo(c.dx + s * 0.10, c.dy + s * 0.26)
          ..close();
        canvas.drawPath(spartHelmet, bronze);
        // Face opening (cut out)
        final faceHole = Path()
          ..addOval(Rect.fromCenter(center: Offset(c.dx, c.dy + s * 0.10), width: s * 0.26, height: s * 0.28));
        canvas.drawPath(faceHole, skin);
        // Crest/plume on top
        final crest = Path()
          ..moveTo(c.dx, c.dy - s * 0.24)
          ..quadraticBezierTo(c.dx + s * 0.06, c.dy - s * 0.40, c.dx, c.dy - s * 0.44)
          ..quadraticBezierTo(c.dx - s * 0.06, c.dy - s * 0.40, c.dx, c.dy - s * 0.24);
        canvas.drawPath(crest, crestRed);
        // Plume going back
        for (var i = 0; i < 6; i++) {
          final py = c.dy - s * 0.24 - i * s * 0.035;
          canvas.drawCircle(Offset(c.dx, py), s * 0.035, crestRed);
        }
        // Fierce eyes
        canvas.drawCircle(Offset(c.dx - s * 0.06, c.dy + s * 0.08), s * 0.022, eye);
        canvas.drawCircle(Offset(c.dx + s * 0.06, c.dy + s * 0.08), s * 0.022, eye);
        // Nose guard
        canvas.drawLine(Offset(c.dx, c.dy - s * 0.02), Offset(c.dx, c.dy + s * 0.12), Paint()..color = const Color(0xFFB8860B)..strokeWidth = s * 0.025);
        // Determined mouth
        canvas.drawLine(Offset(c.dx - s * 0.05, c.dy + s * 0.18), Offset(c.dx + s * 0.05, c.dy + s * 0.18), line);
        break;

      // ═══════════════════════════════════════════════════════
      case 5: // WITCH — pointed hat, flowing hair, mysterious
        final hatPurple = Paint()..color = const Color(0xFF6A1B9A);
        final hair = Paint()..color = const Color(0xFF1A1A1A);
        // Flowing hair on sides
        canvas.drawOval(Rect.fromCenter(center: Offset(c.dx - s * 0.18, c.dy + s * 0.10), width: s * 0.16, height: s * 0.46), hair);
        canvas.drawOval(Rect.fromCenter(center: Offset(c.dx + s * 0.18, c.dy + s * 0.10), width: s * 0.16, height: s * 0.46), hair);
        // Face
        canvas.drawOval(Rect.fromCenter(center: Offset(c.dx, c.dy + s * 0.12), width: s * 0.34, height: s * 0.36), skin);
        // Pointed hat
        final hatPath = Path()
          ..moveTo(c.dx - s * 0.22, c.dy + s * 0.02)
          ..lineTo(c.dx + s * 0.08, c.dy - s * 0.44)
          ..lineTo(c.dx + s * 0.22, c.dy + s * 0.02)
          ..close();
        canvas.drawPath(hatPath, hatPurple);
        // Hat brim
        canvas.drawOval(Rect.fromCenter(center: Offset(c.dx, c.dy + s * 0.02), width: s * 0.54, height: s * 0.10), hatPurple);
        // Hat band
        canvas.drawLine(Offset(c.dx - s * 0.18, c.dy - s * 0.01), Offset(c.dx + s * 0.18, c.dy - s * 0.01),
            Paint()..color = const Color(0xFFDAA520)..strokeWidth = s * 0.025);
        // Mysterious eyes
        canvas.drawCircle(Offset(c.dx - s * 0.07, c.dy + s * 0.10), s * 0.024, Paint()..color = const Color(0xFF7B1FA2));
        canvas.drawCircle(Offset(c.dx + s * 0.07, c.dy + s * 0.10), s * 0.024, Paint()..color = const Color(0xFF7B1FA2));
        canvas.drawCircle(Offset(c.dx - s * 0.07, c.dy + s * 0.10), s * 0.012, eye);
        canvas.drawCircle(Offset(c.dx + s * 0.07, c.dy + s * 0.10), s * 0.012, eye);
        // Smirk
        final smirk = Path()..moveTo(c.dx - s * 0.04, c.dy + s * 0.21)..quadraticBezierTo(c.dx + s * 0.04, c.dy + s * 0.24, c.dx + s * 0.08, c.dy + s * 0.19);
        canvas.drawPath(smirk, line);
        break;

      // ═══════════════════════════════════════════════════════
      case 6: // CLEOPATRA — Egyptian headdress, kohl eyes
        final goldPaint = Paint()..color = const Color(0xFFDAA520);
        final bluePaint = Paint()..color = const Color(0xFF1565C0);
        // Face
        canvas.drawOval(Rect.fromCenter(center: Offset(c.dx, c.dy + s * 0.08), width: s * 0.34, height: s * 0.38), skin);
        // Nemes headdress (side panels)
        final leftPanel = Path()
          ..moveTo(c.dx - s * 0.18, c.dy - s * 0.06)
          ..lineTo(c.dx - s * 0.26, c.dy + s * 0.30)
          ..lineTo(c.dx - s * 0.12, c.dy + s * 0.30)
          ..lineTo(c.dx - s * 0.12, c.dy - s * 0.06)
          ..close();
        final rightPanel = Path()
          ..moveTo(c.dx + s * 0.18, c.dy - s * 0.06)
          ..lineTo(c.dx + s * 0.26, c.dy + s * 0.30)
          ..lineTo(c.dx + s * 0.12, c.dy + s * 0.30)
          ..lineTo(c.dx + s * 0.12, c.dy - s * 0.06)
          ..close();
        canvas.drawPath(leftPanel, bluePaint);
        canvas.drawPath(rightPanel, bluePaint);
        // Stripes on panels
        final stripe = Paint()..color = const Color(0xFFDAA520)..strokeWidth = s * 0.012;
        for (var i = 0; i < 4; i++) {
          final y = c.dy + s * 0.02 + i * s * 0.07;
          canvas.drawLine(Offset(c.dx - s * 0.25, y), Offset(c.dx - s * 0.12, y), stripe);
          canvas.drawLine(Offset(c.dx + s * 0.12, y), Offset(c.dx + s * 0.25, y), stripe);
        }
        // Crown top
        final crown = Path()
          ..moveTo(c.dx - s * 0.18, c.dy - s * 0.06)
          ..quadraticBezierTo(c.dx, c.dy - s * 0.22, c.dx + s * 0.18, c.dy - s * 0.06)
          ..close();
        canvas.drawPath(crown, bluePaint);
        // Gold band
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(c.dx, c.dy - s * 0.06), width: s * 0.40, height: s * 0.04), Radius.circular(s * 0.02)),
          goldPaint,
        );
        // Cobra emblem (uraeus)
        canvas.drawCircle(Offset(c.dx, c.dy - s * 0.10), s * 0.03, goldPaint);
        // Kohl-lined eyes
        final kohl = Paint()..color = const Color(0xFF1A1A1A)..strokeWidth = s * 0.02..strokeCap = StrokeCap.round;
        canvas.drawCircle(Offset(c.dx - s * 0.07, c.dy + s * 0.06), s * 0.022, eye);
        canvas.drawCircle(Offset(c.dx + s * 0.07, c.dy + s * 0.06), s * 0.022, eye);
        // Kohl wings
        canvas.drawLine(Offset(c.dx - s * 0.10, c.dy + s * 0.06), Offset(c.dx - s * 0.16, c.dy + s * 0.03), kohl);
        canvas.drawLine(Offset(c.dx + s * 0.10, c.dy + s * 0.06), Offset(c.dx + s * 0.16, c.dy + s * 0.03), kohl);
        // Regal lips
        final lips = Path()..moveTo(c.dx - s * 0.04, c.dy + s * 0.17)..quadraticBezierTo(c.dx, c.dy + s * 0.20, c.dx + s * 0.04, c.dy + s * 0.17);
        canvas.drawPath(lips, Paint()..color = const Color(0xFFC62828)..style = PaintingStyle.stroke..strokeWidth = s * 0.018..strokeCap = StrokeCap.round);
        break;

      // ═══════════════════════════════════════════════════════
      case 7: // NINJA — mask, intense eyes, headband
        final maskColor = Paint()..color = const Color(0xFF222222);
        final bandColor = Paint()..color = const Color(0xFF1A1A1A);
        // Head shape (mostly hidden)
        canvas.drawCircle(Offset(c.dx, c.dy + s * 0.04), s * 0.24, maskColor);
        // Exposed eye area (skin band)
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(c.dx, c.dy + s * 0.02), width: s * 0.46, height: s * 0.14), Radius.circular(s * 0.04)),
          skin,
        );
        // Headband
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(c.dx, c.dy - s * 0.10), width: s * 0.50, height: s * 0.06), Radius.circular(s * 0.03)),
          bandColor,
        );
        // Headband tail
        canvas.drawLine(Offset(c.dx + s * 0.22, c.dy - s * 0.10), Offset(c.dx + s * 0.34, c.dy - s * 0.16),
            Paint()..color = const Color(0xFF1A1A1A)..strokeWidth = s * 0.03..strokeCap = StrokeCap.round);
        canvas.drawLine(Offset(c.dx + s * 0.22, c.dy - s * 0.10), Offset(c.dx + s * 0.32, c.dy - s * 0.06),
            Paint()..color = const Color(0xFF1A1A1A)..strokeWidth = s * 0.025..strokeCap = StrokeCap.round);
        // Intense eyes
        canvas.drawCircle(Offset(c.dx - s * 0.10, c.dy + s * 0.02), s * 0.032, eye);
        canvas.drawCircle(Offset(c.dx + s * 0.10, c.dy + s * 0.02), s * 0.032, eye);
        // Eye glint
        canvas.drawCircle(Offset(c.dx - s * 0.095, c.dy + s * 0.015), s * 0.010, white);
        canvas.drawCircle(Offset(c.dx + s * 0.105, c.dy + s * 0.015), s * 0.010, white);
        // Narrow brows
        final browP = Paint()..color = const Color(0xFF1A1A1A)..strokeWidth = s * 0.02..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(c.dx - s * 0.16, c.dy - s * 0.04), Offset(c.dx - s * 0.06, c.dy - s * 0.02), browP);
        canvas.drawLine(Offset(c.dx + s * 0.06, c.dy - s * 0.02), Offset(c.dx + s * 0.16, c.dy - s * 0.04), browP);
        break;

      // ═══════════════════════════════════════════════════════
      case 8: // VALKYRIE — winged helmet, warrior woman
        final silver = Paint()..color = const Color(0xFFB0BEC5);
        final wingColor = Paint()..color = const Color(0xFFECEFF1);
        // Face
        canvas.drawOval(Rect.fromCenter(center: Offset(c.dx, c.dy + s * 0.10), width: s * 0.34, height: s * 0.36), skin);
        // Flowing hair on sides
        final hairGold = Paint()..color = const Color(0xFFDAA520);
        canvas.drawOval(Rect.fromCenter(center: Offset(c.dx - s * 0.18, c.dy + s * 0.14), width: s * 0.12, height: s * 0.40), hairGold);
        canvas.drawOval(Rect.fromCenter(center: Offset(c.dx + s * 0.18, c.dy + s * 0.14), width: s * 0.12, height: s * 0.40), hairGold);
        // Helmet
        final vHelmet = Path()
          ..moveTo(c.dx - s * 0.20, c.dy + s * 0.02)
          ..quadraticBezierTo(c.dx - s * 0.22, c.dy - s * 0.14, c.dx, c.dy - s * 0.20)
          ..quadraticBezierTo(c.dx + s * 0.22, c.dy - s * 0.14, c.dx + s * 0.20, c.dy + s * 0.02)
          ..close();
        canvas.drawPath(vHelmet, silver);
        // Wings on helmet
        final leftWing = Path()
          ..moveTo(c.dx - s * 0.18, c.dy - s * 0.08)
          ..lineTo(c.dx - s * 0.38, c.dy - s * 0.30)
          ..lineTo(c.dx - s * 0.32, c.dy - s * 0.18)
          ..lineTo(c.dx - s * 0.36, c.dy - s * 0.12)
          ..lineTo(c.dx - s * 0.22, c.dy - s * 0.04)
          ..close();
        final rightWing = Path()
          ..moveTo(c.dx + s * 0.18, c.dy - s * 0.08)
          ..lineTo(c.dx + s * 0.38, c.dy - s * 0.30)
          ..lineTo(c.dx + s * 0.32, c.dy - s * 0.18)
          ..lineTo(c.dx + s * 0.36, c.dy - s * 0.12)
          ..lineTo(c.dx + s * 0.22, c.dy - s * 0.04)
          ..close();
        canvas.drawPath(leftWing, wingColor);
        canvas.drawPath(rightWing, wingColor);
        // Eyes
        canvas.drawCircle(Offset(c.dx - s * 0.07, c.dy + s * 0.08), s * 0.022, Paint()..color = const Color(0xFF1565C0));
        canvas.drawCircle(Offset(c.dx + s * 0.07, c.dy + s * 0.08), s * 0.022, Paint()..color = const Color(0xFF1565C0));
        canvas.drawCircle(Offset(c.dx - s * 0.07, c.dy + s * 0.08), s * 0.010, eye);
        canvas.drawCircle(Offset(c.dx + s * 0.07, c.dy + s * 0.08), s * 0.010, eye);
        // Slight smile
        final vSmile = Path()..moveTo(c.dx - s * 0.05, c.dy + s * 0.20)..quadraticBezierTo(c.dx, c.dy + s * 0.23, c.dx + s * 0.05, c.dy + s * 0.20);
        canvas.drawPath(vSmile, line);
        break;

      // ═══════════════════════════════════════════════════════
      case 9: // SHAMAN — feathered headdress, tribal markings
        final featherColors = [const Color(0xFFD32F2F), const Color(0xFFFF8F00), const Color(0xFF388E3C), const Color(0xFF1565C0), const Color(0xFF6A1B9A)];
        // Face
        canvas.drawCircle(Offset(c.dx, c.dy + s * 0.08), s * 0.22, skinDark);
        // Feathered headdress
        for (var i = 0; i < 5; i++) {
          final angle = -0.5 + i * 0.25;
          final fx = c.dx + s * 0.20 * math.sin(angle);
          final fy = c.dy - s * 0.10 - s * 0.18;
          final feather = Path()
            ..moveTo(c.dx + s * 0.10 * math.sin(angle), c.dy - s * 0.06)
            ..quadraticBezierTo(fx - s * 0.02, fy + s * 0.06, fx, fy);
          canvas.drawPath(feather, Paint()..color = featherColors[i]..style = PaintingStyle.stroke..strokeWidth = s * 0.04..strokeCap = StrokeCap.round);
        }
        // Headband
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(c.dx, c.dy - s * 0.04), width: s * 0.48, height: s * 0.05), Radius.circular(s * 0.02)),
          Paint()..color = const Color(0xFF8D6E63),
        );
        // Tribal face markings
        final tribal = Paint()..color = const Color(0xFFC62828)..strokeWidth = s * 0.015..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(c.dx - s * 0.14, c.dy + s * 0.06), Offset(c.dx - s * 0.06, c.dy + s * 0.10), tribal);
        canvas.drawLine(Offset(c.dx - s * 0.14, c.dy + s * 0.10), Offset(c.dx - s * 0.06, c.dy + s * 0.14), tribal);
        canvas.drawLine(Offset(c.dx + s * 0.06, c.dy + s * 0.10), Offset(c.dx + s * 0.14, c.dy + s * 0.06), tribal);
        canvas.drawLine(Offset(c.dx + s * 0.06, c.dy + s * 0.14), Offset(c.dx + s * 0.14, c.dy + s * 0.10), tribal);
        // Wise eyes
        canvas.drawCircle(Offset(c.dx - s * 0.07, c.dy + s * 0.06), s * 0.022, eye);
        canvas.drawCircle(Offset(c.dx + s * 0.07, c.dy + s * 0.06), s * 0.022, eye);
        // Neutral wise mouth
        canvas.drawLine(Offset(c.dx - s * 0.04, c.dy + s * 0.20), Offset(c.dx + s * 0.04, c.dy + s * 0.20), line);
        break;

      // ═══════════════════════════════════════════════════════
      case 10: // KNIGHT — medieval visor helmet
        final armor = Paint()..color = const Color(0xFF78909C);
        final armorDark = Paint()..color = const Color(0xFF546E7A);
        // Helmet shape
        final kHelmet = Path()
          ..moveTo(c.dx - s * 0.24, c.dy + s * 0.18)
          ..lineTo(c.dx - s * 0.24, c.dy - s * 0.04)
          ..quadraticBezierTo(c.dx - s * 0.26, c.dy - s * 0.20, c.dx, c.dy - s * 0.26)
          ..quadraticBezierTo(c.dx + s * 0.26, c.dy - s * 0.20, c.dx + s * 0.24, c.dy - s * 0.04)
          ..lineTo(c.dx + s * 0.24, c.dy + s * 0.18)
          ..close();
        canvas.drawPath(kHelmet, armor);
        // Face opening slit
        final visorSlit = Path()
          ..moveTo(c.dx - s * 0.16, c.dy + s * 0.04)
          ..lineTo(c.dx - s * 0.12, c.dy + s * 0.02)
          ..lineTo(c.dx + s * 0.12, c.dy + s * 0.02)
          ..lineTo(c.dx + s * 0.16, c.dy + s * 0.04)
          ..lineTo(c.dx + s * 0.14, c.dy + s * 0.14)
          ..lineTo(c.dx - s * 0.14, c.dy + s * 0.14)
          ..close();
        canvas.drawPath(visorSlit, Paint()..color = const Color(0xFF1A1A1A));
        // Eyes in shadow
        canvas.drawCircle(Offset(c.dx - s * 0.06, c.dy + s * 0.06), s * 0.020, Paint()..color = const Color(0xFF90CAF9));
        canvas.drawCircle(Offset(c.dx + s * 0.06, c.dy + s * 0.06), s * 0.020, Paint()..color = const Color(0xFF90CAF9));
        // Rivets on helmet
        for (var i = 0; i < 3; i++) {
          canvas.drawCircle(Offset(c.dx - s * 0.16 + i * s * 0.16, c.dy - s * 0.10), s * 0.015, armorDark);
        }
        // Center ridge
        canvas.drawLine(Offset(c.dx, c.dy - s * 0.26), Offset(c.dx, c.dy + s * 0.02),
            Paint()..color = const Color(0xFF546E7A)..strokeWidth = s * 0.025);
        // Breathing holes
        for (var i = 0; i < 3; i++) {
          final hy = c.dy + s * 0.16 + i * s * 0.025;
          canvas.drawLine(Offset(c.dx - s * 0.06, hy), Offset(c.dx + s * 0.06, hy),
              Paint()..color = const Color(0xFF37474F)..strokeWidth = s * 0.01);
        }
        break;

      // ═══════════════════════════════════════════════════════
      case 11: // PHARAOH — nemes headdress, commanding
        final blueGold = Paint()..color = const Color(0xFF1565C0);
        final goldPaint = Paint()..color = const Color(0xFFDAA520);
        // Face
        canvas.drawOval(Rect.fromCenter(center: Offset(c.dx, c.dy + s * 0.08), width: s * 0.32, height: s * 0.36), skinDark);
        // Nemes headdress panels
        final lPanel = Path()
          ..moveTo(c.dx - s * 0.16, c.dy - s * 0.04)
          ..lineTo(c.dx - s * 0.24, c.dy + s * 0.32)
          ..lineTo(c.dx - s * 0.10, c.dy + s * 0.32)
          ..lineTo(c.dx - s * 0.10, c.dy - s * 0.04)
          ..close();
        final rPanel = Path()
          ..moveTo(c.dx + s * 0.16, c.dy - s * 0.04)
          ..lineTo(c.dx + s * 0.24, c.dy + s * 0.32)
          ..lineTo(c.dx + s * 0.10, c.dy + s * 0.32)
          ..lineTo(c.dx + s * 0.10, c.dy - s * 0.04)
          ..close();
        canvas.drawPath(lPanel, blueGold);
        canvas.drawPath(rPanel, blueGold);
        // Gold stripes
        final gs = Paint()..color = const Color(0xFFDAA520)..strokeWidth = s * 0.01;
        for (var i = 0; i < 5; i++) {
          final y = c.dy + s * 0.04 + i * s * 0.06;
          canvas.drawLine(Offset(c.dx - s * 0.23, y), Offset(c.dx - s * 0.10, y), gs);
          canvas.drawLine(Offset(c.dx + s * 0.10, y), Offset(c.dx + s * 0.23, y), gs);
        }
        // Crown dome
        final dome = Path()
          ..moveTo(c.dx - s * 0.18, c.dy - s * 0.04)
          ..quadraticBezierTo(c.dx, c.dy - s * 0.22, c.dx + s * 0.18, c.dy - s * 0.04)
          ..close();
        canvas.drawPath(dome, blueGold);
        // Gold band
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(c.dx, c.dy - s * 0.04), width: s * 0.40, height: s * 0.04), Radius.circular(s * 0.02)),
          goldPaint,
        );
        // Cobra (uraeus)
        final cobra = Path()
          ..moveTo(c.dx, c.dy - s * 0.06)
          ..quadraticBezierTo(c.dx - s * 0.04, c.dy - s * 0.14, c.dx, c.dy - s * 0.18)
          ..quadraticBezierTo(c.dx + s * 0.04, c.dy - s * 0.14, c.dx, c.dy - s * 0.06);
        canvas.drawPath(cobra, goldPaint);
        // Commanding eyes
        canvas.drawCircle(Offset(c.dx - s * 0.06, c.dy + s * 0.06), s * 0.022, eye);
        canvas.drawCircle(Offset(c.dx + s * 0.06, c.dy + s * 0.06), s * 0.022, eye);
        // Kohl lines
        final kohlP = Paint()..color = const Color(0xFF1A1A1A)..strokeWidth = s * 0.015..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(c.dx - s * 0.09, c.dy + s * 0.06), Offset(c.dx - s * 0.14, c.dy + s * 0.04), kohlP);
        canvas.drawLine(Offset(c.dx + s * 0.09, c.dy + s * 0.06), Offset(c.dx + s * 0.14, c.dy + s * 0.04), kohlP);
        // Pharaoh beard
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(c.dx - s * 0.03, c.dy + s * 0.20, s * 0.06, s * 0.14), Radius.circular(s * 0.02)),
          goldPaint,
        );
        break;

      // ═══════════════════════════════════════════════════════
      case 12: // DRUID — hood/cowl, glowing eyes
        final hood = Paint()..color = const Color(0xFF2E7D32);
        final hoodDark = Paint()..color = const Color(0xFF1B5E20);
        // Hood shape
        final hoodPath = Path()
          ..moveTo(c.dx - s * 0.28, c.dy + s * 0.24)
          ..quadraticBezierTo(c.dx - s * 0.32, c.dy - s * 0.06, c.dx, c.dy - s * 0.30)
          ..quadraticBezierTo(c.dx + s * 0.32, c.dy - s * 0.06, c.dx + s * 0.28, c.dy + s * 0.24)
          ..close();
        canvas.drawPath(hoodPath, hood);
        // Inner shadow of hood
        final innerHood = Path()
          ..moveTo(c.dx - s * 0.20, c.dy + s * 0.20)
          ..quadraticBezierTo(c.dx - s * 0.22, c.dy + s * 0.02, c.dx, c.dy - s * 0.12)
          ..quadraticBezierTo(c.dx + s * 0.22, c.dy + s * 0.02, c.dx + s * 0.20, c.dy + s * 0.20)
          ..close();
        canvas.drawPath(innerHood, hoodDark);
        // Dark face in shadow
        canvas.drawOval(Rect.fromCenter(center: Offset(c.dx, c.dy + s * 0.10), width: s * 0.28, height: s * 0.30), Paint()..color = const Color(0xFF0D1B0D));
        // Glowing eyes
        final glow = Paint()..color = const Color(0xFF76FF03);
        canvas.drawCircle(Offset(c.dx - s * 0.07, c.dy + s * 0.06), s * 0.030, glow);
        canvas.drawCircle(Offset(c.dx + s * 0.07, c.dy + s * 0.06), s * 0.030, glow);
        // Eye pupils
        canvas.drawCircle(Offset(c.dx - s * 0.07, c.dy + s * 0.06), s * 0.014, eye);
        canvas.drawCircle(Offset(c.dx + s * 0.07, c.dy + s * 0.06), s * 0.014, eye);
        // Glow effect
        canvas.drawCircle(Offset(c.dx - s * 0.07, c.dy + s * 0.06), s * 0.045, Paint()..color = const Color(0xFF76FF03).withValues(alpha: 0.15));
        canvas.drawCircle(Offset(c.dx + s * 0.07, c.dy + s * 0.06), s * 0.045, Paint()..color = const Color(0xFF76FF03).withValues(alpha: 0.15));
        // Staff hint at bottom
        canvas.drawLine(Offset(c.dx + s * 0.16, c.dy + s * 0.10), Offset(c.dx + s * 0.20, c.dy + s * 0.36),
            Paint()..color = const Color(0xFF5D4037)..strokeWidth = s * 0.03..strokeCap = StrokeCap.round);
        // Staff gem
        canvas.drawCircle(Offset(c.dx + s * 0.155, c.dy + s * 0.08), s * 0.02, glow);
        break;

      default:
        canvas.drawCircle(c, s * 0.22, skin);
        canvas.drawCircle(Offset(c.dx - s * 0.06, c.dy), s * 0.02, eye);
        canvas.drawCircle(Offset(c.dx + s * 0.06, c.dy), s * 0.02, eye);
    }
  }

  @override
  bool shouldRepaint(AvatarPainter oldDelegate) => avatarId != oldDelegate.avatarId;
}
