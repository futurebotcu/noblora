import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/mock_mode.dart';
import '../data/repositories/storage_repository.dart';
import 'supabase_client_provider.dart';

final storageRepositoryProvider = Provider<StorageRepository>((ref) {
  if (isMockMode) return StorageRepository();
  return StorageRepository(supabase: ref.watch(supabaseClientProvider));
});
