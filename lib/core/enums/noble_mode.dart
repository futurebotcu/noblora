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
        return AppColors.teal;
      case NobleMode.social:
        return AppColors.violet;
      case NobleMode.noblara:
        return AppColors.gold;
    }
  }

  Color get accentLight {
    switch (this) {
      case NobleMode.date:
        return AppColors.goldLight;
      case NobleMode.bff:
        return const Color(0x2226C6DA);
      case NobleMode.social:
        return const Color(0x229B6DFF);
      case NobleMode.noblara:
        return AppColors.goldLight;
    }
  }

  // Subtle scaffold background tint per mode
  Color get bgTint {
    switch (this) {
      case NobleMode.date:
        return AppColors.bg;
      case NobleMode.bff:
        return const Color(0xFF070A0A);
      case NobleMode.social:
        return const Color(0xFF08070B);
      case NobleMode.noblara:
        return AppColors.bg;
    }
  }
}
