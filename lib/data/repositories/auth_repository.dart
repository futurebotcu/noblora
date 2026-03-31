import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/mock_mode.dart';

class MockUser {
  final String id;
  final String email;
  const MockUser({required this.id, required this.email});
}

const _mockGoldenUser = MockUser(
  id: 'mock-golden-user-001',
  email: 'golden@noblara.com',
);

class AuthRepository {
  final SupabaseClient? _supabase;

  AuthRepository({SupabaseClient? supabase}) : _supabase = supabase;

  /// Returns the mock user id when in mock mode, otherwise Supabase User.id
  Future<String?> getCurrentUserId() async {
    if (isMockMode) return _mockGoldenUser.id;
    return _supabase?.auth.currentUser?.id;
  }

  Future<String?> getCurrentUserEmail() async {
    if (isMockMode) return _mockGoldenUser.email;
    return _supabase?.auth.currentUser?.email;
  }

  Future<bool> isSignedIn() async {
    if (isMockMode) return true;
    return _supabase?.auth.currentUser != null;
  }

  Future<void> signIn({required String email, required String password}) async {
    if (isMockMode) return; // Mock: always succeeds
    await _supabase!.auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signUp({required String email, required String password}) async {
    if (isMockMode) return AuthResponse();
    return await _supabase!.auth.signUp(email: email, password: password);
  }

  /// Sets all verification flags for the current user.
  /// Only called on localhost — never in production.
  Future<void> devAutoVerify() async {
    if (isMockMode) return;
    await _supabase!.rpc('dev_auto_verify');
  }

  Future<void> signOut() async {
    if (isMockMode) return;
    await _supabase!.auth.signOut();
  }

  Stream<AuthState> get authStateChanges {
    if (isMockMode) return const Stream.empty();
    return _supabase!.auth.onAuthStateChange;
  }
}
