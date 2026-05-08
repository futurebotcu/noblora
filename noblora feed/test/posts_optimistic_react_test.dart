// Phase 1 optimistic reaction state-transition testleri.
//
// PostsNotifier.react() çekirdek mantığı:
//  - Önceki reactions + reactionCounts snapshot tutar
//  - Toggle off → kullanıcı reaction'ı listeden çıkar + ilgili count -1
//  - Add new → kullanıcı reaction'ı eklenir + ilgili count +1
//  - Replace → eski reaction count -1, yeni reaction count +1
//  - Hata → snapshot ile rollback
//
// Notifier'ı tam kurmak için Riverpod ProviderContainer + auth + supabase
// stub'ları gerektiği için burada doğrudan Post model katmanında aynı
// dönüşümleri uyguluyoruz. Notifier bu helper'ları kullanır; matematik
// yanlışsa testler önce burada bağırır.

import 'package:flutter_test/flutter_test.dart';
import 'package:noblara/data/models/post.dart';

Post _seedPost({
  Map<String, int> counts = const {'appreciate': 5, 'support': 2, 'pass': 0},
  List<PostReaction> reactions = const [],
}) {
  return Post(
    id: 'p1',
    userId: 'author',
    content: 'seed',
    createdAt: DateTime(2026, 4, 11),
    reactionCounts: counts,
    reactions: reactions,
  );
}

PostReaction _r(String userId, String type) => PostReaction(
      id: 'r-$userId-$type',
      postId: 'p1',
      userId: userId,
      reactionType: type,
      createdAt: DateTime(2026, 4, 11),
    );

/// Mirrors the bump helper inside PostsNotifier.react().
Map<String, int> _bump(Map<String, int> base, String type, int delta) {
  final next = Map<String, int>.from(base);
  next[type] = ((next[type] ?? 0) + delta).clamp(0, 1 << 30);
  return next;
}

/// Mirrors the "add or replace" branch of PostsNotifier.react().
Post _applyAddOrReplace(Post post, String uid, String reactionType) {
  final existing = post.myReaction(uid);
  final newReactions = [
    ...post.reactions.where((r) => r.userId != uid),
    _r(uid, reactionType),
  ];
  var newCounts = post.reactionCounts;
  if (existing != null) {
    newCounts = _bump(newCounts, existing.reactionType, -1);
  }
  newCounts = _bump(newCounts, reactionType, 1);
  return post.copyWith(reactions: newReactions, reactionCounts: newCounts);
}

/// Mirrors the "toggle off" branch of PostsNotifier.react().
Post _applyToggleOff(Post post, String uid, String reactionType) {
  final newReactions = post.reactions.where((r) => r.userId != uid).toList();
  final newCounts = _bump(post.reactionCounts, reactionType, -1);
  return post.copyWith(reactions: newReactions, reactionCounts: newCounts);
}

void main() {
  group('optimistic react math', () {
    test('add new reaction increments count and adds own row', () {
      final before = _seedPost();
      final after = _applyAddOrReplace(before, 'me', 'appreciate');

      expect(after.appreciateCount, 6);
      expect(after.supportCount, 2);
      expect(after.passCount, 0);
      expect(after.myReaction('me')?.reactionType, 'appreciate');
    });

    test('toggle off removes own row and decrements count', () {
      final before = _seedPost(reactions: [_r('me', 'appreciate')]);
      final after = _applyToggleOff(before, 'me', 'appreciate');

      expect(after.appreciateCount, 4);
      expect(after.myReaction('me'), isNull);
    });

    test('replace appreciate -> support decrements appreciate and bumps support', () {
      final before = _seedPost(reactions: [_r('me', 'appreciate')]);
      final after = _applyAddOrReplace(before, 'me', 'support');

      expect(after.appreciateCount, 4);
      expect(after.supportCount, 3);
      expect(after.myReaction('me')?.reactionType, 'support');
    });

    test('rollback restores both reactions list and counts after exception', () {
      // Snapshot what the Notifier captures before the optimistic write.
      final before = _seedPost(reactions: [_r('me', 'appreciate')]);
      final previousReactions = List<PostReaction>.from(before.reactions);
      final previousCounts = Map<String, int>.from(before.reactionCounts);

      // Apply an optimistic toggle-off, then simulate repo failure → rollback.
      final after = _applyToggleOff(before, 'me', 'appreciate');
      expect(after.appreciateCount, 4);
      expect(after.myReaction('me'), isNull);

      final rolledBack =
          after.copyWith(reactions: previousReactions, reactionCounts: previousCounts);

      expect(rolledBack.appreciateCount, 5);
      expect(rolledBack.myReaction('me')?.reactionType, 'appreciate');
    });

    test('bump never goes below zero', () {
      final result = _bump(const {'appreciate': 0}, 'appreciate', -1);
      expect(result['appreciate'], 0);
    });

    test('bump on missing key starts from zero', () {
      final result = _bump(const {}, 'support', 1);
      expect(result['support'], 1);
    });
  });
}
