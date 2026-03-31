import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/table_card.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class TableState {
  final List<TableCard> tables;
  final bool isLoading;

  const TableState({
    this.tables = const [],
    this.isLoading = false,
  });

  TableState copyWith({List<TableCard>? tables, bool? isLoading}) {
    return TableState(
      tables: tables ?? this.tables,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class TableNotifier extends StateNotifier<TableState> {
  TableNotifier() : super(const TableState()) {
    _load();
  }

  Future<void> _load() async {
    state = state.copyWith(isLoading: true);
    state = state.copyWith(tables: [], isLoading: false);
  }

  Future<void> reload() => _load();

  /// Join a table. Returns the updated card (or null if already full).
  TableCard? join(String tableId, String userId, String userName) {
    final idx = state.tables.indexWhere((t) => t.id == tableId);
    if (idx == -1) return null;

    final table = state.tables[idx];
    if (table.isFull) return null; // can't join — already full

    // Don't re-join
    if (table.participants.any((p) => p.id == userId)) return table;

    final updated = table.copyWith(
      participants: [
        ...table.participants,
        TableParticipant(
          id: userId,
          name: userName,
          avatarSeed: userId,
          isHost: table.participants.isEmpty,
        ),
      ],
      isLive: true,
    );

    final newList = [...state.tables];
    newList[idx] = updated;
    state = state.copyWith(tables: newList);
    return updated;
  }

  /// Leave a table. Resets to open if it was full before.
  void leave(String tableId, String userId) {
    final idx = state.tables.indexWhere((t) => t.id == tableId);
    if (idx == -1) return;

    final table = state.tables[idx];
    final updated = table.copyWith(
      participants: table.participants
          .where((p) => p.id != userId)
          .toList(),
      isLive: table.participants.length > 1,
    );

    final newList = [...state.tables];
    newList[idx] = updated;
    state = state.copyWith(tables: newList);
  }

  bool hasJoined(String tableId, String userId) {
    final table = state.tables.firstWhere(
      (t) => t.id == tableId,
      orElse: () => TableCard(
        id: '',
        title: '',
        location: '',
        coverPhotoUrl: '',
        eventTag: '',
      ),
    );
    return table.participants.any((p) => p.id == userId);
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final tableProvider =
    StateNotifierProvider<TableNotifier, TableState>((ref) {
  return TableNotifier();
});
