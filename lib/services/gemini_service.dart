import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GeminiVerificationResult {
  final bool isApproved;
  final String decision;  // 'approved' | 'rejected'
  final String reason;
  final double? realSelfieProbability;
  final String? genderDetected;
  final Map<String, dynamic> raw;

  const GeminiVerificationResult({
    required this.isApproved,
    required this.decision,
    required this.reason,
    this.realSelfieProbability,
    this.genderDetected,
    required this.raw,
  });
}

class GeminiService {
  static const _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  static String get _apiKey => dotenv.maybeGet('GEMINI_API_KEY') ?? '';

  // ---------------------------------------------------------------------------
  // Selfie verification
  // Determines: real selfie? real human? gender? AI generated?
  // ---------------------------------------------------------------------------
  static Future<GeminiVerificationResult> verifySelfie({
    required Uint8List imageBytes,
    required String profileGender,
  }) async {
    const prompt = '''
You are an identity verification AI for a premium social app.

Analyze this selfie image and respond ONLY with a valid JSON object.

Evaluate:
1. Is this a real phone selfie taken by a real human?
2. Is the person real (not AI-generated, not a mannequin, not an illustration)?
3. What is the apparent gender of the person?
4. Does the image appear to be a screenshot, stock photo, or celebrity photo?

Respond ONLY with this exact JSON structure:
{
  "real_selfie_probability": 0.00,
  "is_real_human": true,
  "gender_detected": "female",
  "is_ai_generated": false,
  "is_stock_or_celebrity": false,
  "decision": "approved",
  "reason": "Natural phone selfie of a real person"
}

decision must be "approved" or "rejected".
Reject if: AI generated face, stock photo, celebrity, screenshot, cartoon, or not a selfie.
''';

    return _callGemini(
      imageBytes: imageBytes,
      prompt: prompt,
      isSelfie: true,
      profileGender: profileGender,
    );
  }

  // ---------------------------------------------------------------------------
  // Profile photo verification
  // Detects: fake, AI, celebrity, stock, screenshot
  // ---------------------------------------------------------------------------
  static Future<GeminiVerificationResult> verifyProfilePhoto({
    required Uint8List imageBytes,
  }) async {
    const prompt = '''
You are a photo authenticity AI for a premium social app.

Analyze this profile photo and respond ONLY with a valid JSON object.

Check for:
1. AI-generated faces (uncanny valley, perfect symmetry, unusual backgrounds)
2. Celebrity photos (famous people)
3. Stock photos (watermarks, professional lighting for commercial use)
4. Screenshots from social media or websites
5. Cartoon or illustrated images

Respond ONLY with this exact JSON structure:
{
  "is_real_photo": true,
  "is_ai_generated": false,
  "is_celebrity": false,
  "is_stock_photo": false,
  "is_screenshot": false,
  "confidence": 0.95,
  "decision": "approved",
  "reason": "Authentic personal photograph"
}

decision must be "approved" or "rejected".
Reject if: AI generated, celebrity, stock photo, screenshot, cartoon, or unclear face.
''';

    return _callGemini(
      imageBytes: imageBytes,
      prompt: prompt,
      isSelfie: false,
    );
  }

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
  // Internal: call Gemini API
  // ---------------------------------------------------------------------------
  static Future<GeminiVerificationResult> _callGemini({
    required Uint8List imageBytes,
    required String prompt,
    bool isSelfie = false,
    String? profileGender,
  }) async {
    if (_apiKey.isEmpty || _apiKey == '<placeholder>') {
      // Mock mode fallback
      return GeminiVerificationResult(
        isApproved: true,
        decision: 'approved',
        reason: 'Mock verification — Gemini API key not configured',
        realSelfieProbability: 0.95,
        genderDetected: profileGender,
        raw: {'mock': true},
      );
    }

    final base64Image = base64Encode(imageBytes);

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {
              'inline_data': {
                'mime_type': 'image/jpeg',
                'data': base64Image,
              }
            },
            {'text': prompt},
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.1,
        'maxOutputTokens': 512,
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

    // Extract JSON from response (Gemini may wrap it in markdown)
    final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(text);
    if (jsonMatch == null) {
      throw Exception('Gemini returned non-JSON response: $text');
    }

    final parsed = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;

    final decision = parsed['decision'] as String? ?? 'rejected';
    final isApproved = decision == 'approved';

    return GeminiVerificationResult(
      isApproved: isApproved,
      decision: decision,
      reason: parsed['reason'] as String? ?? '',
      realSelfieProbability: isSelfie
          ? (parsed['real_selfie_probability'] as num?)?.toDouble()
          : null,
      genderDetected: isSelfie ? parsed['gender_detected'] as String? : null,
      raw: parsed,
    );
  }
}
