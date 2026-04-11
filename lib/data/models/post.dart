enum NobTier {
  observer,
  explorer,
  noble;

  String get label {
    switch (this) {
      case NobTier.observer: return 'Observer';
      case NobTier.explorer: return 'Explorer';
      case NobTier.noble: return 'Noble';
    }
  }

  static NobTier fromString(String? s) {
    switch (s) {
      case 'explorer': return NobTier.explorer;
      case 'noble': return NobTier.noble;
      default: return NobTier.observer;
    }
  }
}

class Post {
  final String id;
  /// May be null for anonymous posts when fetched as a non-owner.
  /// Server-side masking by `fetch_nob_lane` strips it.
  final String? userId;
  final String content;    // thought text, or empty for moments
  final String nobType;    // 'thought' | 'moment'
  final String? photoUrl;
  final String? caption;
  final double qualityScore;
  final bool isPinned;
  final bool isArchived;
  final bool isDraft;
  final DateTime? publishedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Populated by join
  final String? authorName;
  final String? authorAvatarUrl;
  final String? tone; // reflective, grounded, curious, creative
  final NobTier authorTier;
  /// Reactions visible to the current user. Under tightened RLS this list
  /// only contains the current user's own reactions to this post (so
  /// `myReaction(uid)` still works), plus any optimistic local entries.
  /// Use [reactionCounts] for displayed totals.
  final List<PostReaction> reactions;
  /// Aggregated public reaction counts keyed by reaction_type
  /// ('appreciate' | 'support' | 'pass'). Server-aggregated, no identity.
  final Map<String, int> reactionCounts;
  final Map<String, int> ownCounts; // author-only reaction counts
  final int commentCount;
  final int echoCount;
  final bool hasEchoed;
  final bool isAnonymous;

  const Post({
    required this.id,
    required this.userId,
    required this.content,
    this.nobType = 'thought',
    this.photoUrl,
    this.caption,
    this.qualityScore = 0.5,
    this.isPinned = false,
    this.isArchived = false,
    this.isDraft = false,
    this.publishedAt,
    required this.createdAt,
    this.updatedAt,
    this.authorName,
    this.authorAvatarUrl,
    this.tone,
    this.authorTier = NobTier.observer,
    this.reactions = const [],
    this.reactionCounts = const {},
    this.ownCounts = const {},
    this.commentCount = 0,
    this.echoCount = 0,
    this.hasEchoed = false,
    this.isAnonymous = false,
  });

  bool get isThought => nobType == 'thought';
  bool get isMoment => nobType == 'moment';

  factory Post.fromJson(Map<String, dynamic> json,
      {Map<String, dynamic>? profile}) {
    return Post(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      content: json['content'] as String? ?? '',
      nobType: json['nob_type'] as String? ?? 'thought',
      photoUrl: json['photo_url'] as String?,
      caption: json['caption'] as String?,
      qualityScore: (json['quality_score'] as num?)?.toDouble() ?? 0.5,
      isPinned: json['is_pinned'] as bool? ?? false,
      isArchived: json['is_archived'] as bool? ?? false,
      isDraft: json['is_draft'] as bool? ?? false,
      publishedAt: json['published_at'] != null
          ? DateTime.parse(json['published_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      authorName: profile?['display_name'] as String? ??
          json['author_name'] as String?,
      authorAvatarUrl: profile?['date_avatar_url'] as String? ??
          json['author_avatar_url'] as String?,
      tone: json['tone'] as String?,
      authorTier: NobTier.fromString(profile?['nob_tier'] as String?),
      isAnonymous: json['is_anonymous'] as bool? ?? false,
    );
  }

  Post copyWith({
    List<PostReaction>? reactions,
    Map<String, int>? reactionCounts,
    bool? isPinned,
    Map<String, int>? ownCounts,
    int? commentCount,
    int? echoCount,
    bool? hasEchoed,
    bool? isAnonymous,
    String? authorName,
    String? authorAvatarUrl,
    NobTier? authorTier,
  }) {
    return Post(
      id: id,
      userId: userId,
      content: content,
      nobType: nobType,
      photoUrl: photoUrl,
      caption: caption,
      qualityScore: qualityScore,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived,
      isDraft: isDraft,
      publishedAt: publishedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
      authorName: authorName ?? this.authorName,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      tone: tone,
      authorTier: authorTier ?? this.authorTier,
      reactions: reactions ?? this.reactions,
      reactionCounts: reactionCounts ?? this.reactionCounts,
      ownCounts: ownCounts ?? this.ownCounts,
      commentCount: commentCount ?? this.commentCount,
      echoCount: echoCount ?? this.echoCount,
      hasEchoed: hasEchoed ?? this.hasEchoed,
      isAnonymous: isAnonymous ?? this.isAnonymous,
    );
  }

  /// Total of [reactionCounts['appreciate']] (the displayed appreciate count).
  int get appreciateCount => reactionCounts['appreciate'] ?? 0;
  int get supportCount => reactionCounts['support'] ?? 0;
  int get passCount => reactionCounts['pass'] ?? 0;

  PostReaction? myReaction(String uid) {
    try {
      return reactions.firstWhere((r) => r.userId == uid);
    } catch (_) {
      return null;
    }
  }
}

class PostReaction {
  final String id;
  final String postId;
  final String userId;
  final String reactionType; // 'appreciate' | 'support' | 'pass'
  final DateTime createdAt;

  const PostReaction({
    required this.id,
    required this.postId,
    required this.userId,
    required this.reactionType,
    required this.createdAt,
  });

  factory PostReaction.fromJson(Map<String, dynamic> json) {
    return PostReaction(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      userId: json['user_id'] as String,
      reactionType: json['reaction_type'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
