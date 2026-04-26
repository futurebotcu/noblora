import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/mock_mode.dart';
import '../data/repositories/noblara_notification_repository.dart';
import 'supabase_client_provider.dart';

final noblaraNotificationRepositoryProvider =
    Provider<NoblaraNotificationRepository>((ref) {
  if (isMockMode) return NoblaraNotificationRepository();
  return NoblaraNotificationRepository(
      supabase: ref.watch(supabaseClientProvider));
});
