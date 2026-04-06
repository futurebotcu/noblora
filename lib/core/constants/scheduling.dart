import 'package:flutter/material.dart';

/// Shared scheduling constants used across video scheduling,
/// BFF plans, and real meetings for consistent time selection.
abstract final class SchedulingConfig {
  static const int startHour = 8;
  static const int endHour = 22;
  static const int minuteStep = 5;
  static const List<int> minutes = [
    0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55
  ];

  /// Snap a raw minute value to the nearest valid step.
  static int snapMinute(int raw) {
    if (minutes.contains(raw)) return raw;
    return minutes.reduce(
        (a, b) => (a - raw).abs() <= (b - raw).abs() ? a : b);
  }

  /// Snap a TimeOfDay to valid scheduling bounds.
  static TimeOfDay snapTime(TimeOfDay time) {
    return TimeOfDay(
      hour: time.hour.clamp(startHour, endHour),
      minute: snapMinute(time.minute),
    );
  }
}
