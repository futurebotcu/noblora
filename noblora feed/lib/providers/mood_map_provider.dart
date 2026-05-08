import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/mock_mode.dart';
import '../data/repositories/mood_map_repository.dart';
import 'supabase_client_provider.dart';

final moodMapRepositoryProvider = Provider<MoodMapRepository>((ref) {
  if (isMockMode) return MoodMapRepository();
  return MoodMapRepository(supabase: ref.watch(supabaseClientProvider));
});
