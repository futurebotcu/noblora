import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_tokens.dart';

class CitySearchScreen extends StatefulWidget {
  final String? initialValue;
  final void Function(String city, String country, double? lat, double? lng) onSelected;

  const CitySearchScreen({super.key, this.initialValue, required this.onSelected});

  @override
  State<CitySearchScreen> createState() => _CitySearchScreenState();
}

class _CitySearchScreenState extends State<CitySearchScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  List<_PlacePrediction> _results = [];
  bool _loading = false;

  static const _apiKey = 'AIzaSyBjqBeQBOz-EiL1Y_RQ3MzjrkQIi0YOJgQ';

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null) _ctrl.text = widget.initialValue!;
    _focus.requestFocus();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query.trim()));
  }

  Future<void> _search(String query) async {
    setState(() => _loading = true);
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=${Uri.encodeComponent(query)}'
        '&types=(cities)'
        '&key=$_apiKey',
      );
      final resp = await http.get(url);
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final predictions = (data['predictions'] as List?) ?? [];
        setState(() {
          _results = predictions.map((p) => _PlacePrediction(
            placeId: p['place_id'] ?? '',
            description: p['description'] ?? '',
            mainText: p['structured_formatting']?['main_text'] ?? '',
            secondaryText: p['structured_formatting']?['secondary_text'] ?? '',
          )).toList();
        });
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _selectPlace(_PlacePrediction prediction) async {
    // Get place details for coordinates
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=${prediction.placeId}'
        '&fields=geometry,address_components'
        '&key=$_apiKey',
      );
      final resp = await http.get(url);
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final result = data['result'];
        final loc = result?['geometry']?['location'];
        final lat = loc?['lat'] as double?;
        final lng = loc?['lng'] as double?;

        // Extract country from address_components
        String country = '';
        final components = result?['address_components'] as List? ?? [];
        for (final c in components) {
          final types = (c['types'] as List?) ?? [];
          if (types.contains('country')) {
            country = c['long_name'] ?? '';
            break;
          }
        }

        if (mounted) {
          widget.onSelected(prediction.mainText, country, lat, lng);
          Navigator.pop(context);
        }
        return;
      }
    } catch (_) {}

    // Fallback without coordinates
    if (mounted) {
      widget.onSelected(prediction.mainText, prediction.secondaryText, null, null);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Search City', style: TextStyle(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          // Search field
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.sm, AppSpacing.xxl, AppSpacing.md),
            child: TextField(
              controller: _ctrl,
              focusNode: _focus,
              onChanged: _onSearchChanged,
              style: TextStyle(color: context.textPrimary, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Type a city name...',
                prefixIcon: Icon(Icons.search_rounded, color: context.textMuted, size: 20),
                suffixIcon: _ctrl.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close_rounded, color: context.textMuted, size: 18),
                        onPressed: () { _ctrl.clear(); setState(() => _results = []); },
                      )
                    : null,
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.gold.withValues(alpha: 0.5)),
                ),
              ),
            ),
          ),

          if (_loading)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
            ),

          // Results
          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, i) {
                final r = _results[i];
                return ListTile(
                  leading: Icon(Icons.location_on_outlined, color: context.textMuted, size: 20),
                  title: Text(r.mainText, style: TextStyle(color: context.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                  subtitle: r.secondaryText.isNotEmpty
                      ? Text(r.secondaryText, style: TextStyle(color: context.textMuted, fontSize: 12))
                      : null,
                  onTap: () => _selectPlace(r),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PlacePrediction {
  final String placeId, description, mainText, secondaryText;
  const _PlacePrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });
}
