import '../../core/enums/noble_mode.dart';

enum ConversationType { alliance, circle, request }

class InboxItem {
  final String id;
  final String name;
  final String avatarSeed;
  final String? photoUrl;
  final String lastMessage;
  final Duration ago;
  final NobleMode mode;
  final ConversationType type;
  final bool isUnread;

  // Alliance (1-on-1 chat) fields
  final String? profession;
  final String? expertise;
  final String? connectionGoal;

  // Circle (group chat) fields
  final String? tableId;
  final String? tableTitle;
  final int? participantCount;
  final int? maxParticipants;

  const InboxItem({
    required this.id,
    required this.name,
    required this.avatarSeed,
    this.photoUrl,
    required this.lastMessage,
    required this.ago,
    required this.mode,
    required this.type,
    this.isUnread = false,
    this.profession,
    this.expertise,
    this.connectionGoal,
    this.tableId,
    this.tableTitle,
    this.participantCount,
    this.maxParticipants,
  });

  String get timeLabel {
    if (ago.inMinutes < 60) return '${ago.inMinutes}m';
    if (ago.inHours < 24) return '${ago.inHours}h';
    return '${ago.inDays}d';
  }

}
