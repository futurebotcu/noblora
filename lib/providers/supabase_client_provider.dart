import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Single point of access for the Supabase client across the app.
/// Override in tests via ProviderScope to inject a mock client; in
/// production it returns the global `Supabase.instance.client`.
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);
