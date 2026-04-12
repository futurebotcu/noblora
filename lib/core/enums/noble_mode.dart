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
        return AppColors.emerald500;
      case NobleMode.bff:
        return AppColors.emerald600;
      case NobleMode.social:
        return AppColors.violet;
      case NobleMode.noblara:
        return AppColors.emerald500;
    }
  }

  Color get accentLight {
    switch (this) {
      case NobleMode.date:
        return AppColors.emerald600.withValues(alpha: 0.14);
      case NobleMode.bff:
        return AppColors.emerald600.withValues(alpha: 0.14);
      case NobleMode.social:
        return AppColors.violet.withValues(alpha: 0.14);
      case NobleMode.noblara:
        return AppColors.emerald600.withValues(alpha: 0.14);
    }
  }

  Color get bgTint {
    switch (this) {
      case NobleMode.date:
        return AppColors.bg;
      case NobleMode.bff:
        return const Color(0xFF0A0E0D);
      case NobleMode.social:
        return const Color(0xFF0C0B0F);
      case NobleMode.noblara:
        return AppColors.bg;
    }
  }
}
