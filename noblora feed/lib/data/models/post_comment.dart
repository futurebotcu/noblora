class PostComment {
  final String id;
  final String postId;
  final String userId;
  final String content;
  final DateTime createdAt;
  final String? parentId;
  final String chainType; // 'reply' (default) | 'chain' — Soul Chain continuation

  // Edit tracking
  final bool isEdited;
  final int editCount;
  final String? originalContent;
  final DateTime? lastEditedAt;

  // Joined fields
  final String? authorName;
  final String? authorAvatarUrl;

  // Client-side: child replies
  final List<PostComment> replies;

  const PostComment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.parentId,
    this.chainType = 'reply',
    this.isEdited = false,
    this.editCount = 0,
    this.originalContent,
    this.lastEditedAt,
    this.authorName,
    this.authorAvatarUrl,
    this.replies = const [],
  });

  bool get isReply => parentId != null;
  bool get isChain => chainType == 'chain';
  bool get canEdit =>
      DateTime.now().difference(createdAt).inMinutes <= 15 && editCount < 3;

  factory PostComment.fromJson(Map<String, dynamic> json, {Map<String, dynamic>? profile}) {
    return PostComment(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      userId: json['user_id'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      parentId: json['parent_id'] as String?,
      chainType: (json['chain_type'] as String?) ?? 'reply',
      isEdited: json['is_edited'] as bool? ?? false,
      editCount: (json['edit_count'] as num?)?.toInt() ?? 0,
      originalContent: json['original_content'] as String?,
      lastEditedAt: json['last_edited_at'] != null
          ? DateTime.parse(json['last_edited_at'] as String)
          : null,
      authorName: profile?['display_name'] as String? ?? json['author_name'] as String?,
      authorAvatarUrl: profile?['date_avatar_url'] as String? ?? json['author_avatar_url'] as String?,
    );
  }
}
