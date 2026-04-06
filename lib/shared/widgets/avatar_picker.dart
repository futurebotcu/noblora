import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';

/// 50 custom-drawn character avatars using CustomPainter.
/// IDs 1-25: Male warriors, IDs 26-50: Female warriors.
class AvatarPicker extends StatelessWidget {
  final int? selectedId;
  final ValueChanged<int> onSelected;

  const AvatarPicker({super.key, this.selectedId, required this.onSelected});

  static const avatarCount = 50;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
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
                    ? Border.all(color: Colors.white, width: 2.5)
                    : Border.all(color: Colors.transparent, width: 2.5),
                boxShadow: sel
                    ? [BoxShadow(color: AppColors.emerald600.withValues(alpha: 0.3), blurRadius: 12)]
                    : null,
              ),
              child: ClipOval(
                child: CustomPaint(
                  size: const Size(64, 64),
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

  // 50 background colors
  static const _bgColors = [
    // ── MALE 1-25 ──
    Color(0xFF1A1A2E), //  1 Samurai
    Color(0xFF2D1B00), //  2 Janissary
    Color(0xFF1B3A4B), //  3 Viking
    Color(0xFF4A0000), //  4 Spartan
    Color(0xFF1A1A1A), //  5 Knight
    Color(0xFF2E2A00), //  6 Pharaoh
    Color(0xFF0A0A0A), //  7 Ninja
    Color(0xFF2E1A00), //  8 Shaman
    Color(0xFF0A2E0A), //  9 Druid
    Color(0xFF4A1A00), // 10 Turkish Deli
    Color(0xFF3D2B1F), // 11 Arab Desert Warrior
    Color(0xFF2A1A0A), // 12 Mongol Warrior
    Color(0xFF3A0A0A), // 13 Roman Centurion
    Color(0xFF1A3A2A), // 14 Aztec Eagle Warrior
    Color(0xFF2A1A00), // 15 Zulu Warrior
    Color(0xFF1A2A1A), // 16 Maori Warrior
    Color(0xFF2A1A3A), // 17 Persian Immortal
    Color(0xFF3A1A1A), // 18 Chinese Imperial Guard
    Color(0xFF1A2A3A), // 19 Scottish Highlander
    Color(0xFF3A2A0A), // 20 Rajput Warrior
    Color(0xFF1A3A3A), // 21 Cossack
    Color(0xFF2A2A2A), // 22 Templar Knight
    Color(0xFF3A2A1A), // 23 Gladiator
    Color(0xFF1A1A3A), // 24 Berserker
    Color(0xFF2A0A1A), // 25 Shogun
    // ── FEMALE 26-50 ──
    Color(0xFF1A2E4A), // 26 Valkyrie
    Color(0xFF0A2E1A), // 27 Cleopatra
    Color(0xFF1A0A2E), // 28 Witch
    Color(0xFF2E0A1A), // 29 Amazon Warrior
    Color(0xFF3A0A2A), // 30 Geisha
    Color(0xFF0A3A2A), // 31 Celtic Queen
    Color(0xFF2E1A0A), // 32 Nefertiti
    Color(0xFF1A0A1A), // 33 Chinese Warrior Woman
    Color(0xFF3A1A0A), // 34 Indian Rani
    Color(0xFF2A0A3A), // 35 Persian Warrior Woman
    Color(0xFF1A3A4A), // 36 Shieldmaiden
    Color(0xFF0A2A1A), // 37 Mayan Priestess
    Color(0xFF1A1A3A), // 38 Pirate Queen
    Color(0xFF0A0A1A), // 39 Kunoichi
    Color(0xFF3A0A0A), // 40 Ottoman Sultana
    Color(0xFF1A2A0A), // 41 African Queen
    Color(0xFF2A1A2A), // 42 Korean Hwarang
    Color(0xFF2A2A0A), // 43 Apache Warrior Woman
    Color(0xFF0A1A3A), // 44 Artemis
    Color(0xFF2A3A1A), // 45 Boudica
    Color(0xFF1A1A4A), // 46 Joan of Arc
    Color(0xFF3A1A2A), // 47 Tomoe Gozen
    Color(0xFF2A2A1A), // 48 Zenobia
    Color(0xFF1A3A1A), // 49 Scythian Warrior Woman
    Color(0xFF0A2A3A), // 50 Hawaiian Queen
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final s = size.width;
    final bg = _bgColors[(avatarId - 1).clamp(0, 49)];

    canvas.drawCircle(c, r, Paint()..color = bg);

    // Common paints
    final skin = Paint()..color = const Color(0xFFF5DEB3);
    final skinDark = Paint()..color = const Color(0xFFDEB887);
    final skinOlive = Paint()..color = const Color(0xFFD2A679);
    final skinBrown = Paint()..color = const Color(0xFFA0764A);
    final skinDeep = Paint()..color = const Color(0xFF8B5E3C);
    final eye = Paint()..color = const Color(0xFF1A1A1A);
    final white = Paint()..color = Colors.white;
    final gold = Paint()..color = const Color(0xFFDAA520);
    final red = Paint()..color = const Color(0xFFC62828);
    final line = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.022
      ..strokeCap = StrokeCap.round;

    switch (avatarId) {
      // ═══════════════════════════════════════════════════════════════════
      // MALE AVATARS 1-25
      // ═══════════════════════════════════════════════════════════════════

      case 1: // SAMURAI — kabuto helmet, fierce eyes
        _drawFace(canvas, c, s, skin, yOff: 0.10, w: 0.38, h: 0.32);
        // Kabuto helmet dome
        final helmet = Path()
          ..moveTo(c.dx - s * 0.28, c.dy + s * 0.02)
          ..quadraticBezierTo(c.dx - s * 0.30, c.dy - s * 0.18, c.dx, c.dy - s * 0.28)
          ..quadraticBezierTo(c.dx + s * 0.30, c.dy - s * 0.18, c.dx + s * 0.28, c.dy + s * 0.02)
          ..close();
        canvas.drawPath(helmet, Paint()..color = const Color(0xFF8B0000));
        // Gold crest
        final crest = Path()
          ..moveTo(c.dx - s * 0.04, c.dy - s * 0.26)
          ..lineTo(c.dx, c.dy - s * 0.42)
          ..lineTo(c.dx + s * 0.04, c.dy - s * 0.26)
          ..close();
        canvas.drawPath(crest, gold);
        // Helmet brim
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(c.dx, c.dy + s * 0.02), width: s * 0.60, height: s * 0.06), Radius.circular(s * 0.03)), Paint()..color = const Color(0xFF5C0000));
        canvas.drawCircle(Offset(c.dx, c.dy - s * 0.12), s * 0.04, gold);
        _drawEyes(canvas, c, s, eye, yOff: 0.10);
        // Angry brows
        _drawAngryBrows(canvas, c, s);
        // Menpo
        final menpo = Path()..moveTo(c.dx - s * 0.16, c.dy + s * 0.16)..quadraticBezierTo(c.dx, c.dy + s * 0.28, c.dx + s * 0.16, c.dy + s * 0.16);
        canvas.drawPath(menpo, Paint()..color = const Color(0xFF333333));
        canvas.drawLine(Offset(c.dx - s * 0.08, c.dy + s * 0.20), Offset(c.dx + s * 0.08, c.dy + s * 0.20), Paint()..color = const Color(0xFF111111)..strokeWidth = s * 0.015);
        break;

      case 2: // JANISSARY — tall börk hat, strong mustache
        _drawFace(canvas, c, s, skinDark, yOff: 0.12, w: 0.38, h: 0.34);
        final hat = Path()
          ..moveTo(c.dx - s * 0.14, c.dy + s * 0.02)
          ..lineTo(c.dx - s * 0.12, c.dy - s * 0.32)
          ..quadraticBezierTo(c.dx, c.dy - s * 0.38, c.dx + s * 0.12, c.dy - s * 0.32)
          ..lineTo(c.dx + s * 0.14, c.dy + s * 0.02)
          ..close();
        canvas.drawPath(hat, white);
        // Red plume
        final plume = Path()..moveTo(c.dx, c.dy - s * 0.32)..quadraticBezierTo(c.dx + s * 0.12, c.dy - s * 0.42, c.dx + s * 0.06, c.dy - s * 0.28);
        canvas.drawPath(plume, Paint()..color = const Color(0xFFC62828)..style = PaintingStyle.stroke..strokeWidth = s * 0.04..strokeCap = StrokeCap.round);
        // Gold band
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(c.dx, c.dy + s * 0.01), width: s * 0.30, height: s * 0.05), Radius.circular(s * 0.02)), gold);
        _drawEyes(canvas, c, s, eye, yOff: 0.10);
        _drawMustache(canvas, c, s, const Color(0xFF2C2C2C));
        break;

      case 3: // VIKING — horned helmet, braided beard
        _drawFace(canvas, c, s, skin, yOff: 0.10, w: 0.40, h: 0.34);
        final helmetGray = Paint()..color = const Color(0xFF78909C);
        // Helmet
        final vh = Path()
          ..moveTo(c.dx - s * 0.24, c.dy + s * 0.04)
          ..quadraticBezierTo(c.dx, c.dy - s * 0.26, c.dx + s * 0.24, c.dy + s * 0.04)
          ..close();
        canvas.drawPath(vh, helmetGray);
        // Nose guard
        canvas.drawLine(Offset(c.dx, c.dy - s * 0.08), Offset(c.dx, c.dy + s * 0.14), Paint()..color = const Color(0xFF607D8B)..strokeWidth = s * 0.03);
        // Horns
        final horn = Paint()..color = const Color(0xFFE0D6B8);
        canvas.drawLine(Offset(c.dx - s * 0.24, c.dy - s * 0.02), Offset(c.dx - s * 0.36, c.dy - s * 0.20), horn..strokeWidth = s * 0.04..strokeCap = StrokeCap.round);
        canvas.drawLine(Offset(c.dx + s * 0.24, c.dy - s * 0.02), Offset(c.dx + s * 0.36, c.dy - s * 0.20), horn);
        _drawEyes(canvas, c, s, eye, yOff: 0.10);
        // Beard braids
        final beard = Paint()..color = const Color(0xFFD4A463);
        for (var j = 0; j < 3; j++) {
          canvas.drawOval(Rect.fromCenter(center: Offset(c.dx - s * 0.06 + j * s * 0.06, c.dy + s * 0.28), width: s * 0.06, height: s * 0.10), beard);
        }
        break;

      case 4: // SPARTAN — bronze helmet with crest
        _drawFace(canvas, c, s, skinOlive, yOff: 0.12, w: 0.28, h: 0.30);
        final bronze = Paint()..color = const Color(0xFFCD7F32);
        // Helmet
        final sh = Path()
          ..moveTo(c.dx - s * 0.28, c.dy + s * 0.16)
          ..quadraticBezierTo(c.dx - s * 0.30, c.dy - s * 0.10, c.dx, c.dy - s * 0.24)
          ..quadraticBezierTo(c.dx + s * 0.30, c.dy - s * 0.10, c.dx + s * 0.28, c.dy + s * 0.16)
          ..close();
        canvas.drawPath(sh, bronze);
        // Red crest
        for (var j = 0; j < 6; j++) {
          canvas.drawCircle(Offset(c.dx, c.dy - s * 0.22 + j * s * 0.06), s * 0.04, red);
        }
        // Nose guard
        canvas.drawLine(Offset(c.dx, c.dy - s * 0.08), Offset(c.dx, c.dy + s * 0.12), Paint()..color = const Color(0xFFB8860B)..strokeWidth = s * 0.025);
        _drawEyes(canvas, c, s, eye, yOff: 0.10);
        _drawAngryBrows(canvas, c, s);
        canvas.drawLine(Offset(c.dx - s * 0.06, c.dy + s * 0.22), Offset(c.dx + s * 0.06, c.dy + s * 0.22), line);
        break;

      case 5: // KNIGHT — medieval visor helmet
        // Full helmet
        final steel = Paint()..color = const Color(0xFF888888);
        canvas.drawOval(Rect.fromCenter(center: Offset(c.dx, c.dy + s * 0.02), width: s * 0.52, height: s * 0.56), steel);
        // Visor slit
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(c.dx, c.dy + s * 0.04), width: s * 0.36, height: s * 0.06), Radius.circular(s * 0.02)), Paint()..color = const Color(0xFF222222));
        // Glowing eyes
        canvas.drawCircle(Offset(c.dx - s * 0.08, c.dy + s * 0.04), s * 0.018, Paint()..color = const Color(0xFF4488FF));
        canvas.drawCircle(Offset(c.dx + s * 0.08, c.dy + s * 0.04), s * 0.018, Paint()..color = const Color(0xFF4488FF));
        // Rivets
        for (var j = -1; j <= 1; j++) {
          canvas.drawCircle(Offset(c.dx + j * s * 0.10, c.dy - s * 0.14), s * 0.02, Paint()..color = const Color(0xFF555555));
        }
        // Center ridge
        canvas.drawLine(Offset(c.dx, c.dy - s * 0.26), Offset(c.dx, c.dy + s * 0.04), Paint()..color = const Color(0xFF666666)..strokeWidth = s * 0.02);
        // Breathing holes
        for (var j = 0; j < 3; j++) {
          canvas.drawLine(Offset(c.dx - s * 0.10, c.dy + s * 0.14 + j * s * 0.04), Offset(c.dx + s * 0.10, c.dy + s * 0.14 + j * s * 0.04), Paint()..color = const Color(0xFF555555)..strokeWidth = s * 0.01);
        }
        break;

      case 6: // PHARAOH — nemes headdress, gold & blue
        _drawFace(canvas, c, s, skinBrown, yOff: 0.10, w: 0.36, h: 0.32);
        final blue = Paint()..color = const Color(0xFF1565C0);
        // Nemes sides
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(c.dx - s * 0.34, c.dy - s * 0.06, s * 0.14, s * 0.38), Radius.circular(s * 0.04)), blue);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(c.dx + s * 0.20, c.dy - s * 0.06, s * 0.14, s * 0.38), Radius.circular(s * 0.04)), blue);
        // Stripes
        for (var j = 0; j < 3; j++) {
          canvas.drawLine(Offset(c.dx - s * 0.34, c.dy + j * s * 0.08), Offset(c.dx - s * 0.20, c.dy + j * s * 0.08), Paint()..color = const Color(0xFFDAA520)..strokeWidth = s * 0.015);
          canvas.drawLine(Offset(c.dx + s * 0.20, c.dy + j * s * 0.08), Offset(c.dx + s * 0.34, c.dy + j * s * 0.08), Paint()..color = const Color(0xFFDAA520)..strokeWidth = s * 0.015);
        }
        // Crown dome
        final crown = Path()..moveTo(c.dx - s * 0.22, c.dy - s * 0.04)..quadraticBezierTo(c.dx, c.dy - s * 0.30, c.dx + s * 0.22, c.dy - s * 0.04)..close();
        canvas.drawPath(crown, blue);
        // Gold band
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(c.dx, c.dy - s * 0.04), width: s * 0.46, height: s * 0.05), Radius.circular(s * 0.02)), gold);
        // Cobra
        canvas.drawCircle(Offset(c.dx, c.dy - s * 0.14), s * 0.03, gold);
        _drawEyes(canvas, c, s, eye, yOff: 0.08);
        // Kohl lines
        canvas.drawLine(Offset(c.dx - s * 0.12, c.dy + s * 0.08), Offset(c.dx - s * 0.18, c.dy + s * 0.06), Paint()..color = const Color(0xFF1A1A1A)..strokeWidth = s * 0.015);
        canvas.drawLine(Offset(c.dx + s * 0.12, c.dy + s * 0.08), Offset(c.dx + s * 0.18, c.dy + s * 0.06), Paint()..color = const Color(0xFF1A1A1A)..strokeWidth = s * 0.015);
        // Gold beard
        final gBeard = Path()..moveTo(c.dx - s * 0.03, c.dy + s * 0.20)..lineTo(c.dx, c.dy + s * 0.32)..lineTo(c.dx + s * 0.03, c.dy + s * 0.20)..close();
        canvas.drawPath(gBeard, gold);
        break;

      case 7: // NINJA — mask, intense eyes
        // Black wrap
        canvas.drawOval(Rect.fromCenter(center: Offset(c.dx, c.dy + s * 0.06), width: s * 0.50, height: s * 0.50), eye);
        // Skin band (eyes area)
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(c.dx, c.dy + s * 0.06), width: s * 0.44, height: s * 0.14), Radius.circular(s * 0.06)), skin);
        // Eyes
        canvas.drawOval(Rect.fromCenter(center: Offset(c.dx - s * 0.10, c.dy + s * 0.06), width: s * 0.08, height: s * 0.06), eye);
        canvas.drawOval(Rect.fromCenter(center: Offset(c.dx + s * 0.10, c.dy + s * 0.06), width: s * 0.08, height: s * 0.06), eye);
        // White glint
        canvas.drawCircle(Offset(c.dx - s * 0.08, c.dy + s * 0.05), s * 0.015, white);
        canvas.drawCircle(Offset(c.dx + s * 0.12, c.dy + s * 0.05), s * 0.015, white);
        // Headband tail
        canvas.drawLine(Offset(c.dx + s * 0.22, c.dy - s * 0.02), Offset(c.dx + s * 0.38, c.dy - s * 0.10), Paint()..color = const Color(0xFF333333)..strokeWidth = s * 0.025..strokeCap = StrokeCap.round);
        canvas.drawLine(Offset(c.dx + s * 0.22, c.dy + s * 0.02), Offset(c.dx + s * 0.36, c.dy - s * 0.04), Paint()..color = const Color(0xFF333333)..strokeWidth = s * 0.020..strokeCap = StrokeCap.round);
        break;

      case 8: // SHAMAN — feathered headdress, tribal markings
        _drawFace(canvas, c, s, skinBrown, yOff: 0.10, w: 0.38, h: 0.34);
        // Feathers
        final featherColors = [const Color(0xFFD32F2F), const Color(0xFFFF8F00), const Color(0xFF388E3C), const Color(0xFF1976D2), const Color(0xFF7B1FA2)];
        for (var j = 0; j < 5; j++) {
          final angle = -0.4 + j * 0.2;
          final fx = c.dx + s * 0.02 * j - s * 0.04;
          canvas.drawLine(Offset(fx, c.dy - s * 0.06), Offset(fx + math.sin(angle) * s * 0.16, c.dy - s * 0.36), Paint()..color = featherColors[j]..strokeWidth = s * 0.035..strokeCap = StrokeCap.round);
        }
        // Headband
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(c.dx, c.dy - s * 0.02), width: s * 0.44, height: s * 0.05), Radius.circular(s * 0.02)), Paint()..color = const Color(0xFF795548));
        _drawEyes(canvas, c, s, eye, yOff: 0.10);
        // War paint
        canvas.drawLine(Offset(c.dx - s * 0.14, c.dy + s * 0.12), Offset(c.dx - s * 0.06, c.dy + s * 0.16), red..strokeWidth = s * 0.02);
        canvas.drawLine(Offset(c.dx + s * 0.06, c.dy + s * 0.16), Offset(c.dx + s * 0.14, c.dy + s * 0.12), red);
        canvas.drawLine(Offset(c.dx - s * 0.06, c.dy + s * 0.22), Offset(c.dx + s * 0.06, c.dy + s * 0.22), line);
        break;

      case 9: // DRUID — green hood, glowing eyes
        // Hood
        final hood = Path()
          ..moveTo(c.dx - s * 0.30, c.dy + s * 0.28)
          ..quadraticBezierTo(c.dx - s * 0.32, c.dy - s * 0.10, c.dx, c.dy - s * 0.28)
          ..quadraticBezierTo(c.dx + s * 0.32, c.dy - s * 0.10, c.dx + s * 0.30, c.dy + s * 0.28)
          ..close();
        canvas.drawPath(hood, Paint()..color = const Color(0xFF2E7D32));
        // Inner shadow
        final inner = Path()
          ..moveTo(c.dx - s * 0.22, c.dy + s * 0.24)
          ..quadraticBezierTo(c.dx - s * 0.24, c.dy, c.dx, c.dy - s * 0.14)
          ..quadraticBezierTo(c.dx + s * 0.24, c.dy, c.dx + s * 0.22, c.dy + s * 0.24)
          ..close();
        canvas.drawPath(inner, Paint()..color = const Color(0xFF1A1A1A));
        // Glowing eyes
        canvas.drawCircle(Offset(c.dx - s * 0.08, c.dy + s * 0.06), s * 0.04, Paint()..color = const Color(0xFF76FF03).withValues(alpha: 0.15));
        canvas.drawCircle(Offset(c.dx + s * 0.08, c.dy + s * 0.06), s * 0.04, Paint()..color = const Color(0xFF76FF03).withValues(alpha: 0.15));
        canvas.drawCircle(Offset(c.dx - s * 0.08, c.dy + s * 0.06), s * 0.025, Paint()..color = const Color(0xFF76FF03));
        canvas.drawCircle(Offset(c.dx + s * 0.08, c.dy + s * 0.06), s * 0.025, Paint()..color = const Color(0xFF76FF03));
        canvas.drawCircle(Offset(c.dx - s * 0.07, c.dy + s * 0.05), s * 0.008, eye);
        canvas.drawCircle(Offset(c.dx + s * 0.09, c.dy + s * 0.05), s * 0.008, eye);
        break;

      case 10: // TURKISH DELI — distinctive helmet with feathers, wild look
        _drawFace(canvas, c, s, skinOlive, yOff: 0.10, w: 0.38, h: 0.34);
        // Deli helmet (rounded with feathers)
        final delHelmet = Path()
          ..moveTo(c.dx - s * 0.22, c.dy + s * 0.02)
          ..quadraticBezierTo(c.dx, c.dy - s * 0.28, c.dx + s * 0.22, c.dy + s * 0.02)
          ..close();
        canvas.drawPath(delHelmet, Paint()..color = const Color(0xFF4E342E));
        // Leopard spots on helmet
        for (var j = 0; j < 4; j++) {
          canvas.drawCircle(Offset(c.dx - s * 0.10 + j * s * 0.07, c.dy - s * 0.10), s * 0.02, Paint()..color = const Color(0xFF3E2723));
        }
        // Tall feather plumes
        canvas.drawLine(Offset(c.dx - s * 0.04, c.dy - s * 0.22), Offset(c.dx - s * 0.08, c.dy - s * 0.42), Paint()..color = const Color(0xFFD32F2F)..strokeWidth = s * 0.03..strokeCap = StrokeCap.round);
        canvas.drawLine(Offset(c.dx + s * 0.04, c.dy - s * 0.22), Offset(c.dx + s * 0.08, c.dy - s * 0.42), Paint()..color = const Color(0xFFD32F2F)..strokeWidth = s * 0.03..strokeCap = StrokeCap.round);
        canvas.drawLine(Offset(c.dx, c.dy - s * 0.24), Offset(c.dx, c.dy - s * 0.44), Paint()..color = const Color(0xFF1565C0)..strokeWidth = s * 0.03..strokeCap = StrokeCap.round);
        // Wild eyes
        _drawEyes(canvas, c, s, eye, yOff: 0.10, sz: 0.028);
        _drawAngryBrows(canvas, c, s);
        // Fierce mustache
        _drawMustache(canvas, c, s, const Color(0xFF1A1A1A));
        break;

      case 11: // ARAB DESERT WARRIOR — keffiyeh, dark eyes
        _drawFace(canvas, c, s, skinOlive, yOff: 0.10, w: 0.34, h: 0.30);
        // Keffiyeh wrap
        final keff = Paint()..color = const Color(0xFFE8E0D0);
        canvas.drawOval(Rect.fromCenter(center: Offset(c.dx, c.dy - s * 0.04), width: s * 0.54, height: s * 0.44), keff);
        // Face opening
        _drawFace(canvas, c, s, skinOlive, yOff: 0.10, w: 0.32, h: 0.26);
        // Agal (black ring)
        canvas.drawCircle(c + Offset(0, -s * 0.12), s * 0.18, Paint()..color = const Color(0xFF1A1A1A)..style = PaintingStyle.stroke..strokeWidth = s * 0.03);
        // Red pattern on keffiyeh
        for (var j = 0; j < 3; j++) {
          canvas.drawLine(Offset(c.dx - s * 0.20 + j * s * 0.08, c.dy - s * 0.20), Offset(c.dx - s * 0.18 + j * s * 0.08, c.dy - s * 0.10), Paint()..color = const Color(0xFFC62828)..strokeWidth = s * 0.008);
        }
        _drawEyes(canvas, c, s, eye, yOff: 0.10);
        // Lower face wrap
        final wrap = Path()
          ..moveTo(c.dx - s * 0.18, c.dy + s * 0.16)
          ..quadraticBezierTo(c.dx, c.dy + s * 0.24, c.dx + s * 0.18, c.dy + s * 0.16);
        canvas.drawPath(wrap, keff..style = PaintingStyle.fill);
        break;

      case 12: // MONGOL WARRIOR — fur-lined helmet, fierce gaze
        _drawFace(canvas, c, s, skinOlive, yOff: 0.10, w: 0.38, h: 0.32);
        // Fur-lined helmet
        final fur = Paint()..color = const Color(0xFF5D4037);
        final mHelmet = Path()
          ..moveTo(c.dx - s * 0.26, c.dy + s * 0.04)
          ..quadraticBezierTo(c.dx, c.dy - s * 0.30, c.dx + s * 0.26, c.dy + s * 0.04)
          ..close();
        canvas.drawPath(mHelmet, Paint()..color = const Color(0xFF424242));
        // Fur brim
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(c.dx, c.dy + s * 0.02), width: s * 0.56, height: s * 0.08), Radius.circular(s * 0.04)), fur);
        // Spike on top
        canvas.drawLine(Offset(c.dx, c.dy - s * 0.24), Offset(c.dx, c.dy - s * 0.36), Paint()..color = const Color(0xFFBDBDBD)..strokeWidth = s * 0.025..strokeCap = StrokeCap.round);
        _drawEyes(canvas, c, s, eye, yOff: 0.10, sz: 0.022);
        _drawAngryBrows(canvas, c, s);
        // Thin beard
        canvas.drawLine(Offset(c.dx - s * 0.02, c.dy + s * 0.22), Offset(c.dx - s * 0.02, c.dy + s * 0.30), Paint()..color = const Color(0xFF1A1A1A)..strokeWidth = s * 0.012);
        canvas.drawLine(Offset(c.dx + s * 0.02, c.dy + s * 0.22), Offset(c.dx + s * 0.02, c.dy + s * 0.30), Paint()..color = const Color(0xFF1A1A1A)..strokeWidth = s * 0.012);
        break;

      case 13: // ROMAN CENTURION — red crest helmet, stern face
        _drawFace(canvas, c, s, skinOlive, yOff: 0.10, w: 0.34, h: 0.30);
        // Helmet
        final rHelmet = Path()
          ..moveTo(c.dx - s * 0.26, c.dy + s * 0.06)
          ..quadraticBezierTo(c.dx - s * 0.28, c.dy - s * 0.10, c.dx, c.dy - s * 0.22)
          ..quadraticBezierTo(c.dx + s * 0.28, c.dy - s * 0.10, c.dx + s * 0.26, c.dy + s * 0.06)
          ..close();
        canvas.drawPath(rHelmet, gold);
        // Transverse crest (centurion style - side to side)
        for (var j = -3; j <= 3; j++) {
          canvas.drawCircle(Offset(c.dx + j * s * 0.05, c.dy - s * 0.22), s * 0.035, red);
        }
        // Cheek guards
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(c.dx - s * 0.28, c.dy + s * 0.04, s * 0.10, s * 0.18), Radius.circular(s * 0.02)), gold);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(c.dx + s * 0.18, c.dy + s * 0.04, s * 0.10, s * 0.18), Radius.circular(s * 0.02)), gold);
        _drawEyes(canvas, c, s, eye, yOff: 0.10);
        canvas.drawLine(Offset(c.dx - s * 0.06, c.dy + s * 0.22), Offset(c.dx + s * 0.06, c.dy + s * 0.22), line);
        break;

      case 14: // AZTEC EAGLE WARRIOR — eagle headdress
        _drawFace(canvas, c, s, skinBrown, yOff: 0.12, w: 0.34, h: 0.28);
        // Eagle beak above head
        final beak = Path()
          ..moveTo(c.dx - s * 0.12, c.dy - s * 0.06)
          ..lineTo(c.dx, c.dy - s * 0.02)
          ..lineTo(c.dx + s * 0.12, c.dy - s * 0.06)
          ..lineTo(c.dx, c.dy + s * 0.04)
          ..close();
        canvas.drawPath(beak, Paint()..color = const Color(0xFFFF8F00));
        // Eagle head dome
        final eagle = Path()
          ..moveTo(c.dx - s * 0.28, c.dy - s * 0.04)
          ..quadraticBezierTo(c.dx, c.dy - s * 0.36, c.dx + s * 0.28, c.dy - s * 0.04)
          ..close();
        canvas.drawPath(eagle, white);
        // Feathers radiating
        for (var j = 0; j < 7; j++) {
          final angle = -1.2 + j * 0.4;
          canvas.drawLine(Offset(c.dx + math.cos(angle) * s * 0.20, c.dy - s * 0.16 + math.sin(angle) * s * 0.10), Offset(c.dx + math.cos(angle) * s * 0.38, c.dy - s * 0.20 + math.sin(angle) * s * 0.14), Paint()..color = const Color(0xFF4E342E)..strokeWidth = s * 0.02..strokeCap = StrokeCap.round);
        }
        _drawEyes(canvas, c, s, eye, yOff: 0.12);
        // War paint stripes
        canvas.drawLine(Offset(c.dx - s * 0.10, c.dy + s * 0.14), Offset(c.dx - s * 0.16, c.dy + s * 0.20), red..strokeWidth = s * 0.015);
        canvas.drawLine(Offset(c.dx + s * 0.10, c.dy + s * 0.14), Offset(c.dx + s * 0.16, c.dy + s * 0.20), red);
        break;

      case 15: // ZULU WARRIOR — isiCoco headring, shield patterns
        _drawFace(canvas, c, s, skinDeep, yOff: 0.08, w: 0.40, h: 0.36);
        // IsiCoco headring
        canvas.drawCircle(Offset(c.dx, c.dy - s * 0.06), s * 0.22, Paint()..color = const Color(0xFF1A1A1A)..style = PaintingStyle.stroke..strokeWidth = s * 0.05);
        // Feathers on top
        canvas.drawLine(Offset(c.dx - s * 0.06, c.dy - s * 0.22), Offset(c.dx - s * 0.08, c.dy - s * 0.38), white..strokeWidth = s * 0.025..strokeCap = StrokeCap.round);
        canvas.drawLine(Offset(c.dx + s * 0.06, c.dy - s * 0.22), Offset(c.dx + s * 0.08, c.dy - s * 0.38), white..strokeWidth = s * 0.025..strokeCap = StrokeCap.round);
        _drawEyes(canvas, c, s, eye, yOff: 0.08);
        // Tribal markings
        canvas.drawLine(Offset(c.dx - s * 0.08, c.dy + s * 0.16), Offset(c.dx - s * 0.08, c.dy + s * 0.24), white..strokeWidth = s * 0.012);
        canvas.drawLine(Offset(c.dx + s * 0.08, c.dy + s * 0.16), Offset(c.dx + s * 0.08, c.dy + s * 0.24), white);
        canvas.drawLine(Offset(c.dx - s * 0.06, c.dy + s * 0.22), Offset(c.dx + s * 0.06, c.dy + s * 0.22), line);
        break;

      case 16: // MAORI WARRIOR — ta moko face tattoo, topknot
        _drawFace(canvas, c, s, skinBrown, yOff: 0.06, w: 0.44, h: 0.40);
        // Topknot
        canvas.drawOval(Rect.fromCenter(center: Offset(c.dx, c.dy - s * 0.24), width: s * 0.16, height: s * 0.14), eye);
        // Ta moko patterns
        final moko = Paint()..color = const Color(0xFF1A3A5A)..strokeWidth = s * 0.015..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
        // Chin curves
        canvas.drawArc(Rect.fromCenter(center: Offset(c.dx, c.dy + s * 0.18), width: s * 0.18, height: s * 0.10), 0, math.pi, false, moko);
        canvas.drawArc(Rect.fromCenter(center: Offset(c.dx, c.dy + s * 0.22), width: s * 0.14, height: s * 0.08), 0, math.pi, false, moko);
        // Forehead spirals
        canvas.drawArc(Rect.fromCenter(center: Offset(c.dx - s * 0.08, c.dy + s * 0.02), width: s * 0.10, height: s * 0.10), 0, math.pi * 1.5, false, moko);
        canvas.drawArc(Rect.fromCenter(center: Offset(c.dx + s * 0.08, c.dy + s * 0.02), width: s * 0.10, height: s * 0.10), math.pi, math.pi * 1.5, false, moko);
        _drawEyes(canvas, c, s, eye, yOff: 0.06, sz: 0.026);
        // Open mouth (haka)
        canvas.drawOval(Rect.fromCenter(center: Offset(c.dx, c.dy + s * 0.22), width: s * 0.12, height: s * 0.08), Paint()..color = const Color(0xFF8B0000));
        break;

      case 17: // PERSIAN IMMORTAL — gold mask, ornate helmet
        // Gold face mask
        _drawFace(canvas, c, s, gold, yOff: 0.08, w: 0.40, h: 0.36);
        // Helmet dome
        final pHelmet = Path()
          ..moveTo(c.dx - s * 0.24, c.dy - s * 0.02)
          ..quadraticBezierTo(c.dx, c.dy - s * 0.30, c.dx + s * 0.24, c.dy - s * 0.02)
          ..close();
        canvas.drawPath(pHelmet, Paint()..color = const Color(0xFF7B1FA2));
        // Gold trim
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(c.dx, c.dy - s * 0.02), width: s * 0.50, height: s * 0.05), Radius.circular(s * 0.02)), gold);
        // Crown point
        canvas.drawLine(Offset(c.dx, c.dy - s * 0.26), Offset(c.dx, c.dy - s * 0.38), gold..strokeWidth = s * 0.03..strokeCap = StrokeCap.round);
        // Dark empty eyes on mask
        canvas.drawOval(Rect.fromCenter(center: Offset(c.dx - s * 0.09, c.dy + s * 0.06), width: s * 0.08, height: s * 0.06), eye);
        canvas.drawOval(Rect.fromCenter(center: Offset(c.dx + s * 0.09, c.dy + s * 0.06), width: s * 0.08, height: s * 0.06), eye);
        // Beard detail on mask
        for (var j = 0; j < 5; j++) {
          canvas.drawLine(Offset(c.dx - s * 0.08 + j * s * 0.04, c.dy + s * 0.18), Offset(c.dx - s * 0.08 + j * s * 0.04, c.dy + s * 0.28), Paint()..color = const Color(0xFFB8860B)..strokeWidth = s * 0.01);
        }
        break;

      case 18: // CHINESE IMPERIAL GUARD — ornate helmet, stern
        _drawFace(canvas, c, s, skinOlive, yOff: 0.10, w: 0.36, h: 0.30);
        // Helmet with upturned wings
        final cHelmet = Path()
          ..moveTo(c.dx - s * 0.26, c.dy + s * 0.02)
          ..quadraticBezierTo(c.dx, c.dy - s * 0.26, c.dx + s * 0.26, c.dy + s * 0.02)
          ..close();
        canvas.drawPath(cHelmet, Paint()..color = const Color(0xFFD32F2F));
        // Gold ornament
        canvas.drawCircle(Offset(c.dx, c.dy - s * 0.12), s * 0.04, gold);
        // Wing ornaments
        canvas.drawLine(Offset(c.dx - s * 0.22, c.dy - s * 0.02), Offset(c.dx - s * 0.34, c.dy - s * 0.14), gold..strokeWidth = s * 0.025..strokeCap = StrokeCap.round);
        canvas.drawLine(Offset(c.dx + s * 0.22, c.dy - s * 0.02), Offset(c.dx + s * 0.34, c.dy - s * 0.14), gold);
        // Chin guard
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(c.dx, c.dy + s * 0.24), width: s * 0.20, height: s * 0.06), Radius.circular(s * 0.02)), Paint()..color = const Color(0xFFD32F2F));
        _drawEyes(canvas, c, s, eye, yOff: 0.10);
        // Thin mustache
        canvas.drawLine(Offset(c.dx - s * 0.02, c.dy + s * 0.18), Offset(c.dx - s * 0.12, c.dy + s * 0.20), Paint()..color = const Color(0xFF1A1A1A)..strokeWidth = s * 0.012..strokeCap = StrokeCap.round);
        canvas.drawLine(Offset(c.dx + s * 0.02, c.dy + s * 0.18), Offset(c.dx + s * 0.12, c.dy + s * 0.20), Paint()..color = const Color(0xFF1A1A1A)..strokeWidth = s * 0.012..strokeCap = StrokeCap.round);
        break;

      case 19: // SCOTTISH HIGHLANDER — beret, red beard
        _drawFace(canvas, c, s, skin, yOff: 0.10, w: 0.40, h: 0.34);
        // Tam o' Shanter beret
        canvas.drawOval(Rect.fromCenter(center: Offset(c.dx, c.dy - s * 0.10), width: s * 0.48, height: s * 0.22), Paint()..color = const Color(0xFF1565C0));
        // Pom-pom
        canvas.drawCircle(Offset(c.dx, c.dy - s * 0.22), s * 0.04, Paint()..color = const Color(0xFFFF5722));
        _drawEyes(canvas, c, s, eye, yOff: 0.10);
        // Bushy red beard
        final rBeard = Path()
          ..moveTo(c.dx - s * 0.20, c.dy + s * 0.14)
          ..quadraticBezierTo(c.dx - s * 0.22, c.dy + s * 0.30, c.dx, c.dy + s * 0.34)
          ..quadraticBezierTo(c.dx + s * 0.22, c.dy + s * 0.30, c.dx + s * 0.20, c.dy + s * 0.14)
          ..close();
        canvas.drawPath(rBeard, Paint()..color = const Color(0xFFBF360C));
        break;

      case 20: // RAJPUT WARRIOR — turban, regal bearing
        _drawFace(canvas, c, s, skinBrown, yOff: 0.10, w: 0.36, h: 0.32);
        // Turban wraps
        final turban = Paint()..color = const Color(0xFFFF6F00);
        final tPath = Path()
          ..moveTo(c.dx - s * 0.24, c.dy + s * 0.02)
          ..quadraticBezierTo(c.dx - s * 0.26, c.dy - s * 0.14, c.dx, c.dy - s * 0.24)
          ..quadraticBezierTo(c.dx + s * 0.26, c.dy - s * 0.14, c.dx + s * 0.24, c.dy + s * 0.02)
          ..close();
        canvas.drawPath(tPath, turban);
        // Turban folds
        canvas.drawArc(Rect.fromCenter(center: Offset(c.dx, c.dy - s * 0.10), width: s * 0.36, height: s * 0.16), 0, math.pi, false, Paint()..color = const Color(0xFFE65100)..style = PaintingStyle.stroke..strokeWidth = s * 0.015);
        // Jewel center
        canvas.drawCircle(Offset(c.dx, c.dy - s * 0.08), s * 0.035, Paint()..color = const Color(0xFFD32F2F));
        canvas.drawCircle(Offset(c.dx, c.dy - s * 0.08), s * 0.02, gold);
        // Feather
        canvas.drawLine(Offset(c.dx + s * 0.04, c.dy - s * 0.20), Offset(c.dx + s * 0.10, c.dy - s * 0.38), white..strokeWidth = s * 0.02..strokeCap = StrokeCap.round);
        _drawEyes(canvas, c, s, eye, yOff: 0.10);
        _drawMustache(canvas, c, s, const Color(0xFF1A1A1A));
        break;

      case 21: // COSSACK — papakha hat, fierce mustache
        _drawFace(canvas, c, s, skin, yOff: 0.10, w: 0.38, h: 0.32);
        // Papakha (tall fur hat)
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(c.dx, c.dy - s * 0.14), width: s * 0.40, height: s * 0.28), Radius.circular(s * 0.06)), Paint()..color = const Color(0xFF4E342E));
        // Fur texture
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(c.dx, c.dy - s * 0.14), width: s * 0.42, height: s * 0.30), Radius.circular(s * 0.06)), Paint()..color = const Color(0xFF5D4037)..style = PaintingStyle.stroke..strokeWidth = s * 0.02);
        _drawEyes(canvas, c, s, eye, yOff: 0.10);
        // Long droopy mustache
        final cMust = Paint()..color = const Color(0xFF4E342E)..strokeWidth = s * 0.025..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(c.dx, c.dy + s * 0.18), Offset(c.dx - s * 0.16, c.dy + s * 0.24), cMust);
        canvas.drawLine(Offset(c.dx, c.dy + s * 0.18), Offset(c.dx + s * 0.16, c.dy + s * 0.24), cMust);
        break;

      case 22: // TEMPLAR KNIGHT — white helm with red cross
        // White helmet
        canvas.drawOval(Rect.fromCenter(center: Offset(c.dx, c.dy + s * 0.02), width: s * 0.52, height: s * 0.56), white);
        // Red cross
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(c.dx, c.dy + s * 0.02), width: s * 0.08, height: s * 0.36), Radius.circular(s * 0.01)), red);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(c.dx, c.dy - s * 0.04), width: s * 0.28, height: s * 0.08), Radius.circular(s * 0.01)), red);
        // Visor slit
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(c.dx, c.dy + s * 0.06), width: s * 0.32, height: s * 0.05), Radius.circular(s * 0.02)), Paint()..color = const Color(0xFF333333));
        // Eyes through slit
        canvas.drawCircle(Offset(c.dx - s * 0.06, c.dy + s * 0.06), s * 0.015, Paint()..color = const Color(0xFF4488FF));
        canvas.drawCircle(Offset(c.dx + s * 0.06, c.dy + s * 0.06), s * 0.015, Paint()..color = const Color(0xFF4488FF));
        break;

      case 23: // GLADIATOR — open-face helmet, scarred
        _drawFace(canvas, c, s, skinOlive, yOff: 0.08, w: 0.42, h: 0.38);
        // Helmet frame
        final gHelmet = Paint()..color = const Color(0xFFCD7F32);
        canvas.drawArc(Rect.fromCenter(center: Offset(c.dx, c.dy - s * 0.04), width: s * 0.52, height: s * 0.46), math.pi, math.pi, false, gHelmet..strokeWidth = s * 0.04..style = PaintingStyle.stroke);
        // Crest
        for (var j = 0; j < 5; j++) {
          canvas.drawCircle(Offset(c.dx, c.dy - s * 0.24 + j * s * 0.02), s * 0.03, red);
        }
        // Cheek guard
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(c.dx - s * 0.28, c.dy + s * 0.02, s * 0.08, s * 0.16), Radius.circular(s * 0.02)), gHelmet..style = PaintingStyle.fill);
        _drawEyes(canvas, c, s, eye, yOff: 0.08);
        _drawAngryBrows(canvas, c, s, yOff: 0.02);
        // Scar
        canvas.drawLine(Offset(c.dx + s * 0.06, c.dy + s * 0.04), Offset(c.dx + s * 0.14, c.dy + s * 0.18), Paint()..color = const Color(0xFFD32F2F)..strokeWidth = s * 0.012);
        canvas.drawLine(Offset(c.dx - s * 0.06, c.dy + s * 0.22), Offset(c.dx + s * 0.06, c.dy + s * 0.22), line);
        break;

      case 24: // BERSERKER — bear pelt hood, wild eyes
        // Bear hood
        final bearFur = Paint()..color = const Color(0xFF3E2723);
        final bHood = Path()
          ..moveTo(c.dx - s * 0.32, c.dy + s * 0.24)
          ..quadraticBezierTo(c.dx - s * 0.34, c.dy - s * 0.10, c.dx, c.dy - s * 0.28)
          ..quadraticBezierTo(c.dx + s * 0.34, c.dy - s * 0.10, c.dx + s * 0.32, c.dy + s * 0.24)
          ..close();
        canvas.drawPath(bHood, bearFur);
        // Bear ears
        canvas.drawCircle(Offset(c.dx - s * 0.20, c.dy - s * 0.22), s * 0.06, bearFur);
        canvas.drawCircle(Offset(c.dx + s * 0.20, c.dy - s * 0.22), s * 0.06, bearFur);
        // Face
        _drawFace(canvas, c, s, skin, yOff: 0.08, w: 0.36, h: 0.32);
        // Wild eyes (red-rimmed)
        canvas.drawCircle(Offset(c.dx - s * 0.08, c.dy + s * 0.06), s * 0.03, Paint()..color = const Color(0xFFFF5252));
        canvas.drawCircle(Offset(c.dx + s * 0.08, c.dy + s * 0.06), s * 0.03, Paint()..color = const Color(0xFFFF5252));
        canvas.drawCircle(Offset(c.dx - s * 0.08, c.dy + s * 0.06), s * 0.018, eye);
        canvas.drawCircle(Offset(c.dx + s * 0.08, c.dy + s * 0.06), s * 0.018, eye);
        // War paint
        canvas.drawLine(Offset(c.dx - s * 0.16, c.dy + s * 0.10), Offset(c.dx - s * 0.04, c.dy + s * 0.14), Paint()..color = const Color(0xFF1565C0)..strokeWidth = s * 0.018);
        canvas.drawLine(Offset(c.dx + s * 0.04, c.dy + s * 0.14), Offset(c.dx + s * 0.16, c.dy + s * 0.10), Paint()..color = const Color(0xFF1565C0)..strokeWidth = s * 0.018);
        // Open mouth scream
        canvas.drawOval(Rect.fromCenter(center: Offset(c.dx, c.dy + s * 0.22), width: s * 0.12, height: s * 0.08), Paint()..color = const Color(0xFF8B0000));
        break;

      case 25: // SHOGUN — elaborate kabuto, authority
        _drawFace(canvas, c, s, skinOlive, yOff: 0.12, w: 0.34, h: 0.28);
        // Grand kabuto
        final sHelmet = Path()
          ..moveTo(c.dx - s * 0.30, c.dy + s * 0.04)
          ..quadraticBezierTo(c.dx - s * 0.32, c.dy - s * 0.14, c.dx, c.dy - s * 0.26)
          ..quadraticBezierTo(c.dx + s * 0.32, c.dy - s * 0.14, c.dx + s * 0.30, c.dy + s * 0.04)
          ..close();
        canvas.drawPath(sHelmet, Paint()..color = const Color(0xFF1A1A1A));
        // Grand maedate (wide crescent)
        final crescent = Path()
          ..moveTo(c.dx - s * 0.34, c.dy - s * 0.18)
          ..quadraticBezierTo(c.dx, c.dy - s * 0.42, c.dx + s * 0.34, c.dy - s * 0.18);
        canvas.drawPath(crescent, Paint()..color = const Color(0xFFDAA520)..style = PaintingStyle.stroke..strokeWidth = s * 0.03..strokeCap = StrokeCap.round);
        // Gold brim
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(c.dx, c.dy + s * 0.04), width: s * 0.62, height: s * 0.05), Radius.circular(s * 0.02)), gold);
        _drawEyes(canvas, c, s, eye, yOff: 0.12);
        // Menpo
        final sMenpo = Path()..moveTo(c.dx - s * 0.14, c.dy + s * 0.18)..quadraticBezierTo(c.dx, c.dy + s * 0.28, c.dx + s * 0.14, c.dy + s * 0.18);
        canvas.drawPath(sMenpo, Paint()..color = const Color(0xFF8B0000));
        break;

      // ═══════════════════════════════════════════════════════════════════
      // FEMALE AVATARS 26-50
      // ═══════════════════════════════════════════════════════════════════

      case 26: // VALKYRIE — winged helmet, golden hair
        _drawFace(canvas, c, s, skin, yOff: 0.10, w: 0.36, h: 0.32);
        // Flowing golden hair
        _drawHair(canvas, c, s, const Color(0xFFDAA520), spread: 0.22);
        // Silver helmet
        final vHelmet = Path()
          ..moveTo(c.dx - s * 0.20, c.dy + s * 0.02)
          ..quadraticBezierTo(c.dx, c.dy - s * 0.22, c.dx + s * 0.20, c.dy + s * 0.02)
          ..close();
        canvas.drawPath(vHelmet, Paint()..color = const Color(0xFFBDBDBD));
        // Wings on helmet
        canvas.drawLine(Offset(c.dx - s * 0.18, c.dy - s * 0.06), Offset(c.dx - s * 0.34, c.dy - s * 0.22), white..strokeWidth = s * 0.02..strokeCap = StrokeCap.round);
        canvas.drawLine(Offset(c.dx - s * 0.18, c.dy - s * 0.04), Offset(c.dx - s * 0.32, c.dy - s * 0.16), white);
        canvas.drawLine(Offset(c.dx + s * 0.18, c.dy - s * 0.06), Offset(c.dx + s * 0.34, c.dy - s * 0.22), white);
        canvas.drawLine(Offset(c.dx + s * 0.18, c.dy - s * 0.04), Offset(c.dx + s * 0.32, c.dy - s * 0.16), white);
        // Blue eyes
        _drawFemaleEyes(canvas, c, s, const Color(0xFF42A5F5));
        _drawSmile(canvas, c, s);
        break;

      case 27: // CLEOPATRA — Egyptian nemes, kohl eyes
        _drawFace(canvas, c, s, skinOlive, yOff: 0.10, w: 0.36, h: 0.32);
        final blue = Paint()..color = const Color(0xFF1565C0);
        // Nemes sides
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(c.dx - s * 0.34, c.dy - s * 0.06, s * 0.14, s * 0.38), Radius.circular(s * 0.04)), blue);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(c.dx + s * 0.20, c.dy - s * 0.06, s * 0.14, s * 0.38), Radius.circular(s * 0.04)), blue);
        for (var j = 0; j < 3; j++) {
          canvas.drawLine(Offset(c.dx - s * 0.34, c.dy + j * s * 0.08), Offset(c.dx - s * 0.20, c.dy + j * s * 0.08), gold..strokeWidth = s * 0.015);
          canvas.drawLine(Offset(c.dx + s * 0.20, c.dy + j * s * 0.08), Offset(c.dx + s * 0.34, c.dy + j * s * 0.08), gold);
        }
        // Crown dome
        final cCrown = Path()..moveTo(c.dx - s * 0.22, c.dy - s * 0.04)..quadraticBezierTo(c.dx, c.dy - s * 0.26, c.dx + s * 0.22, c.dy - s * 0.04)..close();
        canvas.drawPath(cCrown, blue);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(c.dx, c.dy - s * 0.04), width: s * 0.46, height: s * 0.05), Radius.circular(s * 0.02)), gold);
        // Cobra
        canvas.drawCircle(Offset(c.dx, c.dy - s * 0.14), s * 0.03, gold);
        _drawFemaleEyes(canvas, c, s, const Color(0xFF1A1A1A));
        // Kohl wings
        canvas.drawLine(Offset(c.dx - s * 0.12, c.dy + s * 0.08), Offset(c.dx - s * 0.18, c.dy + s * 0.06), eye..strokeWidth = s * 0.015);
        canvas.drawLine(Offset(c.dx + s * 0.12, c.dy + s * 0.08), Offset(c.dx + s * 0.18, c.dy + s * 0.06), eye);
        // Red lips
        _drawLips(canvas, c, s, const Color(0xFFD32F2F));
        break;

      case 28: // WITCH — pointed hat, purple theme
        _drawFace(canvas, c, s, skin, yOff: 0.12, w: 0.36, h: 0.30);
        // Flowing dark hair
        _drawHair(canvas, c, s, const Color(0xFF1A1A1A), spread: 0.20);
        // Pointed hat
        final hatP = Path()
          ..moveTo(c.dx - s * 0.22, c.dy + s * 0.02)
          ..lineTo(c.dx + s * 0.08, c.dy - s * 0.42)
          ..lineTo(c.dx + s * 0.22, c.dy + s * 0.02)
          ..close();
        canvas.drawPath(hatP, Paint()..color = const Color(0xFF4A148C));
        // Hat band
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(c.dx, c.dy + s * 0.01), width: s * 0.44, height: s * 0.05), Radius.circular(s * 0.02)), gold);
        // Purple eyes
        _drawFemaleEyes(canvas, c, s, const Color(0xFF9C27B0));
        // Smirk
        final smirk = Path()..moveTo(c.dx - s * 0.04, c.dy + s * 0.20)..quadraticBezierTo(c.dx + s * 0.04, c.dy + s * 0.24, c.dx + s * 0.08, c.dy + s * 0.18);
        canvas.drawPath(smirk, line);
        break;

      case 29: // AMAZON WARRIOR — leather headband, strong
        _drawFace(canvas, c, s, skinOlive, yOff: 0.08, w: 0.40, h: 0.36);
        // Wild curly hair
        for (var j = 0; j < 8; j++) {
          final angle = -1.0 + j * 0.3;
          canvas.drawCircle(Offset(c.dx + math.cos(angle) * s * 0.22, c.dy - s * 0.06 + math.sin(angle) * s * 0.16), s * 0.06, Paint()..color = const Color(0xFF4E342E));
        }
        // Leather headband
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(c.dx, c.dy - s * 0.02), width: s * 0.48, height: s * 0.05), Radius.circular(s * 0.02)), Paint()..color = const Color(0xFF795548));
        _drawFemaleEyes(canvas, c, s, const Color(0xFF4E342E));
        _drawAngryBrows(canvas, c, s, yOff: 0.02);
        canvas.drawLine(Offset(c.dx - s * 0.06, c.dy + s * 0.20), Offset(c.dx + s * 0.06, c.dy + s * 0.20), line);
        break;

      case 30: // GEISHA — elaborate updo, white face
        // White face
        _drawFace(canvas, c, s, Paint()..color = const Color(0xFFFFF8F0), yOff: 0.10, w: 0.36, h: 0.32);
        // Elaborate black hair updo
        canvas.drawOval(Rect.fromCenter(center: Offset(c.dx, c.dy - s * 0.12), width: s * 0.46, height: s * 0.28), eye);
        // Hair ornaments (kanzashi)
        canvas.drawCircle(Offset(c.dx - s * 0.14, c.dy - s * 0.18), s * 0.03, red);
        canvas.drawCircle(Offset(c.dx + s * 0.10, c.dy - s * 0.20), s * 0.025, Paint()..color = const Color(0xFFE91E63));
        // Hair sticks
        canvas.drawLine(Offset(c.dx - s * 0.14, c.dy - s * 0.18), Offset(c.dx - s * 0.24, c.dy - s * 0.08), gold..strokeWidth = s * 0.012..strokeCap = StrokeCap.round);
        canvas.drawLine(Offset(c.dx + s * 0.10, c.dy - s * 0.20), Offset(c.dx + s * 0.20, c.dy - s * 0.10), gold);
        // Delicate eyes
        _drawFemaleEyes(canvas, c, s, const Color(0xFF1A1A1A), sz: 0.018);
        // Red lips (small)
        canvas.drawOval(Rect.fromCenter(center: Offset(c.dx, c.dy + s * 0.20), width: s * 0.06, height: s * 0.04), red);
        break;

      case 31: // CELTIC QUEEN — torque necklace, red hair, crown
        _drawFace(canvas, c, s, skin, yOff: 0.08, w: 0.38, h: 0.34);
        // Red flowing hair
        _drawHair(canvas, c, s, const Color(0xFFBF360C), spread: 0.24);
        // Simple crown
        final crownQ = Paint()..color = const Color(0xFFDAA520);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(c.dx, c.dy - s * 0.08), width: s * 0.38, height: s * 0.06), Radius.circular(s * 0.01)), crownQ);
        // Crown points
        for (var j = -2; j <= 2; j++) {
          final pPath = Path()
            ..moveTo(c.dx + j * s * 0.08 - s * 0.03, c.dy - s * 0.11)
            ..lineTo(c.dx + j * s * 0.08, c.dy - s * 0.19)
            ..lineTo(c.dx + j * s * 0.08 + s * 0.03, c.dy - s * 0.11)
            ..close();
          canvas.drawPath(pPath, crownQ);
        }
        _drawFemaleEyes(canvas, c, s, const Color(0xFF2E7D32));
        _drawSmile(canvas, c, s);
        // Torque necklace hint
        canvas.drawArc(Rect.fromCenter(center: Offset(c.dx, c.dy + s * 0.26), width: s * 0.28, height: s * 0.12), 0, math.pi, false, gold..strokeWidth = s * 0.02..style = PaintingStyle.stroke);
        break;

      case 32: // NEFERTITI — tall crown, elegant
        _drawFace(canvas, c, s, skinBrown, yOff: 0.12, w: 0.34, h: 0.28);
        // Tall blue crown
        final nCrown = Path()
          ..moveTo(c.dx - s * 0.16, c.dy + s * 0.02)
          ..lineTo(c.dx - s * 0.14, c.dy - s * 0.36)
          ..quadraticBezierTo(c.dx, c.dy - s * 0.40, c.dx + s * 0.14, c.dy - s * 0.36)
          ..lineTo(c.dx + s * 0.16, c.dy + s * 0.02)
          ..close();
        canvas.drawPath(nCrown, Paint()..color = const Color(0xFF1565C0));
        // Gold band
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(c.dx, c.dy + s * 0.01), width: s * 0.34, height: s * 0.04), Radius.circular(s * 0.02)), gold);
        // Cobra on crown
        canvas.drawCircle(Offset(c.dx, c.dy - s * 0.06), s * 0.025, gold);
        _drawFemaleEyes(canvas, c, s, const Color(0xFF1A1A1A));
        // Kohl lines
        canvas.drawLine(Offset(c.dx - s * 0.12, c.dy + s * 0.10), Offset(c.dx - s * 0.18, c.dy + s * 0.08), eye..strokeWidth = s * 0.012);
        canvas.drawLine(Offset(c.dx + s * 0.12, c.dy + s * 0.10), Offset(c.dx + s * 0.18, c.dy + s * 0.08), eye);
        _drawLips(canvas, c, s, const Color(0xFFD32F2F));
        break;

      case 33: // CHINESE WARRIOR WOMAN — armor, bun hairstyle
        _drawFace(canvas, c, s, skinOlive, yOff: 0.10, w: 0.36, h: 0.30);
        // Hair bun on top
        canvas.drawCircle(Offset(c.dx, c.dy - s * 0.20), s * 0.08, eye);
        // Hair stick through bun
        canvas.drawLine(Offset(c.dx - s * 0.12, c.dy - s * 0.22), Offset(c.dx + s * 0.12, c.dy - s * 0.18), gold..strokeWidth = s * 0.015..strokeCap = StrokeCap.round);
        // Side hair
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(c.dx - s * 0.24, c.dy, s * 0.08, s * 0.20), Radius.circular(s * 0.03)), eye);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(c.dx + s * 0.16, c.dy, s * 0.08, s * 0.20), Radius.circular(s * 0.03)), eye);
        // Headband
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(c.dx, c.dy - s * 0.04), width: s * 0.42, height: s * 0.04), Radius.circular(s * 0.02)), red);
        _drawFemaleEyes(canvas, c, s, const Color(0xFF4E342E));
        _drawSmile(canvas, c, s);
        break;

      case 34: // INDIAN RANI — ornate jewelry, bindi
        _drawFace(canvas, c, s, skinBrown, yOff: 0.08, w: 0.38, h: 0.34);
        // Dark hair parted
        _drawHair(canvas, c, s, const Color(0xFF1A1A1A), spread: 0.20);
        // Maang tikka (head jewelry)
        canvas.drawLine(Offset(c.dx, c.dy - s * 0.16), Offset(c.dx, c.dy - s * 0.02), gold..strokeWidth = s * 0.012..strokeCap = StrokeCap.round);
        // Bindi
        canvas.drawCircle(Offset(c.dx, c.dy + s * 0.01), s * 0.025, red);
        // Nose ring
        canvas.drawCircle(Offset(c.dx + s * 0.04, c.dy + s * 0.14), s * 0.015, gold);
        // Earrings
        canvas.drawCircle(Offset(c.dx - s * 0.20, c.dy + s * 0.12), s * 0.025, gold);
        canvas.drawCircle(Offset(c.dx + s * 0.20, c.dy + s * 0.12), s * 0.025, gold);
        _drawFemaleEyes(canvas, c, s, const Color(0xFF4E342E));
        _drawLips(canvas, c, s, const Color(0xFFD32F2F));
        break;

      case 35: // PERSIAN WARRIOR WOMAN — ornate headpiece
        _drawFace(canvas, c, s, skinOlive, yOff: 0.10, w: 0.36, h: 0.30);
        // Dark wavy hair
        _drawHair(canvas, c, s, const Color(0xFF1A1A1A), spread: 0.22);
        // Gold headpiece / tiara
        final tiara = Path()
          ..moveTo(c.dx - s * 0.20, c.dy - s * 0.02)
          ..quadraticBezierTo(c.dx, c.dy - s * 0.16, c.dx + s * 0.20, c.dy - s * 0.02);
        canvas.drawPath(tiara, gold..strokeWidth = s * 0.03..style = PaintingStyle.stroke);
        // Center gem
        canvas.drawCircle(Offset(c.dx, c.dy - s * 0.08), s * 0.03, Paint()..color = const Color(0xFF7B1FA2));
        // Gold chains
        canvas.drawLine(Offset(c.dx - s * 0.20, c.dy - s * 0.02), Offset(c.dx - s * 0.22, c.dy + s * 0.10), gold..strokeWidth = s * 0.008);
        canvas.drawLine(Offset(c.dx + s * 0.20, c.dy - s * 0.02), Offset(c.dx + s * 0.22, c.dy + s * 0.10), gold);
        _drawFemaleEyes(canvas, c, s, const Color(0xFF4E342E));
        _drawLips(canvas, c, s, const Color(0xFFC62828));
        break;

      case 36: // SHIELDMAIDEN — braided hair, determined
        _drawFace(canvas, c, s, skin, yOff: 0.08, w: 0.38, h: 0.34);
        // Blonde braids
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(c.dx - s * 0.28, c.dy - s * 0.04, s * 0.10, s * 0.36), Radius.circular(s * 0.04)), Paint()..color = const Color(0xFFDAA520));
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(c.dx + s * 0.18, c.dy - s * 0.04, s * 0.10, s * 0.36), Radius.circular(s * 0.04)), Paint()..color = const Color(0xFFDAA520));
        // Braid ties
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(c.dx - s * 0.23, c.dy + s * 0.26), width: s * 0.08, height: s * 0.04), Radius.circular(s * 0.02)), Paint()..color = const Color(0xFF795548));
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(c.dx + s * 0.23, c.dy + s * 0.26), width: s * 0.08, height: s * 0.04), Radius.circular(s * 0.02)), Paint()..color = const Color(0xFF795548));
        // Simple headband
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(c.dx, c.dy - s * 0.04), width: s * 0.44, height: s * 0.04), Radius.circular(s * 0.02)), Paint()..color = const Color(0xFF78909C));
        _drawFemaleEyes(canvas, c, s, const Color(0xFF42A5F5));
        _drawAngryBrows(canvas, c, s, yOff: 0.02);
        canvas.drawLine(Offset(c.dx - s * 0.05, c.dy + s * 0.20), Offset(c.dx + s * 0.05, c.dy + s * 0.20), line);
        break;

      case 37: // MAYAN PRIESTESS — jade jewelry, feathered
        _drawFace(canvas, c, s, skinBrown, yOff: 0.10, w: 0.36, h: 0.30);
        // Elaborate feathered headdress (green quetzal)
        final jade = Paint()..color = const Color(0xFF2E7D32);
        for (var j = 0; j < 5; j++) {
          final angle = -0.6 + j * 0.3;
          canvas.drawLine(Offset(c.dx + math.sin(angle) * s * 0.06, c.dy - s * 0.10), Offset(c.dx + math.sin(angle) * s * 0.20, c.dy - s * 0.38), Paint()..color = const Color(0xFF1B5E20)..strokeWidth = s * 0.025..strokeCap = StrokeCap.round);
        }
        // Gold headband
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(c.dx, c.dy - s * 0.02), width: s * 0.42, height: s * 0.05), Radius.circular(s * 0.02)), gold);
        // Jade earrings
        canvas.drawCircle(Offset(c.dx - s * 0.20, c.dy + s * 0.12), s * 0.025, jade);
        canvas.drawCircle(Offset(c.dx + s * 0.20, c.dy + s * 0.12), s * 0.025, jade);
        _drawFemaleEyes(canvas, c, s, const Color(0xFF4E342E));
        _drawLips(canvas, c, s, const Color(0xFFC62828));
        break;

      case 38: // PIRATE QUEEN — tricorn hat, bold
        _drawFace(canvas, c, s, skinOlive, yOff: 0.10, w: 0.38, h: 0.32);
        // Dark wavy hair
        _drawHair(canvas, c, s, const Color(0xFF1A1A1A), spread: 0.20);
        // Tricorn hat
        final tricorn = Path()
          ..moveTo(c.dx - s * 0.30, c.dy - s * 0.04)
          ..lineTo(c.dx - s * 0.10, c.dy - s * 0.26)
          ..lineTo(c.dx + s * 0.10, c.dy - s * 0.26)
          ..lineTo(c.dx + s * 0.30, c.dy - s * 0.04)
          ..quadraticBezierTo(c.dx, c.dy - s * 0.10, c.dx - s * 0.30, c.dy - s * 0.04)
          ..close();
        canvas.drawPath(tricorn, Paint()..color = const Color(0xFF37474F));
        // Skull emblem
        canvas.drawCircle(Offset(c.dx, c.dy - s * 0.16), s * 0.03, white);
        // Gold trim
        canvas.drawLine(Offset(c.dx - s * 0.28, c.dy - s * 0.04), Offset(c.dx + s * 0.28, c.dy - s * 0.04), gold..strokeWidth = s * 0.015);
        _drawFemaleEyes(canvas, c, s, const Color(0xFF4E342E));
        // Smirk
        final pSmirk = Path()..moveTo(c.dx - s * 0.06, c.dy + s * 0.20)..quadraticBezierTo(c.dx, c.dy + s * 0.24, c.dx + s * 0.08, c.dy + s * 0.18);
        canvas.drawPath(pSmirk, line);
        break;

      case 39: // KUNOICHI — female ninja, mask with flower
        // Black wrap
        canvas.drawOval(Rect.fromCenter(center: Offset(c.dx, c.dy + s * 0.06), width: s * 0.50, height: s * 0.50), Paint()..color = const Color(0xFF1A1A2E));
        // Skin band
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(c.dx, c.dy + s * 0.06), width: s * 0.44, height: s * 0.14), Radius.circular(s * 0.06)), skin);
        // Feminine eyes (larger, with lashes)
        _drawFemaleEyes(canvas, c, s, const Color(0xFF4E342E), yOff: 0.06);
        // Cherry blossom on head
        canvas.drawCircle(Offset(c.dx + s * 0.14, c.dy - s * 0.08), s * 0.035, Paint()..color = const Color(0xFFE91E63));
        canvas.drawCircle(Offset(c.dx + s * 0.14, c.dy - s * 0.08), s * 0.015, Paint()..color = const Color(0xFFFF80AB));
        // Headband tail (purple)
        canvas.drawLine(Offset(c.dx + s * 0.22, c.dy - s * 0.02), Offset(c.dx + s * 0.36, c.dy - s * 0.10), Paint()..color = const Color(0xFF4A148C)..strokeWidth = s * 0.022..strokeCap = StrokeCap.round);
        break;

      case 40: // OTTOMAN SULTANA — ornate veil, jewels
        _drawFace(canvas, c, s, skinOlive, yOff: 0.10, w: 0.36, h: 0.30);
        // Ornate veil/headpiece
        final veil = Paint()..color = const Color(0xFF880E4F);
        final vPath = Path()
          ..moveTo(c.dx - s * 0.26, c.dy + s * 0.02)
          ..quadraticBezierTo(c.dx, c.dy - s * 0.26, c.dx + s * 0.26, c.dy + s * 0.02)
          ..close();
        canvas.drawPath(vPath, veil);
        // Gold filigree lines
        for (var j = 0; j < 3; j++) {
          canvas.drawArc(Rect.fromCenter(center: Offset(c.dx, c.dy - s * 0.08), width: s * 0.30 + j * s * 0.08, height: s * 0.14 + j * s * 0.04), math.pi, math.pi, false, gold..strokeWidth = s * 0.008..style = PaintingStyle.stroke);
        }
        // Teardrop jewel
        canvas.drawCircle(Offset(c.dx, c.dy - s * 0.04), s * 0.03, Paint()..color = const Color(0xFF1565C0));
        // Dangling jewels
        canvas.drawCircle(Offset(c.dx - s * 0.18, c.dy + s * 0.08), s * 0.02, gold);
        canvas.drawCircle(Offset(c.dx + s * 0.18, c.dy + s * 0.08), s * 0.02, gold);
        _drawFemaleEyes(canvas, c, s, const Color(0xFF4E342E));
        _drawLips(canvas, c, s, const Color(0xFFC62828));
        break;

      case 41: // AFRICAN QUEEN — beaded crown, regal
        _drawFace(canvas, c, s, skinDeep, yOff: 0.08, w: 0.38, h: 0.34);
        // Tall beaded crown
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(c.dx, c.dy - s * 0.14), width: s * 0.36, height: s * 0.24), Radius.circular(s * 0.04)), gold);
        // Bead rows
        final beadColors = [const Color(0xFFD32F2F), const Color(0xFF1565C0), const Color(0xFF2E7D32), const Color(0xFFFF8F00)];
        for (var j = 0; j < 4; j++) {
          canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(c.dx, c.dy - s * 0.20 + j * s * 0.05), width: s * 0.32, height: s * 0.03), Radius.circular(s * 0.01)), Paint()..color = beadColors[j]);
        }
        // Large earrings
        canvas.drawCircle(Offset(c.dx - s * 0.22, c.dy + s * 0.10), s * 0.03, gold);
        canvas.drawCircle(Offset(c.dx + s * 0.22, c.dy + s * 0.10), s * 0.03, gold);
        _drawFemaleEyes(canvas, c, s, const Color(0xFF3E2723));
        _drawLips(canvas, c, s, const Color(0xFFBF360C));
        break;

      case 42: // KOREAN HWARANG — gat hat, elegant
        _drawFace(canvas, c, s, skinOlive, yOff: 0.10, w: 0.36, h: 0.30);
        // Dark straight hair
        _drawHair(canvas, c, s, const Color(0xFF1A1A1A), spread: 0.18);
        // Gat-style hat (wide brim)
        canvas.drawOval(Rect.fromCenter(center: Offset(c.dx, c.dy - s * 0.08), width: s * 0.56, height: s * 0.12), eye);
        // Hat top
        canvas.drawOval(Rect.fromCenter(center: Offset(c.dx, c.dy - s * 0.16), width: s * 0.22, height: s * 0.14), eye);
        // Decorative ribbon
        canvas.drawLine(Offset(c.dx - s * 0.04, c.dy - s * 0.02), Offset(c.dx - s * 0.10, c.dy + s * 0.14), Paint()..color = const Color(0xFFE91E63)..strokeWidth = s * 0.015..strokeCap = StrokeCap.round);
        canvas.drawLine(Offset(c.dx + s * 0.04, c.dy - s * 0.02), Offset(c.dx + s * 0.10, c.dy + s * 0.14), Paint()..color = const Color(0xFFE91E63)..strokeWidth = s * 0.015..strokeCap = StrokeCap.round);
        _drawFemaleEyes(canvas, c, s, const Color(0xFF3E2723));
        _drawSmile(canvas, c, s);
        break;

      case 43: // APACHE WARRIOR WOMAN — feather, war paint
        _drawFace(canvas, c, s, skinBrown, yOff: 0.08, w: 0.40, h: 0.36);
        // Long dark hair
        _drawHair(canvas, c, s, const Color(0xFF1A1A1A), spread: 0.22);
        // Headband
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(c.dx, c.dy - s * 0.04), width: s * 0.48, height: s * 0.04), Radius.circular(s * 0.02)), red);
        // Single feather
        canvas.drawLine(Offset(c.dx + s * 0.16, c.dy - s * 0.04), Offset(c.dx + s * 0.24, c.dy - s * 0.22), white..strokeWidth = s * 0.025..strokeCap = StrokeCap.round);
        // War paint stripes
        canvas.drawLine(Offset(c.dx - s * 0.16, c.dy + s * 0.10), Offset(c.dx - s * 0.06, c.dy + s * 0.10), red..strokeWidth = s * 0.018);
        canvas.drawLine(Offset(c.dx + s * 0.06, c.dy + s * 0.10), Offset(c.dx + s * 0.16, c.dy + s * 0.10), red);
        _drawFemaleEyes(canvas, c, s, const Color(0xFF4E342E));
        canvas.drawLine(Offset(c.dx - s * 0.05, c.dy + s * 0.20), Offset(c.dx + s * 0.05, c.dy + s * 0.20), line);
        break;

      case 44: // ARTEMIS — crescent moon crown, silver
        _drawFace(canvas, c, s, skin, yOff: 0.10, w: 0.36, h: 0.30);
        // Auburn hair
        _drawHair(canvas, c, s, const Color(0xFF6D4C41), spread: 0.20);
        // Crescent moon crown
        final moon = Paint()..color = const Color(0xFFE0E0E0);
        canvas.drawArc(Rect.fromCenter(center: Offset(c.dx, c.dy - s * 0.12), width: s * 0.32, height: s * 0.32), math.pi * 1.2, math.pi * 0.6, false, moon..strokeWidth = s * 0.04..style = PaintingStyle.stroke);
        // Star on forehead
        _drawStar(canvas, Offset(c.dx, c.dy - s * 0.04), s * 0.03, Paint()..color = const Color(0xFFE0E0E0));
        _drawFemaleEyes(canvas, c, s, const Color(0xFF78909C));
        _drawSmile(canvas, c, s);
        break;

      case 45: // BOUDICA — war crown, fierce red hair
        _drawFace(canvas, c, s, skin, yOff: 0.08, w: 0.40, h: 0.36);
        // Wild red hair
        for (var j = 0; j < 8; j++) {
          final angle = -1.0 + j * 0.3;
          canvas.drawLine(Offset(c.dx + math.cos(angle) * s * 0.18, c.dy - s * 0.04 + math.sin(angle) * s * 0.12), Offset(c.dx + math.cos(angle) * s * 0.36, c.dy - s * 0.08 + math.sin(angle) * s * 0.22), Paint()..color = const Color(0xFFBF360C)..strokeWidth = s * 0.035..strokeCap = StrokeCap.round);
        }
        // Bronze torque crown
        canvas.drawArc(Rect.fromCenter(center: Offset(c.dx, c.dy - s * 0.04), width: s * 0.42, height: s * 0.14), math.pi, math.pi, false, Paint()..color = const Color(0xFFCD7F32)..strokeWidth = s * 0.03..style = PaintingStyle.stroke);
        _drawFemaleEyes(canvas, c, s, const Color(0xFF2E7D32));
        _drawAngryBrows(canvas, c, s, yOff: 0.02);
        // War cry mouth
        canvas.drawOval(Rect.fromCenter(center: Offset(c.dx, c.dy + s * 0.22), width: s * 0.10, height: s * 0.06), Paint()..color = const Color(0xFF8B0000));
        break;

      case 46: // JOAN OF ARC — short hair, armor, halo
        _drawFace(canvas, c, s, skin, yOff: 0.10, w: 0.36, h: 0.30);
        // Short brown hair (bob)
        final bob = Path()
          ..moveTo(c.dx - s * 0.22, c.dy + s * 0.08)
          ..quadraticBezierTo(c.dx - s * 0.24, c.dy - s * 0.10, c.dx, c.dy - s * 0.18)
          ..quadraticBezierTo(c.dx + s * 0.24, c.dy - s * 0.10, c.dx + s * 0.22, c.dy + s * 0.08)
          ..close();
        canvas.drawPath(bob, Paint()..color = const Color(0xFF5D4037));
        // Halo
        canvas.drawCircle(Offset(c.dx, c.dy - s * 0.04), s * 0.28, Paint()..color = const Color(0xFFFFD54F).withValues(alpha: 0.2)..style = PaintingStyle.stroke..strokeWidth = s * 0.02);
        // Armor collar
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(c.dx, c.dy + s * 0.24), width: s * 0.30, height: s * 0.06), Radius.circular(s * 0.02)), Paint()..color = const Color(0xFF9E9E9E));
        _drawFemaleEyes(canvas, c, s, const Color(0xFF42A5F5));
        _drawSmile(canvas, c, s);
        break;

      case 47: // TOMOE GOZEN — samurai helmet, feminine
        _drawFace(canvas, c, s, skinOlive, yOff: 0.12, w: 0.34, h: 0.28);
        // Long black hair flowing
        _drawHair(canvas, c, s, const Color(0xFF1A1A1A), spread: 0.20);
        // Elegant kabuto (smaller, feminine)
        final tHelmet = Path()
          ..moveTo(c.dx - s * 0.22, c.dy + s * 0.02)
          ..quadraticBezierTo(c.dx, c.dy - s * 0.22, c.dx + s * 0.22, c.dy + s * 0.02)
          ..close();
        canvas.drawPath(tHelmet, Paint()..color = const Color(0xFF880E4F));
        // Gold crescent maedate
        canvas.drawArc(Rect.fromCenter(center: Offset(c.dx, c.dy - s * 0.18), width: s * 0.24, height: s * 0.16), math.pi, math.pi, false, gold..strokeWidth = s * 0.025..style = PaintingStyle.stroke);
        _drawFemaleEyes(canvas, c, s, const Color(0xFF4E342E));
        canvas.drawLine(Offset(c.dx - s * 0.05, c.dy + s * 0.20), Offset(c.dx + s * 0.05, c.dy + s * 0.20), line);
        break;

      case 48: // ZENOBIA — Palmyrene crown, regal warrior
        _drawFace(canvas, c, s, skinOlive, yOff: 0.10, w: 0.36, h: 0.30);
        // Dark wavy hair
        _drawHair(canvas, c, s, const Color(0xFF1A1A1A), spread: 0.22);
        // Radiate crown (sun rays)
        for (var j = 0; j < 7; j++) {
          final angle = -0.8 + j * 0.26;
          canvas.drawLine(Offset(c.dx + math.sin(angle) * s * 0.14, c.dy - s * 0.10), Offset(c.dx + math.sin(angle) * s * 0.24, c.dy - s * 0.26), gold..strokeWidth = s * 0.02..strokeCap = StrokeCap.round);
        }
        // Crown base
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(c.dx, c.dy - s * 0.06), width: s * 0.36, height: s * 0.06), Radius.circular(s * 0.02)), gold);
        // Center gem
        canvas.drawCircle(Offset(c.dx, c.dy - s * 0.06), s * 0.025, Paint()..color = const Color(0xFFD32F2F));
        _drawFemaleEyes(canvas, c, s, const Color(0xFF4E342E));
        _drawLips(canvas, c, s, const Color(0xFFBF360C));
        break;

      case 49: // SCYTHIAN WARRIOR WOMAN — pointed hood, bow
        _drawFace(canvas, c, s, skin, yOff: 0.10, w: 0.36, h: 0.30);
        // Pointed hood/cap
        final sHood = Path()
          ..moveTo(c.dx - s * 0.20, c.dy + s * 0.04)
          ..lineTo(c.dx + s * 0.06, c.dy - s * 0.36)
          ..lineTo(c.dx + s * 0.20, c.dy + s * 0.04)
          ..close();
        canvas.drawPath(sHood, Paint()..color = const Color(0xFFBF360C));
        // Gold trim
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(c.dx, c.dy + s * 0.02), width: s * 0.42, height: s * 0.04), Radius.circular(s * 0.02)), gold);
        // Loose blonde strands
        canvas.drawLine(Offset(c.dx - s * 0.16, c.dy + s * 0.04), Offset(c.dx - s * 0.20, c.dy + s * 0.20), Paint()..color = const Color(0xFFDAA520)..strokeWidth = s * 0.015..strokeCap = StrokeCap.round);
        canvas.drawLine(Offset(c.dx + s * 0.16, c.dy + s * 0.04), Offset(c.dx + s * 0.20, c.dy + s * 0.20), Paint()..color = const Color(0xFFDAA520)..strokeWidth = s * 0.015..strokeCap = StrokeCap.round);
        _drawFemaleEyes(canvas, c, s, const Color(0xFF42A5F5));
        canvas.drawLine(Offset(c.dx - s * 0.05, c.dy + s * 0.20), Offset(c.dx + s * 0.05, c.dy + s * 0.20), line);
        break;

      case 50: // HAWAIIAN QUEEN — flower lei crown, warm
        _drawFace(canvas, c, s, skinBrown, yOff: 0.08, w: 0.40, h: 0.36);
        // Long dark wavy hair
        _drawHair(canvas, c, s, const Color(0xFF1A1A1A), spread: 0.24);
        // Flower crown (lei po'o)
        final flowerColors = [const Color(0xFFE91E63), const Color(0xFFFF5722), const Color(0xFFFFEB3B), const Color(0xFFE91E63), const Color(0xFFFF5722)];
        for (var j = 0; j < 5; j++) {
          final fx = c.dx - s * 0.16 + j * s * 0.08;
          canvas.drawCircle(Offset(fx, c.dy - s * 0.06), s * 0.035, Paint()..color = flowerColors[j]);
          canvas.drawCircle(Offset(fx, c.dy - s * 0.06), s * 0.015, Paint()..color = const Color(0xFFFFEB3B));
        }
        // Leaf accents
        canvas.drawLine(Offset(c.dx - s * 0.22, c.dy - s * 0.02), Offset(c.dx - s * 0.28, c.dy + s * 0.06), Paint()..color = const Color(0xFF2E7D32)..strokeWidth = s * 0.015..strokeCap = StrokeCap.round);
        canvas.drawLine(Offset(c.dx + s * 0.22, c.dy - s * 0.02), Offset(c.dx + s * 0.28, c.dy + s * 0.06), Paint()..color = const Color(0xFF2E7D32)..strokeWidth = s * 0.015..strokeCap = StrokeCap.round);
        _drawFemaleEyes(canvas, c, s, const Color(0xFF4E342E));
        _drawSmile(canvas, c, s);
        break;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // Helper methods
  // ═══════════════════════════════════════════════════════════════════

  void _drawFace(Canvas canvas, Offset c, double s, Paint paint, {required double yOff, required double w, required double h}) {
    canvas.drawOval(Rect.fromCenter(center: Offset(c.dx, c.dy + s * yOff), width: s * w, height: s * h), paint);
  }

  void _drawEyes(Canvas canvas, Offset c, double s, Paint paint, {required double yOff, double sz = 0.025}) {
    canvas.drawCircle(Offset(c.dx - s * 0.08, c.dy + s * yOff), s * sz, paint);
    canvas.drawCircle(Offset(c.dx + s * 0.08, c.dy + s * yOff), s * sz, paint);
  }

  void _drawFemaleEyes(Canvas canvas, Offset c, double s, Color irisColor, {double yOff = 0.10, double sz = 0.022}) {
    final eye = Paint()..color = const Color(0xFF1A1A1A);
    final iris = Paint()..color = irisColor;
    // White of eyes
    canvas.drawOval(Rect.fromCenter(center: Offset(c.dx - s * 0.08, c.dy + s * yOff), width: s * 0.07, height: s * 0.05), Paint()..color = Colors.white);
    canvas.drawOval(Rect.fromCenter(center: Offset(c.dx + s * 0.08, c.dy + s * yOff), width: s * 0.07, height: s * 0.05), Paint()..color = Colors.white);
    // Iris
    canvas.drawCircle(Offset(c.dx - s * 0.08, c.dy + s * yOff), s * sz, iris);
    canvas.drawCircle(Offset(c.dx + s * 0.08, c.dy + s * yOff), s * sz, iris);
    // Pupil
    canvas.drawCircle(Offset(c.dx - s * 0.08, c.dy + s * yOff), s * 0.010, eye);
    canvas.drawCircle(Offset(c.dx + s * 0.08, c.dy + s * yOff), s * 0.010, eye);
    // Lash line
    canvas.drawArc(Rect.fromCenter(center: Offset(c.dx - s * 0.08, c.dy + s * yOff), width: s * 0.08, height: s * 0.05), math.pi, math.pi, false, eye..strokeWidth = s * 0.012..style = PaintingStyle.stroke);
    canvas.drawArc(Rect.fromCenter(center: Offset(c.dx + s * 0.08, c.dy + s * yOff), width: s * 0.08, height: s * 0.05), math.pi, math.pi, false, eye);
  }

  void _drawAngryBrows(Canvas canvas, Offset c, double s, {double yOff = 0.04}) {
    final brow = Paint()..color = const Color(0xFF1A1A1A)..strokeWidth = s * 0.025..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(c.dx - s * 0.14, c.dy + s * yOff), Offset(c.dx - s * 0.04, c.dy + s * (yOff + 0.02)), brow);
    canvas.drawLine(Offset(c.dx + s * 0.04, c.dy + s * (yOff + 0.02)), Offset(c.dx + s * 0.14, c.dy + s * yOff), brow);
  }

  void _drawMustache(Canvas canvas, Offset c, double s, Color color) {
    final must = Paint()..color = color..strokeWidth = s * 0.025..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    final leftM = Path()..moveTo(c.dx, c.dy + s * 0.18)..quadraticBezierTo(c.dx - s * 0.08, c.dy + s * 0.20, c.dx - s * 0.16, c.dy + s * 0.16);
    final rightM = Path()..moveTo(c.dx, c.dy + s * 0.18)..quadraticBezierTo(c.dx + s * 0.08, c.dy + s * 0.20, c.dx + s * 0.16, c.dy + s * 0.16);
    canvas.drawPath(leftM, must);
    canvas.drawPath(rightM, must);
  }

  void _drawSmile(Canvas canvas, Offset c, double s) {
    final smile = Path()..moveTo(c.dx - s * 0.06, c.dy + s * 0.19)..quadraticBezierTo(c.dx, c.dy + s * 0.24, c.dx + s * 0.06, c.dy + s * 0.19);
    canvas.drawPath(smile, Paint()..color = const Color(0xFF1A1A1A)..style = PaintingStyle.stroke..strokeWidth = s * 0.015..strokeCap = StrokeCap.round);
  }

  void _drawLips(Canvas canvas, Offset c, double s, Color color) {
    // Upper lip
    final upper = Path()
      ..moveTo(c.dx - s * 0.06, c.dy + s * 0.20)
      ..quadraticBezierTo(c.dx - s * 0.02, c.dy + s * 0.18, c.dx, c.dy + s * 0.19)
      ..quadraticBezierTo(c.dx + s * 0.02, c.dy + s * 0.18, c.dx + s * 0.06, c.dy + s * 0.20);
    canvas.drawPath(upper, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = s * 0.015..strokeCap = StrokeCap.round);
    // Lower lip
    final lower = Path()
      ..moveTo(c.dx - s * 0.06, c.dy + s * 0.20)
      ..quadraticBezierTo(c.dx, c.dy + s * 0.25, c.dx + s * 0.06, c.dy + s * 0.20);
    canvas.drawPath(lower, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = s * 0.015..strokeCap = StrokeCap.round);
  }

  void _drawHair(Canvas canvas, Offset c, double s, Color color, {required double spread}) {
    // Side hair flowing down
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(c.dx - s * (spread + 0.06), c.dy - s * 0.04, s * 0.10, s * 0.30), Radius.circular(s * 0.04)), Paint()..color = color);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(c.dx + s * (spread - 0.04), c.dy - s * 0.04, s * 0.10, s * 0.30), Radius.circular(s * 0.04)), Paint()..color = color);
    // Top hair
    final top = Path()
      ..moveTo(c.dx - s * spread, c.dy + s * 0.02)
      ..quadraticBezierTo(c.dx, c.dy - s * 0.22, c.dx + s * spread, c.dy + s * 0.02)
      ..close();
    canvas.drawPath(top, Paint()..color = color);
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    for (var i = 0; i < 5; i++) {
      final angle = -math.pi / 2 + i * 4 * math.pi / 5;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(AvatarPainter old) => old.avatarId != avatarId;
}
