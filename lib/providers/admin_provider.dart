import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/mock_mode.dart';
import '../data/repositories/admin_repository.dart';
import 'auth_provider.dart';
import 'profile_provider.dart';
import 'supabase_client_provider.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  if (isMockMode) return AdminRepository();
  return AdminRepository(supabase: ref.watch(supabaseClientProvider));
});

// Whether current user is an admin — autoDispose so it refreshes on user switch.
final isAdminProvider = FutureProvider.autoDispose<bool>((ref) async {
  if (isMockMode) return true;
  final userId = ref.watch(authProvider).userId;
  if (userId == null) return false;
  final isAdmin =
      await ref.read(profileRepositoryProvider).fetchIsAdmin(userId);
  return isAdmin ?? false;
});
