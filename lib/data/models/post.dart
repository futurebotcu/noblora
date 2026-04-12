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

  // Second Thought / revision tracking
  final int editCount;
  final bool hasSecondThought;
  final DateTime? lastEditedAt;
  final String? secondThoughtReason;
  final String? originalContent;
  final String? originalCaption;

  // Future Nob
  final bool isFutureNob;
  final DateTime? revisitAt;
  final String? futureNobStatus; // 'waiting' | 'reminded' | 'revisited'

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
    this.editCount = 0,
    this.hasSecondThought = false,
    this.lastEditedAt,
    this.secondThoughtReason,
    this.originalContent,
    this.originalCaption,
    this.isFutureNob = false,
    this.revisitAt,
    this.futureNobStatus,
  });

  bool get isThought => nobType == 'thought';
  bool get isMoment => nobType == 'moment';
  bool get isEdited => editCount > 0;
  bool get canMinorEdit =>
      publishedAt != null &&
      DateTime.now().difference(publishedAt!).inMinutes <= 30 &&
      editCount < 3;
  bool get canSecondThought => !hasSecondThought;
  bool get isFutureNobDue =>
      isFutureNob && revisitAt != null && DateTime.now().isAfter(revisitAt!);

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
      editCount: (json['edit_count'] as num?)?.toInt() ?? 0,
      hasSecondThought: json['has_second_thought'] as bool? ?? false,
      lastEditedAt: json['last_edited_at'] != null
          ? DateTime.parse(json['last_edited_at'] as String)
          : null,
      secondThoughtReason: json['second_thought_reason'] as String?,
      originalContent: json['original_content'] as String?,
      originalCaption: json['original_caption'] as String?,
      isFutureNob: json['is_future_nob'] as bool? ?? false,
      revisitAt: json['revisit_at'] != null
          ? DateTime.parse(json['revisit_at'] as String)
          : null,
      futureNobStatus: json['future_nob_status'] as String?,
    );
  }

  Post copyWith({
    String? content,
    String? caption,
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
    int? editCount,
    bool? hasSecondThought,
    DateTime? lastEditedAt,
    String? secondThoughtReason,
    String? originalContent,
    String? originalCaption,
    bool? isFutureNob,
    DateTime? revisitAt,
    String? futureNobStatus,
  }) {
    return Post(
      id: id,
      userId: userId,
      content: content ?? this.content,
      nobType: nobType,
      photoUrl: photoUrl,
      caption: caption ?? this.caption,
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
      editCount: editCount ?? this.editCount,
      hasSecondThought: hasSecondThought ?? this.hasSecondThought,
      lastEditedAt: lastEditedAt ?? this.lastEditedAt,
      secondThoughtReason: secondThoughtReason ?? this.secondThoughtReason,
      originalContent: originalContent ?? this.originalContent,
      originalCaption: originalCaption ?? this.originalCaption,
      isFutureNob: isFutureNob ?? this.isFutureNob,
      revisitAt: revisitAt ?? this.revisitAt,
      futureNobStatus: futureNobStatus ?? this.futureNobStatus,
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
