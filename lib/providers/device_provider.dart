import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/mock_mode.dart';
import '../data/repositories/device_repository.dart';
import 'supabase_client_provider.dart';

final deviceRepositoryProvider = Provider<DeviceRepository>((ref) {
  if (isMockMode) return DeviceRepository();
  return DeviceRepository(supabase: ref.watch(supabaseClientProvider));
});
