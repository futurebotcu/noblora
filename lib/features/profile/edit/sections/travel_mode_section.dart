import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/country_support.dart';
import '../../../../shared/widgets/city_search_screen.dart';
import '../edit_profile_provider.dart';
import '../widgets/edit_section_shell.dart';

/// R13 — Travel Mode section: lets the user toggle "I'm currently traveling"
/// and pick a destination city. The swipe gate
/// (`create_swipe_with_gate` RPC + `CountrySupport.isUserActiveInRegion`)
/// reads `travelMode` + `travelCountry` from this section to decide whether
/// the user can like profiles when their home country is outside TH/VN/PH.
///
/// Kept separate from `travel_section.dart` (Travel & World — visited /
/// lived / wishlist countries + travel style) because the semantics differ:
/// this is a functional setting that gates interactions, not a dating
/// preference attribute.
class TravelModeSection extends ConsumerWidget {
  const TravelModeSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(editProfileProvider).draft;

    Future<void> pickTravelCity() async {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CitySearchScreen(
            initialValue: d.travelCity,
            onSelected: (city, country, lat, lng, countryCode, placeId) {
              ref.read(editProfileProvider.notifier).updateDraft((draft) {
                draft.travelCity = city;
                draft.travelCountry = countryCode;
                draft.travelPlaceId = placeId;
                return draft;
              });
            },
          ),
        ),
      );
    }

    final destinationLabel = _formatDestination(d.travelCity, d.travelCountry);
    final destinationSupported = CountrySupport.isSupported(d.travelCountry);

    return EditSectionShell(
      title: 'Travel Mode',
      description:
          'Activate when traveling. Match with people in your destination '
          'across Thailand, Vietnam, or the Philippines.',
      saving: ref.watch(editProfileProvider).isSaving,
      onSave: () async {
        final ok = await ref.read(editProfileProvider.notifier).save();
        if (ok && context.mounted) Navigator.pop(context);
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        children: [
          const SizedBox(height: AppSpacing.md),

          // Toggle ─────────────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              border: Border.all(color: context.borderColor),
            ),
            child: SwitchListTile(
              title: Text(
                "I'm currently traveling",
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  d.travelMode
                      ? 'You can match with people in your travel destination'
                      : 'Activate to match outside your home country',
                  style: TextStyle(color: context.textMuted, fontSize: 12),
                ),
              ),
              value: d.travelMode,
              activeThumbColor: context.accent,
              onChanged: (v) {
                ref.read(editProfileProvider.notifier).updateDraft((draft) {
                  draft.travelMode = v;
                  return draft;
                });
              },
            ),
          ),

          if (d.travelMode) ...[
            const SizedBox(height: AppSpacing.xxl),

            // Destination picker ──────────────────────────────────────────
            Text(
              'Destination',
              style: TextStyle(
                color: context.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: pickTravelCity,
              style: OutlinedButton.styleFrom(
                foregroundColor: context.textPrimary,
                side: BorderSide(color: context.borderColor),
                minimumSize: const Size.fromHeight(48),
                alignment: Alignment.centerLeft,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.location_city_rounded,
                    size: 18,
                    color: context.textMuted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      destinationLabel ?? 'Select a city',
                      style: TextStyle(
                        color: destinationLabel == null
                            ? context.textMuted
                            : context.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: context.textMuted,
                  ),
                ],
              ),
            ),

            // Region status — explicit warning if the picked destination
            // is outside the supported set, since the gate will still bite.
            const SizedBox(height: AppSpacing.sm),
            if (d.travelCity != null && !destinationSupported)
              Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 14,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'This destination is outside our supported regions. '
                      'Pick a city in TH/VN/PH to like profiles.',
                      style: TextStyle(
                        color: context.textMuted,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              )
            else
              Text(
                'Supported destinations: Thailand, Vietnam, Philippines',
                style: TextStyle(color: context.textMuted, fontSize: 11),
              ),
          ],

          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }

  String? _formatDestination(String? city, String? countryCode) {
    if (city == null || city.isEmpty) return null;
    if (countryCode != null && countryCode.isNotEmpty) {
      return '$city, $countryCode';
    }
    return city;
  }
}
