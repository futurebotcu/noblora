import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum NobleMode { date, bff, social, noblara }

extension NobleModeX on NobleMode {
  String get label {
    switch (this) {
      case NobleMode.date:
        return 'Noble Date';
      case NobleMode.bff:
        return 'Noble BFF';
      case NobleMode.social:
        return 'Noble Social';
      case NobleMode.noblara:
        return 'Noblara';
    }
  }

  String get subtitle {
    switch (this) {
      case NobleMode.date:
        return 'Find your match';
      case NobleMode.bff:
        return 'Build your circle';
      case NobleMode.social:
        return 'Join the scene';
      case NobleMode.noblara:
        return 'Community feed';
    }
  }

  String get shortLabel {
    switch (this) {
      case NobleMode.date:
        return 'Date';
      case NobleMode.bff:
        return 'BFF';
      case NobleMode.social:
        return 'Social';
      case NobleMode.noblara:
        return 'Noblara';
    }
  }

  IconData get icon {
    switch (this) {
      case NobleMode.date:
        return Icons.favorite_rounded;
      case NobleMode.bff:
        return Icons.people_rounded;
      case NobleMode.social:
        return Icons.explore_rounded;
      case NobleMode.noblara:
        return Icons.article_rounded;
    }
  }

  Color get accentColor {
    switch (this) {
      case NobleMode.date:
        return AppColors.gold;
      case NobleMode.bff:
        return const Color(0xFF26C6DA); // Teal
      case NobleMode.social:
        return const Color(0xFFAB47BC); // Violet
      case NobleMode.noblara:
        return const Color(0xFFEF5350); // Red
    }
  }

  Color get accentLight {
    switch (this) {
      case NobleMode.date:
        return const Color(0x33C9A84C);
      case NobleMode.bff:
        return const Color(0x3326C6DA);
      case NobleMode.social:
        return const Color(0x33AB47BC);
      case NobleMode.noblara:
        return const Color(0x33EF5350);
    }
  }

  // Subtle scaffold background tint per mode
  Color get bgTint {
    switch (this) {
      case NobleMode.date:
        return const Color(0xFF0D0D0D);
      case NobleMode.bff:
        return const Color(0xFF060E0E); // barely-perceptible teal undertone
      case NobleMode.social:
        return const Color(0xFF090610); // barely-perceptible violet undertone
      case NobleMode.noblara:
        return const Color(0xFF0D0606); // barely-perceptible red undertone
    }
  }
}
