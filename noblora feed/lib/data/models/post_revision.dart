class PostRevision {
  final String id;
  final String postId;
  final String userId;
  final String revisionType; // 'minor_edit' | 'second_thought'
  final String previousContent;
  final String? previousCaption;
  final String newContent;
  final String? newCaption;
  final String? reason;
  final int revisionNumber;
  final DateTime createdAt;

  const PostRevision({
    required this.id,
    required this.postId,
    required this.userId,
    required this.revisionType,
    required this.previousContent,
    this.previousCaption,
    required this.newContent,
    this.newCaption,
    this.reason,
    required this.revisionNumber,
    required this.createdAt,
  });

  bool get isSecondThought => revisionType == 'second_thought';
  bool get isMinorEdit => revisionType == 'minor_edit';

  factory PostRevision.fromJson(Map<String, dynamic> json) {
    return PostRevision(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      userId: json['user_id'] as String,
      revisionType: json['revision_type'] as String,
      previousContent: json['previous_content'] as String,
      previousCaption: json['previous_caption'] as String?,
      newContent: json['new_content'] as String,
      newCaption: json['new_caption'] as String?,
      reason: json['reason'] as String?,
      revisionNumber: (json['revision_number'] as num).toInt(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
