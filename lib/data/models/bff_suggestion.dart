class BffSuggestion {
  final String id;
  final String userAId;
  final String userBId;
  final List<String> commonGround;
  final String status; // pending, connected, passed, expired
  final String? userAAction;
  final String? userBAction;
  final DateTime createdAt;
  final DateTime expiresAt;

  // Populated from profile join
  final String? otherUserName;
  final String? otherUserPhotoUrl;
  final String? otherUserBio;
  final List<String> otherUserNobPosts;

  BffSuggestion({
    required this.id,
    required this.userAId,
    required this.userBId,
    required this.commonGround,
    required this.status,
    this.userAAction,
    this.userBAction,
    required this.createdAt,
    required this.expiresAt,
    this.otherUserName,
    this.otherUserPhotoUrl,
    this.otherUserBio,
    this.otherUserNobPosts = const [],
  });

  factory BffSuggestion.fromJson(Map<String, dynamic> json, {String? currentUserId}) {
    final otherProfile = json['other_profile'] as Map<String, dynamic>?;
    final posts = json['other_posts'] as List<dynamic>?;

    return BffSuggestion(
      id: json['id'] as String,
      userAId: json['user_a_id'] as String,
      userBId: json['user_b_id'] as String,
      commonGround: (json['common_ground'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      status: json['status'] as String? ?? 'pending',
      userAAction: json['user_a_action'] as String?,
      userBAction: json['user_b_action'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      otherUserName: otherProfile?['display_name'] as String?,
      otherUserPhotoUrl: otherProfile?['date_avatar_url'] as String?,
      otherUserBio: otherProfile?['bio'] as String?,
      otherUserNobPosts:
          posts?.map((p) => (p['content'] ?? '') as String).toList() ?? [],
    );
  }

  bool get isPending => status == 'pending';
  bool get isConnected => status == 'connected';
  bool get isExpired => status == 'expired';

  String? myAction(String userId) =>
      userId == userAId ? userAAction : userBAction;

  String otherUserId(String myId) => myId == userAId ? userBId : userAId;

  Duration get timeRemaining {
    final diff = expiresAt.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }
}
