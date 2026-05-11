import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../core/utils/mock_mode.dart';
import '../data/repositories/ai_repository.dart';

/// All AI text operations go through Supabase Edge Function `gemini-text`.
/// No Gemini API key on the client side.
class GeminiService {
  /// Minimal client-side blocklist — defensive layer in front of Gemini's
  /// own safety filters. Catches obvious slurs/profanity that occasionally
  /// leak through. Not a moderation system; the goal is "never surface a
  /// clearly toxic suggestion to the user," not policy enforcement.
  /// Server-side moderation is the proper home for richer policy.
  static const _outputBlocklist = <String>[
    'fuck', 'fucked', 'fucking',
    'shit', 'bullshit',
    'bitch',
    'cunt',
    'asshole', 'arsehole',
    'dick',
    'pussy',
    'whore', 'slut',
    'nigger', 'faggot', 'retard',
  ];

  static bool _containsBlockedContent(String text) {
    if (text.isEmpty) return false;
    final lower = text.toLowerCase();
    for (final term in _outputBlocklist) {
      // Word-boundary check to avoid false positives like "scunthorpe".
      final pattern = RegExp('\\b${RegExp.escape(term)}\\b');
      if (pattern.hasMatch(lower)) return true;
    }
    return false;
  }

  /// Core method — sends prompt to Edge Function, returns parsed result.
  /// On any failure (network, parse, blocked content), returns `{'text': ''}`
  /// so callers fall through to their static fallback strings. We never
  /// rethrow user-facing errors here — surfacing raw "AI service error"
  /// in the UI was previously confusing and unhelpful.
  static Future<Map<String, dynamic>> analyzeText(String prompt) async {
    if (isMockMode) {
      return {'mock': true, 'text': 'Mock response'};
    }

    try {
      final data = await AIRepository.instance().invokeGeminiText(prompt);
      if (data == null) return {'text': ''};

      if (data.containsKey('error')) {
        debugPrint('[gemini] edge function returned error: ${data['error']}');
        return {'text': ''};
      }

      final text = data['text'] as String? ?? '';

      // Defensive blocklist — drop the response entirely if it leaks an
      // obvious slur. Caller will fall through to its fallback string.
      if (_containsBlockedContent(text)) {
        debugPrint('[gemini] response blocked by client-side content filter');
        return {'text': ''};
      }

      // Try to extract JSON object from response
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(text);
      if (jsonMatch != null) {
        try {
          return jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
        } catch (e) {
          debugPrint('[gemini] non-JSON AI response: $e');
          /* fall through to raw text */
        }
      }
      return {'text': text};
    } catch (e) {
      debugPrint('[gemini] AI call failed: $e');
      return {'text': ''};
    }
  }

  // ---------------------------------------------------------------------------
  // Mini Intro — 3 conversation openers
  // ---------------------------------------------------------------------------
  static Future<List<String>> generateOpeners({
    required String userName,
    required String otherName,
    required String userBio,
    required String otherBio,
    List<String> sharedInterests = const [],
  }) async {
    final interestsStr = sharedInterests.isNotEmpty
        ? 'Shared interests: ${sharedInterests.join(", ")}'
        : 'No shared interests known.';

    final prompt = '''
You are a social conversation AI for a premium dating app.

Two users just connected. Generate exactly 3 short, natural conversation openers.

User 1 ($userName): $userBio
User 2 ($otherName): $otherBio
$interestsStr

Rules:
- Each opener must be 1-2 sentences, max 100 characters
- Be warm, human, subtle — NOT scripted or cheesy
- Reference shared interests or bios if possible
- No emojis unless natural
- Return ONLY a JSON array of 3 strings

Example: ["Hey! I noticed we both love hiking.", "Your taste in art caught my eye.", "Fellow coffee addict?"]
''';

    try {
      final result = await analyzeText(prompt);
      final text = result['text'] as String? ?? '[]';
      final listMatch = RegExp(r'\[[\s\S]*\]').firstMatch(text);
      if (listMatch != null) {
        final list = jsonDecode(listMatch.group(0)!) as List<dynamic>;
        return list.map((e) => e.toString()).take(3).toList();
      }
    } catch (e) { debugPrint('[gemini] AI call failed: $e'); }

    return [
      'Hey $otherName, nice to connect!',
      'I noticed we have a lot in common.',
      'Looking forward to getting to know you.',
    ];
  }

  // ---------------------------------------------------------------------------
  // Video call topic suggestion
  // ---------------------------------------------------------------------------
  static Future<String> suggestTopic({
    required String userName,
    required String otherName,
    List<String> sharedInterests = const [],
  }) async {
    final interestsStr = sharedInterests.isNotEmpty
        ? 'Shared interests: ${sharedInterests.join(", ")}'
        : 'General conversation.';

    final prompt = '''
You are a conversation helper for a video call between two people who just met.

$userName and $otherName are on a short intro call.
$interestsStr

Generate exactly 1 light, natural conversation starter. Max 80 characters. No emojis.
Return ONLY the text, nothing else.
''';

    try {
      final result = await analyzeText(prompt);
      final text = (result['text'] as String?)?.trim() ?? '';
      if (text.isNotEmpty) return text;
    } catch (e) { debugPrint('[gemini] AI call failed: $e'); }

    return 'What do you enjoy doing on weekends?';
  }

  // ---------------------------------------------------------------------------
  // Chat nudge after 24h silence
  // ---------------------------------------------------------------------------
  static Future<String> suggestChatNudge({
    required String userName,
    required String otherName,
    String? lastMessageContent,
  }) async {
    final contextStr = lastMessageContent != null
        ? 'Last message was: "$lastMessageContent"'
        : 'The conversation has been quiet.';

    final prompt = '''
You are a conversation helper for a chat between two people.

$userName and $otherName haven't chatted in 24+ hours.
$contextStr

Generate 1 natural, gentle conversation nudge. Max 100 characters. No emojis.
Return ONLY the text, nothing else.
''';

    try {
      final result = await analyzeText(prompt);
      final text = (result['text'] as String?)?.trim() ?? '';
      if (text.isNotEmpty) return text;
    } catch (e) { debugPrint('[gemini] AI call failed: $e'); }

    return 'How has your week been?';
  }

  // R18 — `generateCommonGround` + `generateBffOpener` removed along
  // with the rest of BFF. Both methods only had callers inside BFF
  // screens / the chat _suggestBffOpener helper, all of which were
  // deleted in R18.

  // ---------------------------------------------------------------------------
  // Tier explanation
  // ---------------------------------------------------------------------------
  static Future<String> getTierExplanation({
    required String tier,
    required int profileCompleteness,
    required int communityScore,
    required int depthScore,
    required int followThrough,
  }) async {
    final prompt = '''
You are Noblara Guide — an encouraging social mentor (NOT a grade teacher).
User's current tier: $tier
Scores: Profile $profileCompleteness%, Community $communityScore%,
Depth $depthScore%, Follow-through $followThrough%.

Explain their tier in 2-3 sentences. Warm, specific, actionable.
Do NOT mention numbers or percentages. Return ONLY the text.
''';

    try {
      final result = await analyzeText(prompt);
      final text = (result['text'] as String?)?.trim() ?? '';
      if (text.isNotEmpty) return text;
    } catch (e) { debugPrint('[gemini] AI call failed: $e'); }

    return 'Keep engaging — your profile grows with every interaction.';
  }
}
