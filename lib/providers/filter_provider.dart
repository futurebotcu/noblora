import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/filter_state.dart';

class FilterNotifier extends StateNotifier<FilterState> {
  FilterNotifier() : super(const FilterState());

  void set(FilterState newState) => state = newState;

  void update(FilterState Function(FilterState) updater) {
    state = updater(state);
  }

  void reset() => state = const FilterState();
}

final filterProvider =
    StateNotifierProvider<FilterNotifier, FilterState>((ref) {
  return FilterNotifier();
});
