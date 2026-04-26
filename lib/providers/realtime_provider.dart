import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/mock_mode.dart';
import '../data/repositories/realtime_repository.dart';
import 'supabase_client_provider.dart';

final realtimeRepositoryProvider = Provider<RealtimeRepository>((ref) {
  if (isMockMode) return RealtimeRepository();
  return RealtimeRepository(supabase: ref.watch(supabaseClientProvider));
});
