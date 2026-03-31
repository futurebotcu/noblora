import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/filter_options.dart';

class FilterNotifier extends StateNotifier<FilterOptions> {
  FilterNotifier() : super(const FilterOptions());

  void update(FilterOptions Function(FilterOptions) updater) {
    state = updater(state);
  }

  void reset() => state = const FilterOptions();
}

final filterProvider =
    StateNotifierProvider<FilterNotifier, FilterOptions>((ref) {
  return FilterNotifier();
});
