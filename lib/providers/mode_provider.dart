import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/enums/noble_mode.dart';

class ModeNotifier extends StateNotifier<NobleMode> {
  ModeNotifier() : super(NobleMode.date);

  void setMode(NobleMode mode) => state = mode;
}

final modeProvider = StateNotifierProvider<ModeNotifier, NobleMode>((ref) {
  return ModeNotifier();
});
