import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/mock_mode.dart';
import '../data/repositories/user_report_repository.dart';
import 'supabase_client_provider.dart';

final userReportRepositoryProvider = Provider<UserReportRepository>((ref) {
  if (isMockMode) return UserReportRepository();
  return UserReportRepository(supabase: ref.watch(supabaseClientProvider));
});
