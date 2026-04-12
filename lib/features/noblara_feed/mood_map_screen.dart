import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/mock_mode.dart';
import 'widgets/world_map_view.dart';

// ---------------------------------------------------------------------------
// MoodMapScreen — Noblara World Mood Map
// ---------------------------------------------------------------------------
//
// Premium country-mood overview built from already-analyzed posts.
// Zero AI calls on open: aggregation runs in two SQL RPCs:
//   * fetch_country_moods()         — list of countries + dominant mood
//   * fetch_country_mood_detail(c)  — drill-in for one country
//
// Sample excerpts in the country detail are filtered to is_anonymous = true,
// so identifiable posts are never exposed in the aggregated mood-map context.
// ---------------------------------------------------------------------------

class CountryMood {
  final String countryCode;
  final String dominantMood;
  final int postCount;
  final int moodIntensityAvg;
  final DateTime? lastActivity;

  const CountryMood({
    required this.countryCode,
    required this.dominantMood,
    required this.postCount,
    required this.moodIntensityAvg,
    this.lastActivity,
  });

  factory CountryMood.fromJson(Map<String, dynamic> j) => CountryMood(
        countryCode: j['country_code'] as String,
        dominantMood: j['dominant_mood'] as String,
        postCount: (j['post_count'] as num).toInt(),
        moodIntensityAvg: (j['mood_intensity_avg'] as num?)?.toInt() ?? 0,
        lastActivity: j['last_activity'] != null
            ? DateTime.parse(j['last_activity'] as String)
            : null,
      );
}

// ---------------------------------------------------------------------------
// Mood color palette — single source of truth
// ---------------------------------------------------------------------------

Color moodColor(String? mood) {
  switch (mood) {
    case 'quiet':     return const Color(0xFF6C8FB0); // calm slate-blue
    case 'tender':    return const Color(0xFFE08CA9); // soft rose
    case 'hopeful':   return const Color(0xFF67BE9B); // emerald light
    case 'restless':  return const Color(0xFFC48A2C); // amber
    case 'burning':   return const Color(0xFFD1584A); // crimson
    case 'curious':   return const Color(0xFF9B7DFF); // violet
    case 'reflective':return const Color(0xFF4F89F6); // soft blue
    case 'grounded':  return const Color(0xFF8AA37B); // sage
    case 'late_night':return const Color(0xFF4A4778); // deep indigo
    default:          return const Color(0xFF7E8882); // muted
  }
}

String moodLabel(String? mood) {
  if (mood == null) return 'Unknown';
  switch (mood) {
    case 'late_night': return 'Late Night';
    default:
      return mood[0].toUpperCase() + mood.substring(1);
  }
}

// ---------------------------------------------------------------------------
// Country Insight models (for AI panel)
// ---------------------------------------------------------------------------

class CountryInsightData {
  final String countryCode;
  final String timeWindow;
  final int totalPosts;
  final int uniqueAuthors;
  final double avgQuality;
  final String? dominantMood;
  final List<MoodSlice> moodBreakdown;
  final List<TopicSlice> topTopics;
  final int totalEngagement;
  final String dataQuality;

  const CountryInsightData({
    required this.countryCode,
    required this.timeWindow,
    required this.totalPosts,
    required this.uniqueAuthors,
    required this.avgQuality,
    required this.dominantMood,
    required this.moodBreakdown,
    required this.topTopics,
    required this.totalEngagement,
    required this.dataQuality,
  });

  bool get isInsufficient => dataQuality == 'insufficient';

  factory CountryInsightData.fromJson(Map<String, dynamic> j) {
    final eng = j['engagement'] as Map<String, dynamic>? ?? {};
    return CountryInsightData(
      countryCode: j['country_code'] as String,
      timeWindow: j['time_window'] as String? ?? 'unknown',
      totalPosts: (j['total_posts'] as num?)?.toInt() ?? 0,
      uniqueAuthors: (j['unique_authors'] as num?)?.toInt() ?? 0,
      avgQuality: (j['avg_quality'] as num?)?.toDouble() ?? 0.5,
      dominantMood: j['dominant_mood'] as String?,
      moodBreakdown: (j['mood_breakdown'] as List? ?? [])
          .map((e) => MoodSlice.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      topTopics: (j['top_topics'] as List? ?? [])
          .map((e) => TopicSlice.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      totalEngagement: ((eng['reactions'] as num?)?.toInt() ?? 0) +
          ((eng['echoes'] as num?)?.toInt() ?? 0) +
          ((eng['comments'] as num?)?.toInt() ?? 0),
      dataQuality: j['data_quality'] as String? ?? 'insufficient',
    );
  }
}

class AISummary {
  final String title;
  final String text;
  final String? viralTopic;
  final String? viralReason;
  final double confidence;

  const AISummary({
    required this.title,
    required this.text,
    this.viralTopic,
    this.viralReason,
    required this.confidence,
  });

  factory AISummary.fromJson(Map<String, dynamic> j) => AISummary(
        title: j['summary_title'] as String? ?? '',
        text: j['summary_text'] as String? ?? '',
        viralTopic: j['viral_topic'] as String?,
        viralReason: j['viral_reason'] as String?,
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0.5,
      );
}

// ---------------------------------------------------------------------------
// Providers — insight data + AI summary (keyed by country code)
// ---------------------------------------------------------------------------

final countryInsightDataProvider = FutureProvider.autoDispose
    .family<CountryInsightData, String>((ref, countryCode) async {
  if (isMockMode) {
    return CountryInsightData(
      countryCode: countryCode,
      timeWindow: '72h',
      totalPosts: 6,
      uniqueAuthors: 4,
      avgQuality: 0.7,
      dominantMood: 'curious',
      moodBreakdown: const [MoodSlice(mood: 'curious', count: 3), MoodSlice(mood: 'quiet', count: 2)],
      topTopics: const [TopicSlice(topic: 'travel', count: 3), TopicSlice(topic: 'work', count: 2)],
      totalEngagement: 8,
      dataQuality: 'moderate',
    );
  }
  final res = await Supabase.instance.client.rpc(
    'fetch_country_insight_data',
    params: {'p_country': countryCode},
  );
  return CountryInsightData.fromJson(Map<String, dynamic>.from(res as Map));
});

final countryAISummaryProvider = FutureProvider.autoDispose
    .family<AISummary?, ({String code, String name, CountryInsightData data})>(
        (ref, args) async {
  if (isMockMode || args.data.isInsufficient) return null;
  try {
    final res = await Supabase.instance.client.functions.invoke(
      'nob-country-insight',
      body: {
        'country_code': args.code,
        'country_name': args.name,
        'time_window': args.data.timeWindow,
        'total_posts': args.data.totalPosts,
        'unique_authors': args.data.uniqueAuthors,
        'avg_quality': args.data.avgQuality,
        'dominant_mood': args.data.dominantMood,
        'mood_breakdown': args.data.moodBreakdown
            .map((m) => {'mood': m.mood, 'count': m.count})
            .toList(),
        'top_topics': args.data.topTopics
            .map((t) => {'topic': t.topic, 'count': t.count})
            .toList(),
        'engagement': {'reactions': args.data.totalEngagement, 'echoes': 0, 'comments': 0},
        'data_quality': args.data.dataQuality,
      },
    );
    if (res.data is Map && res.data['summary_title'] != null) {
      return AISummary.fromJson(Map<String, dynamic>.from(res.data));
    }
    return null;
  } catch (e) {
    debugPrint('[countryAISummary] $e');
    return null;
  }
});

// ---------------------------------------------------------------------------
// Provider — fetch country list (autoDispose: refetch every open)
// ---------------------------------------------------------------------------

final countryMoodsProvider =
    FutureProvider.autoDispose<List<CountryMood>>((ref) async {
  if (isMockMode) {
    return const [
      CountryMood(
        countryCode: 'Turkey',
        dominantMood: 'quiet',
        postCount: 6,
        moodIntensityAvg: 60,
      ),
    ];
  }
  final res = await Supabase.instance.client.rpc('fetch_country_moods');
  if (res is List) {
    return res
        .map((r) => CountryMood.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }
  return const [];
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class MoodMapScreen extends ConsumerStatefulWidget {
  const MoodMapScreen({super.key});

  @override
  ConsumerState<MoodMapScreen> createState() => _MoodMapScreenState();
}

class _MoodMapScreenState extends ConsumerState<MoodMapScreen> {
  /// Currently selected country canonical name (for inline insight panel).
  String? _selectedCountry;
  /// Resolved CountryMood for the selected country (for color/mood access).
  CountryMood? _selectedMood;

  @override
  Widget build(BuildContext context) {
    final asyncCountries = ref.watch(countryMoodsProvider);

    return Scaffold(
      backgroundColor: AppColors.nobBackground,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Color(0xFFE6EBE7)),
        title: const Text(
          'World Mood',
          style: TextStyle(
            color: Color(0xFFE6EBE7),
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Builder(
            builder: (btnCtx) => IconButton(
              tooltip: 'Browse list',
              icon: Icon(Icons.format_list_bulleted_rounded,
                  color: context.textMuted, size: 20),
              onPressed: () async {
                HapticFeedback.selectionClick();
                final list = asyncCountries.asData?.value ?? const [];
                if (list.isEmpty) return;
                final picked = await showModalBottomSheet<CountryMood>(
                  context: btnCtx,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (_) => _CountryListSheet(countries: list),
                );
                if (picked != null && btnCtx.mounted) {
                  setState(() {
                    _selectedCountry = picked.countryCode;
                    _selectedMood = picked;
                  });
                }
              },
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(Icons.refresh_rounded,
                color: context.textMuted, size: 20),
            onPressed: () {
              HapticFeedback.selectionClick();
              ref.invalidate(countryMoodsProvider);
              setState(() {
                _selectedCountry = null;
                _selectedMood = null;
              });
            },
          ),
        ],
      ),
      body: asyncCountries.when(
        loading: () => const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
                strokeWidth: 1.5, color: AppColors.emerald600),
          ),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Could not load the world mood right now.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.textMuted, fontSize: 13),
            ),
          ),
        ),
        data: (countries) {
          if (countries.isEmpty) return const _EmptyMap();

          // Build canonical-name → mood color map for the painter.
          final coloredCountries = <String, Color>{
            for (final c in countries)
              c.countryCode: moodColor(c.dominantMood),
          };

          return Stack(
            children: [
              // ── World map (full bleed) ─────────────────────────────────
              Positioned.fill(
                child: WorldMapView(
                  coloredCountries: coloredCountries,
                  onCountryTap: (name) =>
                      _onCountryTap(countries, name),
                ),
              ),

              // ── Top floating summary ───────────────────────────────────
              Positioned(
                top: MediaQuery.of(context).padding.top + kToolbarHeight + 4,
                left: 16,
                right: 16,
                child: _WorldSummaryStrip(countries: countries),
              ),

              // ── Bottom: legend OR insight panel ────────────────────────
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, anim) => SlideTransition(
                      position: Tween(
                        begin: const Offset(0, 0.3),
                        end: Offset.zero,
                      ).animate(anim),
                      child: FadeTransition(opacity: anim, child: child),
                    ),
                    child: _selectedCountry != null
                        ? _CountryInsightPanel(
                            key: ValueKey(_selectedCountry),
                            countryCode: _selectedMood?.countryCode ?? _selectedCountry!,
                            countryName: _selectedCountry!,
                            accentColor: moodColor(_selectedMood?.dominantMood),
                            onClose: () => setState(() {
                              _selectedCountry = null;
                              _selectedMood = null;
                            }),
                            onDeepDive: () {
                              final country = _selectedMood ??
                                  CountryMood(
                                    countryCode: _selectedCountry!,
                                    dominantMood: 'unknown',
                                    postCount: 0,
                                    moodIntensityAvg: 0,
                                  );
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: Colors.transparent,
                                isScrollControlled: true,
                                builder: (_) =>
                                    _CountryDetailSheet(country: country),
                              );
                            },
                          )
                        : KeyedSubtree(
                            key: const ValueKey('legend'),
                            child: _MoodLegend(),
                          ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _onCountryTap(List<CountryMood> countries, String canonicalName) {
    HapticFeedback.selectionClick();
    final norm = normalizeCountryName(canonicalName);
    CountryMood? mood;
    for (final c in countries) {
      if (normalizeCountryName(c.countryCode) == norm) {
        mood = c;
        break;
      }
    }
    setState(() {
      _selectedCountry = canonicalName;
      _selectedMood = mood;
    });
  }
}

// ---------------------------------------------------------------------------
// Top floating summary strip — slim, glassy
// ---------------------------------------------------------------------------

class _WorldSummaryStrip extends StatelessWidget {
  final List<CountryMood> countries;
  const _WorldSummaryStrip({required this.countries});

  @override
  Widget build(BuildContext context) {
    final totalPosts = countries.fold<int>(0, (s, c) => s + c.postCount);
    final weighted = <String, int>{};
    for (final c in countries) {
      weighted[c.dominantMood] = (weighted[c.dominantMood] ?? 0) + c.postCount;
    }
    String? worldMood;
    int max = -1;
    weighted.forEach((m, n) {
      if (n > max) {
        max = n;
        worldMood = m;
      }
    });
    final color = moodColor(worldMood);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.nobSurface.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.32)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 18,
              spreadRadius: -4,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color.withValues(alpha: 0.65),
                  color.withValues(alpha: 0.10),
                ],
              ),
              border: Border.all(color: color.withValues(alpha: 0.55)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'The world feels ${moodLabel(worldMood).toLowerCase()}',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '$totalPosts ${totalPosts == 1 ? 'Nob' : 'Nobs'} · ${countries.length} ${countries.length == 1 ? 'country' : 'countries'} reporting',
                  style: TextStyle(color: context.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          Icon(Icons.touch_app_rounded,
              color: context.textMuted.withValues(alpha: 0.7), size: 14),
          const SizedBox(width: 4),
          Text('tap',
              style: TextStyle(color: context.textMuted, fontSize: 10)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom legend strip — horizontally scrollable mood swatches
// ---------------------------------------------------------------------------

class _MoodLegend extends StatelessWidget {
  static const _moods = [
    'quiet',
    'tender',
    'hopeful',
    'reflective',
    'grounded',
    'curious',
    'restless',
    'burning',
    'late_night',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            AppColors.nobBackground,
            AppColors.nobBackground.withValues(alpha: 0),
          ],
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            for (final m in _moods) ...[
              _LegendChip(mood: m),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  final String mood;
  const _LegendChip({required this.mood});

  @override
  Widget build(BuildContext context) {
    final c = moodColor(mood);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.nobSurface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.withValues(alpha: 0.85),
              border: Border.all(color: c, width: 0.5),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            moodLabel(mood),
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Country list bottom sheet — secondary "browse list" view
// ---------------------------------------------------------------------------

class _CountryListSheet extends StatelessWidget {
  final List<CountryMood> countries;
  const _CountryListSheet({required this.countries});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scroll) => Container(
        decoration: BoxDecoration(
          color: AppColors.nobSurface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(22)),
          border: Border(
            top: BorderSide(
                color: AppColors.emerald600.withValues(alpha: 0.4), width: 1.5),
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.nobBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
              child: Row(
                children: [
                  Text(
                    'COUNTRIES REPORTING',
                    style: TextStyle(
                      color: context.textMuted,
                      fontSize: 10,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${countries.length}',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Divider(
                color: AppColors.nobBorder.withValues(alpha: 0.5), height: 1),
            Expanded(
              child: ListView.separated(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
                itemCount: countries.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) => _CountryTile(
                  country: countries[i],
                  onTap: () =>
                      Navigator.of(ctx).pop<CountryMood>(countries[i]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Country list tile
// ---------------------------------------------------------------------------

class _CountryTile extends StatelessWidget {
  final CountryMood country;
  final VoidCallback onTap;
  const _CountryTile({required this.country, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = moodColor(country.dominantMood);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: AppColors.nobSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.nobBorder.withValues(alpha: 0.55)),
        ),
        child: Row(
          children: [
            // Mood swatch
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    color.withValues(alpha: 0.55),
                    color.withValues(alpha: 0.12),
                  ],
                ),
                border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    country.countryCode,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: color.withValues(alpha: 0.30)),
                        ),
                        child: Text(
                          moodLabel(country.dominantMood).toUpperCase(),
                          style: TextStyle(
                            color: color,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${country.postCount} ${country.postCount == 1 ? 'Nob' : 'Nobs'}',
                        style: TextStyle(color: context.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyMap extends StatelessWidget {
  const _EmptyMap();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.emerald600.withValues(alpha: 0.08),
                border: Border.all(
                    color: AppColors.emerald600.withValues(alpha: 0.18)),
              ),
              child: Icon(Icons.public_rounded,
                  color: AppColors.emerald600.withValues(alpha: 0.5), size: 28),
            ),
            const SizedBox(height: 18),
            Text(
              'The world is quiet',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'No analyzed Nobs yet. Once people start sharing,\nthe world mood will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.textMuted, fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Country detail bottom sheet
// ---------------------------------------------------------------------------

class _CountryDetailSheet extends ConsumerWidget {
  final CountryMood country;
  const _CountryDetailSheet({required this.country});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(countryDetailProvider(country.countryCode));
    final color = moodColor(country.dominantMood);

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: AppColors.nobSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          border: Border(
              top: BorderSide(color: color.withValues(alpha: 0.4), width: 1.5)),
        ),
        child: Column(
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.nobBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          color.withValues(alpha: 0.55),
                          color.withValues(alpha: 0.12),
                        ],
                      ),
                      border: Border.all(color: color.withValues(alpha: 0.4)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          country.countryCode,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          country.postCount == 0
                              ? 'no signal yet'
                              : 'feels ${moodLabel(country.dominantMood).toLowerCase()}',
                          style: TextStyle(
                            color: country.postCount == 0
                                ? context.textMuted
                                : color,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: AppColors.nobBorder.withValues(alpha: 0.5), height: 1),
            Expanded(
              child: detailAsync.when(
                loading: () => const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.5, color: AppColors.emerald600),
                  ),
                ),
                error: (e, _) => Center(
                  child: Text('Could not load details',
                      style: TextStyle(color: context.textMuted, fontSize: 13)),
                ),
                data: (detail) {
                  // Graceful empty state for countries with no signal yet.
                  if (detail.totalPosts == 0) {
                    return _NoSignalView(
                      countryName: country.countryCode,
                      scrollCtrl: scrollCtrl,
                    );
                  }
                  return ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                    children: [
                      Row(
                        children: [
                          _StatPill(
                            icon: Icons.bolt_rounded,
                            label: 'signal',
                            value: '${detail.totalPosts}',
                            color: color,
                          ),
                          const SizedBox(width: 8),
                          if (detail.moodBreakdown.length > 1)
                            _StatPill(
                              icon: Icons.layers_rounded,
                              label: 'moods',
                              value: '${detail.moodBreakdown.length}',
                              color: color,
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _SectionTitle('MOOD BREAKDOWN'),
                      const SizedBox(height: 10),
                      _MoodBreakdown(breakdown: detail.moodBreakdown),
                      if (detail.topTopics.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _SectionTitle('TOP TOPICS'),
                        const SizedBox(height: 6),
                        Text(
                          'Most-discussed themes in this country.',
                          style:
                              TextStyle(color: context.textMuted, fontSize: 11),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final t in detail.topTopics)
                              _TopicChip(topic: t.topic, count: t.count),
                          ],
                        ),
                      ],
                      const SizedBox(height: 24),
                      _SectionTitle('SAMPLE NOBS'),
                      const SizedBox(height: 6),
                      Text(
                        'Anonymous Nobs from this country.',
                        style:
                            TextStyle(color: context.textMuted, fontSize: 11),
                      ),
                      const SizedBox(height: 12),
                      if (detail.samples.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          alignment: Alignment.center,
                          child: Text(
                            'No anonymous Nobs to share yet.',
                            style: TextStyle(
                                color: context.textMuted, fontSize: 12),
                          ),
                        )
                      else
                        for (final s in detail.samples) ...[
                          _SampleCard(sample: s),
                          const SizedBox(height: 10),
                        ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Country detail data + provider
// ---------------------------------------------------------------------------

class CountryMoodDetail {
  final String countryCode;
  final String? dominantMood;
  final int totalPosts;
  final List<MoodSlice> moodBreakdown;
  final List<TopicSlice> topTopics;
  final List<MoodSample> samples;

  const CountryMoodDetail({
    required this.countryCode,
    required this.dominantMood,
    required this.totalPosts,
    required this.moodBreakdown,
    required this.topTopics,
    required this.samples,
  });

  factory CountryMoodDetail.fromJson(Map<String, dynamic> j) {
    final breakdown = (j['mood_breakdown'] as List? ?? [])
        .map((e) => MoodSlice.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final topics = (j['top_topics'] as List? ?? [])
        .map((e) => TopicSlice.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final samples = (j['samples'] as List? ?? [])
        .map((e) => MoodSample.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return CountryMoodDetail(
      countryCode: j['country_code'] as String,
      dominantMood: j['dominant_mood'] as String?,
      totalPosts: (j['total_posts'] as num?)?.toInt() ?? 0,
      moodBreakdown: breakdown,
      topTopics: topics,
      samples: samples,
    );
  }
}

class MoodSlice {
  final String mood;
  final int count;
  const MoodSlice({required this.mood, required this.count});
  factory MoodSlice.fromJson(Map<String, dynamic> j) =>
      MoodSlice(mood: j['mood'] as String, count: (j['count'] as num).toInt());
}

class TopicSlice {
  final String topic;
  final int count;
  const TopicSlice({required this.topic, required this.count});
  factory TopicSlice.fromJson(Map<String, dynamic> j) =>
      TopicSlice(topic: j['topic'] as String, count: (j['count'] as num).toInt());
}

class MoodSample {
  final String id;
  final String? content;
  final String? caption;
  final String nobType;
  final String? primaryMood;
  final DateTime createdAt;
  const MoodSample({
    required this.id,
    required this.content,
    required this.caption,
    required this.nobType,
    required this.primaryMood,
    required this.createdAt,
  });
  factory MoodSample.fromJson(Map<String, dynamic> j) => MoodSample(
        id: j['id'] as String,
        content: j['content'] as String?,
        caption: j['caption'] as String?,
        nobType: (j['nob_type'] as String?) ?? 'thought',
        primaryMood: j['primary_mood'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  String get displayText {
    if (nobType == 'moment' && (caption?.isNotEmpty ?? false)) return caption!;
    return content ?? '';
  }
}

final countryDetailProvider = FutureProvider.autoDispose
    .family<CountryMoodDetail, String>((ref, countryCode) async {
  if (isMockMode) {
    return CountryMoodDetail(
      countryCode: countryCode,
      dominantMood: 'quiet',
      totalPosts: 6,
      moodBreakdown: const [MoodSlice(mood: 'quiet', count: 2)],
      topTopics: const [TopicSlice(topic: 'depth', count: 2)],
      samples: const [],
    );
  }
  final res = await Supabase.instance.client.rpc(
    'fetch_country_mood_detail',
    params: {'p_country': countryCode},
  );
  return CountryMoodDetail.fromJson(Map<String, dynamic>.from(res as Map));
});

// ---------------------------------------------------------------------------
// Detail sub-widgets
// ---------------------------------------------------------------------------

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: context.textMuted,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 2,
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(value,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(color: context.textMuted, fontSize: 10.5)),
        ],
      ),
    );
  }
}

class _NoSignalView extends StatelessWidget {
  final String countryName;
  final ScrollController scrollCtrl;
  const _NoSignalView({required this.countryName, required this.scrollCtrl});

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollCtrl,
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
      children: [
        Center(
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.nobBorder.withValues(alpha: 0.4),
                  border: Border.all(
                      color: AppColors.nobBorder.withValues(alpha: 0.7)),
                ),
                child: Icon(Icons.hourglass_empty_rounded,
                    color: context.textMuted, size: 26),
              ),
              const SizedBox(height: 16),
              Text(
                'No signal from $countryName yet',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'No Nobs have been shared from here yet.\nWhen they are, this country will start to glow.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.textMuted,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MoodBreakdown extends StatelessWidget {
  final List<MoodSlice> breakdown;
  const _MoodBreakdown({required this.breakdown});

  @override
  Widget build(BuildContext context) {
    final total = breakdown.fold<int>(0, (s, m) => s + m.count);
    if (total == 0) {
      return Text('No mood data yet',
          style: TextStyle(color: context.textMuted, fontSize: 12));
    }
    return Column(
      children: [
        for (final m in breakdown) ...[
          _MoodBar(mood: m.mood, count: m.count, total: total),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _MoodBar extends StatelessWidget {
  final String mood;
  final int count;
  final int total;
  const _MoodBar({required this.mood, required this.count, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : count / total;
    final color = moodColor(mood);
    return Row(
      children: [
        SizedBox(
          width: 84,
          child: Text(moodLabel(mood),
              style: TextStyle(color: context.textPrimary, fontSize: 12)),
        ),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: AppColors.nobSurfaceAlt,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              FractionallySizedBox(
                widthFactor: pct.clamp(0.0, 1.0),
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 38,
          child: Text(
            '${(pct * 100).round()}%',
            textAlign: TextAlign.right,
            style: TextStyle(color: context.textMuted, fontSize: 11),
          ),
        ),
      ],
    );
  }
}

class _TopicChip extends StatelessWidget {
  final String topic;
  final int count;
  const _TopicChip({required this.topic, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.nobSurfaceAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.nobBorder.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(topic,
              style: TextStyle(color: context.textPrimary, fontSize: 12)),
          const SizedBox(width: 6),
          Text('$count',
              style: TextStyle(color: context.textMuted, fontSize: 11)),
        ],
      ),
    );
  }
}

class _SampleCard extends StatelessWidget {
  final MoodSample sample;
  const _SampleCard({required this.sample});

  @override
  Widget build(BuildContext context) {
    final color = moodColor(sample.primaryMood);
    final text = sample.displayText.trim();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.nobSurfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: color.withValues(alpha: 0.7), width: 2.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.visibility_off_rounded,
                  color: context.textMuted.withValues(alpha: 0.7), size: 12),
              const SizedBox(width: 4),
              Text('Anonymous',
                  style: TextStyle(
                    color: context.textMuted,
                    fontSize: 10,
                    letterSpacing: 0.4,
                  )),
              const Spacer(),
              if (sample.primaryMood != null)
                Text(
                  moodLabel(sample.primaryMood),
                  style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            text.isEmpty ? '(no text)' : text,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 13.5,
              height: 1.45,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Country Insight Panel — inline AI-powered summary at the bottom of the map
// ---------------------------------------------------------------------------

class _CountryInsightPanel extends ConsumerWidget {
  final String countryCode;
  final String countryName;
  final Color accentColor;
  final VoidCallback onClose;
  final VoidCallback onDeepDive;

  const _CountryInsightPanel({
    super.key,
    required this.countryCode,
    required this.countryName,
    required this.accentColor,
    required this.onClose,
    required this.onDeepDive,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightAsync = ref.watch(countryInsightDataProvider(countryCode));

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 6),
      decoration: BoxDecoration(
        color: AppColors.nobSurface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 24,
            spreadRadius: -6,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: insightAsync.when(
        loading: () => _buildShell(
          context,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 1.5, color: AppColors.emerald600),
              ),
            ),
          ),
        ),
        error: (e, _) => _buildShell(
          context,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'Could not load insight right now.',
                style: TextStyle(color: context.textMuted, fontSize: 12),
              ),
            ),
          ),
        ),
        data: (data) {
          if (data.isInsufficient) {
            return _buildShell(
              context,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: context.textMuted, size: 16),
                    const SizedBox(height: 8),
                    Text(
                      'Not enough anonymous activity in this region yet.',
                      style: TextStyle(
                          color: context.textMuted,
                          fontSize: 12.5,
                          height: 1.4),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${data.totalPosts} ${data.totalPosts == 1 ? 'post' : 'posts'} in the last 7 days',
                      style: TextStyle(
                          color: context.textMuted.withValues(alpha: 0.7),
                          fontSize: 11),
                    ),
                  ],
                ),
              ),
            );
          }
          return _buildDataPanel(context, ref, data);
        },
      ),
    );
  }

  Widget _buildShell(BuildContext context, {required Widget child}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(context),
        child,
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor,
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.5),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              countryName,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.1,
              ),
            ),
          ),
          GestureDetector(
            onTap: onDeepDive,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(Icons.open_in_full_rounded,
                  color: context.textMuted, size: 14),
            ),
          ),
          GestureDetector(
            onTap: onClose,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(Icons.close_rounded,
                  color: context.textMuted, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataPanel(
      BuildContext context, WidgetRef ref, CountryInsightData data) {
    final moodC = moodColor(data.dominantMood);

    // Trigger AI summary fetch (keyed by aggregate data to avoid redundant calls)
    final aiAsync = ref.watch(countryAISummaryProvider(
      (code: countryCode, name: countryName, data: data),
    ));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        const SizedBox(height: 10),

        // ── Mood + stats row ─────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: moodC.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: moodC.withValues(alpha: 0.35)),
                ),
                child: Text(
                  moodLabel(data.dominantMood),
                  style: TextStyle(
                      color: moodC,
                      fontSize: 11,
                      fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${data.totalPosts} posts',
                style: TextStyle(color: context.textMuted, fontSize: 11),
              ),
              const SizedBox(width: 6),
              Text('·', style: TextStyle(color: context.textMuted)),
              const SizedBox(width: 6),
              Text(
                '${data.uniqueAuthors} voices',
                style: TextStyle(color: context.textMuted, fontSize: 11),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.nobSurfaceAlt,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  data.timeWindow == '72h' ? '3 days' : '7 days',
                  style: TextStyle(
                      color: context.textMuted,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),

        // ── Topics ───────────────────────────────────────────────────
        if (data.topTopics.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 28,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: data.topTopics.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final t = data.topTopics[i];
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.nobSurfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.nobBorder.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    '${t.topic} (${t.count})',
                    style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500),
                  ),
                );
              },
            ),
          ),
        ],

        // ── AI summary ───────────────────────────────────────────────
        const SizedBox(height: 10),
        aiAsync.when(
          loading: () => Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Row(
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                      strokeWidth: 1,
                      color: AppColors.emerald600.withValues(alpha: 0.5)),
                ),
                const SizedBox(width: 8),
                Text('Generating insight…',
                    style: TextStyle(
                        color: context.textMuted,
                        fontSize: 11,
                        fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          error: (_, __) => _buildAiFallback(context, data),
          data: (ai) {
            if (ai == null) return _buildAiFallback(context, data);
            return _buildAiSummary(context, data, ai);
          },
        ),
      ],
    );
  }

  Widget _buildAiFallback(BuildContext context, CountryInsightData data) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_outlined,
                  color: context.textMuted.withValues(alpha: 0.5), size: 13),
              const SizedBox(width: 6),
              Text(
                'AI summary unavailable right now',
                style: TextStyle(
                    color: context.textMuted,
                    fontSize: 11,
                    fontStyle: FontStyle.italic),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Based on recent anonymous Nob activity.',
            style: TextStyle(
                color: context.textMuted.withValues(alpha: 0.6),
                fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildAiSummary(
      BuildContext context, CountryInsightData data, AISummary ai) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.auto_awesome_rounded,
                  color: AppColors.emerald600.withValues(alpha: 0.8),
                  size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  ai.title,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Summary text
          Text(
            ai.text,
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 12,
              height: 1.5,
            ),
          ),

          // Viral topic highlight
          if (ai.viralTopic != null && ai.viralTopic!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.emerald600.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.emerald600.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.trending_up_rounded,
                      color: AppColors.emerald600, size: 13),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      ai.viralTopic!,
                      style: const TextStyle(
                        color: AppColors.emerald600,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),

          // Footer
          Row(
            children: [
              Text(
                'Based on anonymous Nob activity',
                style: TextStyle(
                    color: context.textMuted.withValues(alpha: 0.5),
                    fontSize: 9.5),
              ),
              const Spacer(),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ai.confidence >= 0.7
                      ? AppColors.emerald600
                      : ai.confidence >= 0.4
                          ? const Color(0xFFC48A2C)
                          : context.textMuted,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                ai.confidence >= 0.7
                    ? 'High confidence'
                    : ai.confidence >= 0.4
                        ? 'Moderate'
                        : 'Limited data',
                style: TextStyle(
                    color: context.textMuted.withValues(alpha: 0.6),
                    fontSize: 9.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
