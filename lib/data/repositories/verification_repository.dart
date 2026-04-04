import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/mock_mode.dart';
import '../models/photo_verification.dart';

// ---------------------------------------------------------------------------
// Decision engine — private to this file
// ---------------------------------------------------------------------------

enum _Decision { approved, manualReview, rejected }

/// Fraud signal strings that Gemini might return that indicate definitive fraud.
bool _isStrongFraud(List<String> signals) {
  const keywords = {
    'ai_generated', 'ai generated', 'deepfake', 'deep fake',
    'stolen', 'celebrity', 'fake', 'generated', 'fraud', 'impersonation',
  };
  return signals.any(
    (s) => keywords.any((kw) => s.toLowerCase().contains(kw)),
  );
}

_Decision _computeDecision({
  required bool samePerson,
  required double? realSelfieProbability,
  required double? confidence,
  required String? genderDetected,
  required List<String> fraudSignals,
}) {
  final prob = realSelfieProbability ?? 0.0;

  // ── Hard reject conditions (evaluated first) ──────────────────────────────
  if (_isStrongFraud(fraudSignals)) return _Decision.rejected;
  if (!samePerson) return _Decision.rejected;
  if (prob < 0.4) return _Decision.rejected;

  // ── Approved — all conditions must be satisfied ───────────────────────────
  final hasWeakFraud = fraudSignals.isNotEmpty;       // strong fraud already caught above
  final isConfidenceLow = (confidence ?? 1.0) < 0.5;
  final isGenderUnknown = genderDetected == 'unknown';

  if (samePerson &&
      prob >= 0.7 &&
      !hasWeakFraud &&
      !isConfidenceLow &&
      !isGenderUnknown) {
    return _Decision.approved;
  }

  // ── Everything else is ambiguous → manual review ──────────────────────────
  return _Decision.manualReview;
}

String _buildReason(
  _Decision decision, {
  required bool samePerson,
  required double? realSelfieProbability,
  required double? confidence,
  required String? genderDetected,
  required List<String> fraudSignals,
}) {
  switch (decision) {
    case _Decision.approved:
      return 'Identity verified successfully';

    case _Decision.rejected:
      if (_isStrongFraud(fraudSignals)) {
        final critical = fraudSignals
            .where((s) => const {
                  'ai_generated', 'ai generated', 'deepfake', 'deep fake',
                  'stolen', 'celebrity', 'fake', 'generated', 'fraud',
                  'impersonation',
                }.any((kw) => s.toLowerCase().contains(kw)))
            .join(', ');
        return 'Fraudulent content detected: $critical';
      }
      if (!samePerson) {
        return 'Selfie and profile photo do not appear to be the same person';
      }
      return 'Selfie authenticity score too low '
          '(${((realSelfieProbability ?? 0) * 100).toStringAsFixed(0)}%)';

    case _Decision.manualReview:
      if (fraudSignals.isNotEmpty) {
        return 'Inconclusive signals flagged — manual review required';
      }
      if ((confidence ?? 1.0) < 0.5) {
        return 'Verification confidence is low — our team will review your photos';
      }
      if (genderDetected == 'unknown') {
        return 'Could not determine gender — manual review required';
      }
      final prob = realSelfieProbability ?? 0.0;
      if (prob >= 0.4 && prob < 0.7) {
        return 'Selfie probability in uncertain range — manual review required';
      }
      return 'AI confidence ambiguous — pending manual review';
  }
}

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class VerificationRepository {
  final SupabaseClient? _supabase;

  VerificationRepository({SupabaseClient? supabase}) : _supabase = supabase;

  /// Upload both photos and verify via Supabase Edge Function → Gemini.
  /// Returns two PhotoVerification records: one for selfie, one for profile.
  /// Decision is one of: approved | manual_review | rejected.
  Future<List<PhotoVerification>> verifyBothPhotos({
    required String userId,
    required Uint8List selfieBytes,
    required Uint8List profileBytes,
    required String profileGender,
  }) async {
    if (isMockMode) {
      return [
        PhotoVerification(
          id: 'mock-selfie-1',
          userId: userId,
          photoUrl: 'https://picsum.photos/seed/$userId/400/400',
          photoType: 'selfie',
          status: 'approved',
          decision: 'approved',
          aiReason: 'Mock verification passed',
          realSelfieProbability: 0.95,
          genderDetected: profileGender,
          createdAt: DateTime.now(),
        ),
        PhotoVerification(
          id: 'mock-profile-1',
          userId: userId,
          photoUrl: 'https://picsum.photos/seed/${userId}p/400/400',
          photoType: 'profile',
          status: 'approved',
          decision: 'approved',
          aiReason: 'Mock verification passed',
          createdAt: DateTime.now(),
        ),
      ];
    }

    final client = _supabase;
    if (client == null) throw Exception('Supabase client not initialized');

    // Upload both images to storage
    final ts = DateTime.now().millisecondsSinceEpoch;
    final selfieFileName = '$userId/selfie_$ts.jpg';
    final profileFileName = '$userId/profile_$ts.jpg';

    await client.storage.from('verification-photos').uploadBinary(
          selfieFileName,
          selfieBytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
    await client.storage.from('profile-photos').uploadBinary(
          profileFileName,
          profileBytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );

    final selfieUrl =
        client.storage.from('verification-photos').getPublicUrl(selfieFileName);
    final profileUrl =
        client.storage.from('profile-photos').getPublicUrl(profileFileName);

    // ── Call Edge Function ────────────────────────────────────────────────────
    _Decision decision;
    String reason;
    Map<String, dynamic> geminiParsed = {};
    double? realSelfieProbability;
    String? genderDetected;

    try {
      // Encode on isolate to avoid blocking UI
      final selfieB64 = await compute(base64Encode, selfieBytes);
      final profileB64 = await compute(base64Encode, profileBytes);

      final res = await client.functions.invoke(
        'verify-images',
        body: {
          'selfie': selfieB64,
          'profile': profileB64,
        },
      );

      final responseData = res.data as Map<String, dynamic>;

      if (responseData.containsKey('error')) {
        throw Exception(responseData['error']);
      }

      // Gemini wraps output: candidates → content → parts[0].text
      final rawText =
          responseData['candidates']?[0]?['content']?['parts']?[0]?['text']
                  as String? ??
              '';

      // Strip optional markdown fences and extract JSON object
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(rawText);
      if (jsonMatch == null) {
        throw FormatException('Gemini returned no JSON: $rawText');
      }
      geminiParsed =
          jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;

      final samePerson = geminiParsed['same_person'] as bool? ?? false;
      realSelfieProbability =
          (geminiParsed['real_selfie_probability'] as num?)?.toDouble();
      final confidence =
          (geminiParsed['confidence'] as num?)?.toDouble();
      genderDetected = geminiParsed['gender_detected'] as String?;
      final fraudSignals =
          (geminiParsed['fraud_signals'] as List?)?.cast<String>() ?? [];

      decision = _computeDecision(
        samePerson: samePerson,
        realSelfieProbability: realSelfieProbability,
        confidence: confidence,
        genderDetected: genderDetected,
        fraudSignals: fraudSignals,
      );

      reason = _buildReason(
        decision,
        samePerson: samePerson,
        realSelfieProbability: realSelfieProbability,
        confidence: confidence,
        genderDetected: genderDetected,
        fraudSignals: fraudSignals,
      );
    } catch (e) {
      // Edge function error or unparseable response → manual review
      decision = _Decision.manualReview;
      reason = 'AI verification unavailable — pending manual review';
      geminiParsed = {'error': e.toString()};
      realSelfieProbability = null;
      genderDetected = null;
    }

    final dbStatus = switch (decision) {
      _Decision.approved => 'approved',
      _Decision.rejected => 'rejected',
      _Decision.manualReview => 'manual_review',
    };

    final isApproved = decision == _Decision.approved;
    final isRejected = decision == _Decision.rejected;

    // ── Persist both records ──────────────────────────────────────────────────
    final selfieData = await client.from('photo_verifications').insert({
      'user_id': userId,
      'photo_url': selfieUrl,
      'photo_type': 'selfie',
      'status': dbStatus,
      'claimed_gender': profileGender,   // user's declaration at submission time
      'gemini_response': geminiParsed,
      'rejection_reason': isRejected ? reason : null,
      'real_selfie_probability': realSelfieProbability,
      'gender_detected': genderDetected, // AI-detected gender
      'decision': dbStatus,
      'ai_reason': reason,
    }).select().single();

    final profileData = await client.from('photo_verifications').insert({
      'user_id': userId,
      'photo_url': profileUrl,
      'photo_type': 'profile',
      'status': dbStatus,
      'claimed_gender': profileGender,
      'gemini_response': geminiParsed,
      'rejection_reason': isRejected ? reason : null,
      'decision': dbStatus,
      'ai_reason': reason,
    }).select().single();

    // ── Update profile flags on approval ─────────────────────────────────────
    // is_verified is set automatically by the DB trigger when both flags are true.
    // profileUrl is the publicly visible photo — added to the photos gallery array.
    // selfieUrl stays in the private verification bucket and is NOT added to photos.
    if (isApproved) {
      await Future.wait([
        client
            .from('profiles')
            .update({
              'selfie_verified': true,
              'photos_verified': true,
              'photos': [profileUrl],
            })
            .eq('id', userId),
        client
            .from('gating_status')
            .update({
              'is_verified': true,
              'is_entry_approved': true,
            })
            .eq('user_id', userId),
      ]);
    }

    return [
      PhotoVerification.fromJson(selfieData),
      PhotoVerification.fromJson(profileData),
    ];
  }

  Future<List<PhotoVerification>> fetchVerifications(String userId) async {
    if (isMockMode) return [];
    final client = _supabase;
    if (client == null) throw Exception('Supabase client not initialized');
    final data = await client
        .from('photo_verifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return data.map((e) => PhotoVerification.fromJson(e)).toList();
  }

  /// Live stream — emits whenever a row is inserted or updated for this user.
  /// Requires photo_verifications to be in supabase_realtime publication.
  Stream<List<PhotoVerification>> watchVerifications(String userId) {
    if (isMockMode) return const Stream.empty();
    return _supabase!
        .from('photo_verifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map(PhotoVerification.fromJson).toList());
  }
}
