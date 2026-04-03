import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GeminiService {
  static const _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  static String get _apiKey => dotenv.maybeGet('GEMINI_API_KEY') ?? '';

  // ---------------------------------------------------------------------------
  // Generic text prompt — returns parsed JSON or raw text
  // ---------------------------------------------------------------------------
  static Future<Map<String, dynamic>> analyzeText(String prompt) async {
    if (_apiKey.isEmpty || _apiKey == '<placeholder>') {
      return {'mock': true, 'text': 'Mock response — Gemini API key not configured'};
    }

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.2,
        'maxOutputTokens': 1024,
      }
    });

    final response = await http.post(
      Uri.parse('$_baseUrl?key=$_apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception('Gemini API error: ${response.statusCode} ${response.body}');
    }

    final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
    final text = responseJson['candidates']?[0]?['content']?['parts']?[0]?['text']
        as String? ?? '{}';

    // Try to extract JSON; if not found return raw text
    final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(text);
    if (jsonMatch != null) {
      return jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
    }
    return {'text': text};
  }

  // ---------------------------------------------------------------------------
  // AI Opener — generates 3 natural opener suggestions for Mini Intro
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

Example: ["Hey! I noticed we both love hiking.", "Your taste in art caught my eye.", "Fellow coffee addict? ☕"]
''';

    final result = await analyzeText(prompt);
    if (result.containsKey('mock')) {
      return [
        'Hey $otherName, nice to connect!',
        'I noticed we have a lot in common.',
        'Looking forward to getting to know you.',
      ];
    }

    // Try to extract JSON array from text
    final text = result['text'] as String? ?? '[]';
    try {
      final listMatch = RegExp(r'\[[\s\S]*\]').firstMatch(text);
      if (listMatch != null) {
        final list = jsonDecode(listMatch.group(0)!) as List<dynamic>;
        return list.map((e) => e.toString()).take(3).toList();
      }
    } catch (_) {}

    return [
      'Hey $otherName, nice to connect!',
      'I noticed we have a lot in common.',
      'Looking forward to getting to know you.',
    ];
  }

  // ---------------------------------------------------------------------------
  // AI Topic Suggestion — for Short Intro calls (silence >20s or user tap)
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

Generate exactly 1 light, natural conversation starter. NOT a script — just a gentle nudge.

Rules:
- Max 80 characters
- Warm and casual
- Reference shared interests if available
- No emojis
- Return ONLY the text, nothing else.
''';

    final result = await analyzeText(prompt);
    if (result.containsKey('mock')) {
      return 'What made you join Noblara?';
    }
    return (result['text'] as String?)?.trim() ?? 'What do you enjoy doing on weekends?';
  }

  // ---------------------------------------------------------------------------
  // AI Chat Unblock — nudge after 24h silence
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

Generate 1 natural, gentle conversation nudge to restart the chat.

Rules:
- Max 100 characters
- Casual, not pushy
- Could be a question or observation
- No emojis
- Return ONLY the text, nothing else.
''';

    final result = await analyzeText(prompt);
    if (result.containsKey('mock')) {
      return 'How has your week been?';
    }
    return (result['text'] as String?)?.trim() ?? 'Been thinking about our chat — how are you?';
  }

  // ---------------------------------------------------------------------------
  // BFF: Generate common ground between two users
  // ---------------------------------------------------------------------------

  static Future<List<String>> generateCommonGround({
    required String userABio,
    required String userBBio,
    List<String> userAPosts = const [],
    List<String> userBPosts = const [],
  }) async {
    final postsA = userAPosts.isNotEmpty
        ? 'User A recent posts: ${userAPosts.join(" | ")}'
        : '';
    final postsB = userBPosts.isNotEmpty
        ? 'User B recent posts: ${userBPosts.join(" | ")}'
        : '';

    final prompt = '''
You are an AI for a friendship app (NOT dating). Analyze two users and find common ground.

User A bio: $userABio
User B bio: $userBBio
$postsA
$postsB

Return exactly 2-3 short, natural phrases describing what they have in common.
- Focus on lifestyle, rhythm, personality — NOT hobbies lists
- Tone: relaxed, mature, observational
- Examples: "You both prefer quieter places", "You both seem more structured", "You both like slower routines"
- Do NOT use romantic language
- Return ONLY a JSON array of 2-3 strings

Example: ["You both prefer quieter places", "You both seem more structured"]
''';

    final result = await analyzeText(prompt);
    if (result.containsKey('mock')) {
      return [
        'You both prefer quieter places',
        'You both seem more structured',
        'You both like slower routines',
      ];
    }

    final text = result['text'] as String? ?? '[]';
    try {
      final listMatch = RegExp(r'\[[\s\S]*\]').firstMatch(text);
      if (listMatch != null) {
        final list = jsonDecode(listMatch.group(0)!) as List<dynamic>;
        return list.map((e) => e.toString()).take(3).toList();
      }
    } catch (_) {}

    return [
      'You both seem to enjoy calm environments',
      'You both value meaningful conversations',
    ];
  }

  // ---------------------------------------------------------------------------
  // BFF: Generate friendly opener suggestion
  // ---------------------------------------------------------------------------

  static Future<String> generateBffOpener({
    required String userName,
    required String otherName,
    List<String> commonGround = const [],
  }) async {
    final cgStr = commonGround.isNotEmpty
        ? 'Common ground: ${commonGround.join(", ")}'
        : '';

    final prompt = '''
You are an AI for a friendship app (NOT dating). Generate ONE friendly conversation opener.

$userName wants to start chatting with $otherName.
$cgStr

Rules:
- Warm, casual, non-romantic tone
- Reference common ground if available
- 1-2 sentences, max 120 characters
- No emojis unless natural
- Return ONLY the opener text, no JSON

Example: "Hey! I noticed we both like quiet cafes. Got any favorites?"
''';

    final result = await analyzeText(prompt);
    if (result.containsKey('mock')) {
      return 'Hey $otherName! Looks like we have some things in common. What are you into these days?';
    }

    final text = result['text'] as String? ?? '';
    return text.trim().isNotEmpty
        ? text.trim().replaceAll('"', '')
        : 'Hey $otherName! Looks like we have some things in common.';
  }

  // ---------------------------------------------------------------------------
  // Tier explanation — social guide tone
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

Explain their tier in 2-3 sentences. Tone: warm, specific, actionable.
If Explorer: mention what they're doing well + what could get them to Noble.
If Observer: be encouraging, suggest concrete next steps.
If Noble: congratulate briefly, suggest maintaining consistency.
Do NOT mention numbers or percentages. Speak naturally.
Return ONLY the explanation text.
''';

    final result = await analyzeText(prompt);
    if (result.containsKey('mock')) {
      return switch (tier) {
        'noble' => 'Noble means your profile has depth and consistency. You\'re in the top tier — keep engaging authentically.',
        'explorer' => 'Explorer means your profile has great foundations. Noble is about consistency and depth — your recent meetups and Nob activity are key.',
        _ => 'You\'re just getting started. Add a photo, write a short bio, and join an event — your profile will grow naturally.',
      };
    }

    final text = result['text'] as String? ?? '';
    return text.trim().isNotEmpty ? text.trim() : 'Keep engaging — your profile grows with every interaction.';
  }
}
