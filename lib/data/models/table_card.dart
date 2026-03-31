/// A "Noble Social" dining/event table that users can join via swipe.
library;

enum TableStatus {
  open,    // slots available
  full,    // maxParticipants reached → swipe disabled, FOMO label
}

// ---------------------------------------------------------------------------
// TableParticipant
// ---------------------------------------------------------------------------

class TableParticipant {
  final String id;
  final String name;
  final String avatarSeed; // picsum.photos/seed/{seed}/80/80
  final bool isHost;

  const TableParticipant({
    required this.id,
    required this.name,
    required this.avatarSeed,
    this.isHost = false,
  });
}

// ---------------------------------------------------------------------------
// TableCard
// ---------------------------------------------------------------------------

class TableCard {
  final String id;
  final String title;
  final String location;
  final String? description;
  final String coverPhotoUrl;
  final String eventTag;         // 'Dinner' | 'Art' | 'Networking' | etc.
  final int maxParticipants;
  final List<TableParticipant> participants;
  final bool isLive;

  // Host identity & table DNA
  final String hostName;         // e.g. "Sofia K., Art Curator"
  final String? tableGoal;       // e.g. "Connecting female founders in Web3"
  final List<String> discussionTopics; // 3 headline topics for the session
  final String? minEligibility;  // e.g. "Founder Status · C1 English"

  const TableCard({
    required this.id,
    required this.title,
    required this.location,
    this.description,
    required this.coverPhotoUrl,
    required this.eventTag,
    this.maxParticipants = 4,
    this.participants = const [],
    this.isLive = false,
    this.hostName = '',
    this.tableGoal,
    this.discussionTopics = const [],
    this.minEligibility,
  });

  int get currentCount => participants.length;
  int get availableSlots => maxParticipants - currentCount;
  bool get isFull => currentCount >= maxParticipants;
  TableStatus get status => isFull ? TableStatus.full : TableStatus.open;

  TableCard copyWith({
    List<TableParticipant>? participants,
    bool? isLive,
  }) {
    return TableCard(
      id: id,
      title: title,
      location: location,
      description: description,
      coverPhotoUrl: coverPhotoUrl,
      eventTag: eventTag,
      maxParticipants: maxParticipants,
      participants: participants ?? this.participants,
      isLive: isLive ?? this.isLive,
      hostName: hostName,
      tableGoal: tableGoal,
      discussionTopics: discussionTopics,
      minEligibility: minEligibility,
    );
  }

  // ---------------------------------------------------------------------------
  // Mock data — rich host profiles + discussion DNA
  // ---------------------------------------------------------------------------

  static List<TableCard> mockTables() {
    return [
      // 2/4 live — joinable
      TableCard(
        id: 'table-1',
        title: 'Rooftop Dinner',
        location: 'SkyLounge, Nişantaşı · Istanbul',
        description:
            'An intimate dinner under the stars. Fine wine, great company.',
        coverPhotoUrl: 'https://picsum.photos/seed/rooftop1/600/800',
        eventTag: 'Dinner',
        maxParticipants: 4,
        isLive: true,
        participants: [
          TableParticipant(
              id: 'u1', name: 'Sofia', avatarSeed: 'sofia26', isHost: true),
          TableParticipant(id: 'u2', name: 'Deniz', avatarSeed: 'deniz31'),
        ],
        hostName: 'Sofia K., Art Curator',
        tableGoal: 'Create a slow, meaningful dinner for creative minds.',
        discussionTopics: [
          'Art as social commentary',
          'Living between cultures',
          'What makes a city truly liveable?',
        ],
        minEligibility: null,
      ),
      // 0/4 — fully open
      TableCard(
        id: 'table-2',
        title: 'Art Opening Night',
        location: 'Merdiven Art Space · Kadıköy',
        description:
            'Contemporary Turkish artists debut new works. Champagne provided.',
        coverPhotoUrl: 'https://picsum.photos/seed/artnight/600/800',
        eventTag: 'Art',
        maxParticipants: 4,
        isLive: false,
        participants: [],
        hostName: 'Buse T., Event Producer',
        tableGoal: 'Bridge Istanbul\'s art scene with international collectors.',
        discussionTopics: [
          'Emerging artists to watch in 2025',
          'NFTs vs physical art — which holds culture?',
          'Curating for the next generation',
        ],
        minEligibility: 'Art or design background preferred',
      ),
      // 4/4 — FULL (FOMO trigger)
      TableCard(
        id: 'table-3',
        title: 'Founders Networking',
        location: 'Soho House · Beyoğlu',
        description:
            'Founders, creatives and investors. 30-second pitches welcome.',
        coverPhotoUrl: 'https://picsum.photos/seed/network1/600/800',
        eventTag: 'Networking',
        maxParticipants: 4,
        isLive: true,
        participants: [
          TableParticipant(
              id: 'u3', name: 'Buse', avatarSeed: 'buse27', isHost: true),
          TableParticipant(id: 'u4', name: 'Melis', avatarSeed: 'melis29'),
          TableParticipant(id: 'u5', name: 'Selin', avatarSeed: 'selin25'),
          TableParticipant(id: 'u6', name: 'Irem', avatarSeed: 'irem29'),
        ],
        hostName: 'Deniz A., Venture Builder',
        tableGoal: 'Match founders with the right investors & collaborators.',
        discussionTopics: [
          'Raising a seed round in a bear market',
          'Building global teams from Istanbul',
          'The next unicorn verticals in MENA',
        ],
        minEligibility: 'Founder Status · Verified Profile',
      ),
      // 1/6 — larger table
      TableCard(
        id: 'table-4',
        title: 'Sailing Weekend',
        location: 'Kalamış Marina · Kadıköy',
        description:
            'Weekend sail to Princes Islands. Bring sunscreen and stories.',
        coverPhotoUrl: 'https://picsum.photos/seed/sailing1/600/800',
        eventTag: 'Travel',
        maxParticipants: 6,
        isLive: false,
        participants: [
          TableParticipant(
              id: 'u7', name: 'Melis', avatarSeed: 'melis29', isHost: true),
        ],
        hostName: 'Melis D., Sommelier & Sailor',
        tableGoal: 'A weekend of slow travel, good wine and genuine stories.',
        discussionTopics: [
          'Slow travel vs. productivity culture',
          'Favourite harbours around the world',
          'The art of doing nothing well',
        ],
        minEligibility: null,
      ),
      // 3/4 — one slot left
      TableCard(
        id: 'table-5',
        title: 'Wellness Morning',
        location: 'The Core Yoga · Beşiktaş',
        description:
            'Vinyasa flow followed by açai bowls and honest conversation.',
        coverPhotoUrl: 'https://picsum.photos/seed/yoga1/600/800',
        eventTag: 'Wellness',
        maxParticipants: 4,
        isLive: true,
        participants: [
          TableParticipant(
              id: 'u8', name: 'Ceren', avatarSeed: 'ceren26', isHost: true),
          TableParticipant(id: 'u9', name: 'Elif', avatarSeed: 'elif24'),
          TableParticipant(id: 'u10', name: 'Naz', avatarSeed: 'naz23'),
        ],
        hostName: 'Ceren Y., PhD Researcher & Yogi',
        tableGoal: 'Combine body intelligence with intellectual depth.',
        discussionTopics: [
          'Burnout and the attention economy',
          'Can data make us healthier or just anxious?',
          'Morning routines of high performers',
        ],
        minEligibility: null,
      ),
    ];
  }
}
