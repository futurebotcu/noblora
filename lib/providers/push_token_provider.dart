import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/mock_mode.dart';
import '../data/repositories/push_token_repository.dart';
import 'supabase_client_provider.dart';

final pushTokenRepositoryProvider = Provider<PushTokenRepository>((ref) {
  if (isMockMode) return PushTokenRepository();
  return PushTokenRepository(supabase: ref.watch(supabaseClientProvider));
});
