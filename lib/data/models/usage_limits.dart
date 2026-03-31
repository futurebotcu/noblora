/// Tier-based usage limits configuration.
/// Limits are enforced server-side via RPC functions,
/// but this model provides client-side display info.
class UsageLimits {
  final String tier; // 'observer' | 'explorer' | 'noble'
  final int dailySwipesUsed;
  final int dailyConnectionsUsed;
  final int dailySignalsUsed;
  final int weeklySignalsUsed;
  final int monthlySignalsUsed;
  final int dailyNotesUsed;
  final int weeklyNotesUsed;

  const UsageLimits({
    required this.tier,
    this.dailySwipesUsed = 0,
    this.dailyConnectionsUsed = 0,
    this.dailySignalsUsed = 0,
    this.weeklySignalsUsed = 0,
    this.monthlySignalsUsed = 0,
    this.dailyNotesUsed = 0,
    this.weeklyNotesUsed = 0,
  });

  factory UsageLimits.fromProfile(Map<String, dynamic> json) {
    return UsageLimits(
      tier: json['nob_tier'] as String? ?? 'observer',
      dailySwipesUsed: json['daily_swipes_used'] as int? ?? 0,
      dailyConnectionsUsed: json['daily_connections'] as int? ?? 0,
      dailySignalsUsed: json['daily_signals_used'] as int? ?? 0,
      weeklySignalsUsed: json['weekly_signals_used'] as int? ?? 0,
      monthlySignalsUsed: json['monthly_signals_used'] as int? ?? 0,
      dailyNotesUsed: json['daily_notes_used'] as int? ?? 0,
      weeklyNotesUsed: json['weekly_notes_used'] as int? ?? 0,
    );
  }

  // Max limits per tier
  int get maxDailySwipes => switch (tier) {
        'observer' => 30,
        'explorer' => 50,
        'noble' => 100,
        _ => 30,
      };

  int get maxDailyConnections => switch (tier) {
        'observer' => 2,
        'explorer' => 4,
        'noble' => 7,
        _ => 2,
      };

  int get remainingSwipes => (maxDailySwipes - dailySwipesUsed).clamp(0, maxDailySwipes);
  int get remainingConnections => (maxDailyConnections - dailyConnectionsUsed).clamp(0, maxDailyConnections);

  bool get canSwipe => dailySwipesUsed < maxDailySwipes;
  bool get canConnect => dailyConnectionsUsed < maxDailyConnections;
}
