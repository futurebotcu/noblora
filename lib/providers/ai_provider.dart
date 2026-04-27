import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/mock_mode.dart';
import '../data/repositories/ai_repository.dart';
import 'supabase_client_provider.dart';

final aiRepositoryProvider = Provider<AIRepository>((ref) {
  if (isMockMode) return AIRepository();
  return AIRepository(supabase: ref.watch(supabaseClientProvider));
});
