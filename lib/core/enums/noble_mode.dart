import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// R18 — BFF removed from V1. Only `date` (Discover / Match / Chat) and
/// `noblara` (community feed, currently gated behind kSocialEnabled=false)
/// remain. Existing match rows with `mode='bff'` still exist in the DB
/// but no V1 code path constructs `NobleMode.bff`; matches_screen filters
/// them out via the active-modes/string check before this enum sees them.
enum NobleMode { date, noblara }

extension NobleModeX on NobleMode {
  String get label {
    switch (this) {
      case NobleMode.date:
        return 'Noble Date';
      case NobleMode.noblara:
        return 'Noblara';
    }
  }

  String get subtitle {
    switch (this) {
      case NobleMode.date:
        return 'Find your match';
      case NobleMode.noblara:
        return 'Community feed';
    }
  }

  String get shortLabel {
    switch (this) {
      case NobleMode.date:
        return 'Date';
      case NobleMode.noblara:
        return 'Noblara';
    }
  }

  IconData get icon {
    switch (this) {
      case NobleMode.date:
        return Icons.favorite_rounded;
      case NobleMode.noblara:
        return Icons.article_rounded;
    }
  }

  Color get accentColor {
    switch (this) {
      case NobleMode.date:
        return AppColors.emerald500;
      case NobleMode.noblara:
        return AppColors.emerald500;
    }
  }

  Color get accentLight {
    switch (this) {
      case NobleMode.date:
        return AppColors.emerald600.withValues(alpha: 0.14);
      case NobleMode.noblara:
        return AppColors.emerald600.withValues(alpha: 0.14);
    }
  }

  Color get bgTint {
    switch (this) {
      case NobleMode.date:
        return AppColors.bg;
      case NobleMode.noblara:
        return AppColors.bg;
    }
  }
}
