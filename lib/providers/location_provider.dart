import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/mock_mode.dart';
import '../data/repositories/location_repository.dart';
import 'supabase_client_provider.dart';

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  if (isMockMode) return LocationRepository();
  return LocationRepository(supabase: ref.watch(supabaseClientProvider));
});
