import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/mock_mode.dart';

/// AI text Edge Function wrappers — Gemini prompt and content edit. Returns
/// raw `Map<String, dynamic>?` so callers keep their own JSON-extract /
/// fallback logic (regex parse for `gemini-text`, `edited_content` lookup
/// for `nob-ai-edit`). Mock mode short-circuits to `null` so callers fall
/// through to their existing fallback paths.
class AIRepository {
  final SupabaseClient? _supabase;

  AIRepository({SupabaseClient? supabase}) : _supabase = supabase;

  /// Lazy singleton for non-Riverpod callers (e.g. the static
  /// `GeminiService` API). Riverpod-aware code should use
  /// `aiRepositoryProvider` instead so it can be overridden in tests.
  static AIRepository? _singleton;
  static AIRepository instance() {
    if (isMockMode) return _singleton ??= AIRepository();
    return _singleton ??= AIRepository(supabase: Supabase.instance.client);
  }

  /// Invokes the `gemini-text` Edge Function with [prompt]. Returns the
  /// raw response map (typically `{text: ...}` or `{error: ...}`) or
  /// `null` if the response shape is unexpected / mock mode.
  Future<Map<String, dynamic>?> invokeGeminiText(String prompt) async {
    if (isMockMode) return null;
    final res = await _supabase!.functions.invoke(
      'gemini-text',
      body: {'prompt': prompt},
    );
    if (res.data is Map<String, dynamic>) {
      return res.data as Map<String, dynamic>;
    }
    return null;
  }

  /// Invokes the `nob-ai-edit` Edge Function for compose-screen AI rewrite.
  /// Returns the raw response map (`{edited_content: ...}`) or `null`.
  Future<Map<String, dynamic>?> invokeAIEdit({
    required String content,
    required String editType,
  }) async {
    if (isMockMode) return null;
    final res = await _supabase!.functions.invoke(
      'nob-ai-edit',
      body: {'content': content, 'edit_type': editType},
    );
    if (res.data is Map<String, dynamic>) {
      return res.data as Map<String, dynamic>;
    }
    return null;
  }
}
