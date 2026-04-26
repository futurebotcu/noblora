import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/mock_mode.dart';
import '../data/repositories/admin_repository.dart';
import 'supabase_client_provider.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  if (isMockMode) return AdminRepository();
  return AdminRepository(supabase: ref.watch(supabaseClientProvider));
});
