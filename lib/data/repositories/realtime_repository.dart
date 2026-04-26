import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/mock_mode.dart';

/// Single point for tearing down realtime subscriptions. Subscribe paths
/// remain on the domain repositories (MatchRepository, PostRepository, …)
/// because each subscription has domain-specific filters and callbacks;
/// this repository centralises the otherwise repetitive `removeChannel`
/// dispose dance shared by every notifier/widget.
class RealtimeRepository {
  final SupabaseClient? _supabase;

  RealtimeRepository({SupabaseClient? supabase}) : _supabase = supabase;

  /// Tear down a previously-subscribed channel. No-op when [channel] is
  /// null (mock mode or never-subscribed) or when the supabase client is
  /// not configured.
  void unsubscribe(RealtimeChannel? channel) {
    if (isMockMode || channel == null) return;
    final client = _supabase;
    if (client == null) return;
    client.removeChannel(channel);
  }
}
