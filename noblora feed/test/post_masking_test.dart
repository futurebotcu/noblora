// Phase 1 anonymity sigortası — Post.fromJson masked-row testleri.
//
// fetch_nob_lane RPC anonymous post'larda çağıran sahip değilse user_id'yi
// null'a maskeler. Client tarafının bu null'ı parse edip crashe yol açmadan
// boş counts ile sağlam render etmesi gerek. Bu testler şema değişirse
// silent break'i yakalar.

import 'package:flutter_test/flutter_test.dart';
import 'package:noblara/data/models/post.dart';

void main() {
  group('Post.fromJson masking', () {
    test('parses masked anonymous row with null user_id', () {
      final json = <String, dynamic>{
        'id': 'p1',
        'user_id': null,
        'content': 'a quiet thought',
        'nob_type': 'thought',
        'is_anonymous': true,
        'created_at': '2026-04-11T17:00:00Z',
      };

      final post = Post.fromJson(json);

      expect(post.id, 'p1');
      expect(post.userId, isNull);
      expect(post.isAnonymous, isTrue);
      expect(post.content, 'a quiet thought');
      expect(post.appreciateCount, 0);
      expect(post.supportCount, 0);
      expect(post.passCount, 0);
      expect(post.reactions, isEmpty);
      expect(post.reactionCounts, isEmpty);
    });

    test('parses non-anonymous row with real user_id and counts', () {
      final post = Post.fromJson(<String, dynamic>{
        'id': 'p2',
        'user_id': 'u1',
        'content': 'public thought',
        'nob_type': 'thought',
        'is_anonymous': false,
        'created_at': '2026-04-11T17:00:00Z',
      }).copyWith(reactionCounts: const {'appreciate': 7, 'support': 2, 'pass': 1});

      expect(post.userId, 'u1');
      expect(post.isAnonymous, isFalse);
      expect(post.appreciateCount, 7);
      expect(post.supportCount, 2);
      expect(post.passCount, 1);
    });

    test('default quality_score fallback is 0.5 when missing', () {
      final post = Post.fromJson(<String, dynamic>{
        'id': 'p3',
        'user_id': 'u1',
        'content': 'x',
        'created_at': '2026-04-11T17:00:00Z',
      });
      expect(post.qualityScore, 0.5);
    });

    test('moment row with photo_url + caption parses', () {
      final post = Post.fromJson(<String, dynamic>{
        'id': 'p4',
        'user_id': 'u1',
        'content': '',
        'nob_type': 'moment',
        'photo_url': 'https://example.com/x.jpg',
        'caption': 'sunset',
        'created_at': '2026-04-11T17:00:00Z',
      });
      expect(post.isMoment, isTrue);
      expect(post.photoUrl, 'https://example.com/x.jpg');
      expect(post.caption, 'sunset');
    });

    test('myReaction returns null when reactions empty', () {
      final post = Post.fromJson(<String, dynamic>{
        'id': 'p5',
        'user_id': 'u1',
        'content': 'x',
        'created_at': '2026-04-11T17:00:00Z',
      });
      expect(post.myReaction('u1'), isNull);
    });
  });
}
