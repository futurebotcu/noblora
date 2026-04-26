import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/utils/mock_mode.dart';

/// All AI text operations go through Supabase Edge Function `gemini-text`.
/// No Gemini API key on the client side.
class GeminiService {
  /// Core method — sends prompt to Edge Function, returns parsed result.
  static Future<Map<String, dynamic>> analyzeText(String prompt) async {
    if (isMockMode) {
      return {'mock': true, 'text': 'Mock response'};
    }

    try {
      final res = await Supabase.instance.client.functions.invoke(
        'gemini-text',
        body: {'prompt': prompt},
      );

      final data = res.data as Map<String, dynamic>?;
      if (data == null) return {'text': ''};

      if (data.containsKey('error')) {
        throw Exception(data['error']);
      }

      final text = data['text'] as String? ?? '';

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
      throw Exception('AI service error: $e');
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

  // ---------------------------------------------------------------------------
  // BFF common ground
  // ---------------------------------------------------------------------------
  static Future<List<String>> generateCommonGround({
    required String userABio,
    required String userBBio,
    List<String> userAPosts = const [],
    List<String> userBPosts = const [],
  }) async {
    final postsA = userAPosts.isNotEmpty ? 'User A recent posts: ${userAPosts.join(" | ")}' : '';
    final postsB = userBPosts.isNotEmpty ? 'User B recent posts: ${userBPosts.join(" | ")}' : '';

    final prompt = '''
You are an AI for a friendship app (NOT dating). Analyze two users and find common ground.

User A bio: $userABio
User B bio: $userBBio
$postsA
$postsB

Return exactly 2-3 short phrases. Focus on lifestyle, not hobbies lists.
Return ONLY a JSON array of 2-3 strings.
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

    return ['You two might have more in common than you think'];
  }

  // ---------------------------------------------------------------------------
  // BFF friendly opener
  // ---------------------------------------------------------------------------
  static Future<String> generateBffOpener({
    required String userName,
    required String otherName,
    List<String> commonGround = const [],
  }) async {
    final cgStr = commonGround.isNotEmpty ? 'Common ground: ${commonGround.join(", ")}' : '';

    final prompt = '''
You are an AI for a friendship app (NOT dating). Generate ONE friendly conversation opener.

$userName wants to start chatting with $otherName.
$cgStr

Rules: Warm, casual, non-romantic. 1-2 sentences, max 120 characters. No JSON.
''';

    try {
      final result = await analyzeText(prompt);
      final text = (result['text'] as String?)?.trim() ?? '';
      if (text.isNotEmpty) return text.replaceAll('"', '');
    } catch (e) { debugPrint('[gemini] AI call failed: $e'); }

    return 'Hey $otherName! Looks like we have some things in common.';
  }

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
