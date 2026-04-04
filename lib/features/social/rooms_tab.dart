import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_tokens.dart';
import '../../providers/room_provider.dart';
import '../../providers/interaction_gate_provider.dart';
import 'room_card_widget.dart';
import 'room_chat_screen.dart';
import 'create_room_screen.dart';

const _violet = AppColors.violet;

class RoomsTab extends ConsumerStatefulWidget {
  const RoomsTab({super.key});

  @override
  ConsumerState<RoomsTab> createState() => _RoomsTabState();
}

class _RoomsTabState extends ConsumerState<RoomsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(roomListProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(roomListProvider);

    return Stack(
      children: [
        if (state.isLoading && state.rooms.isEmpty)
          const Center(child: CircularProgressIndicator(color: _violet))
        else if (state.rooms.isEmpty)
          _EmptyRooms()
        else
          RefreshIndicator(
            color: _violet,
            onRefresh: () => ref.read(roomListProvider.notifier).load(),
            child: ListView.builder(
              padding: const EdgeInsets.only(
                top: AppSpacing.md,
                bottom: AppSpacing.xxxxl + 60,
              ),
              itemCount: state.rooms.length,
              itemBuilder: (context, i) {
                final room = state.rooms[i];
                return RoomCardWidget(
                  room: room,
                  onTap: () => _openRoom(room.id, room.hostId, room.title),
                  onJoin: room.isFull
                      ? null
                      : () => _joinRoom(room.id, room.hostId, room.title),
                );
              },
            ),
          ),
        // FAB
        Positioned(
          right: AppSpacing.lg,
          bottom: AppSpacing.xxl,
          child: FloatingActionButton(
            heroTag: 'create_room_fab',
            backgroundColor: _violet,
            onPressed: _createRoom,
            child: const Icon(Icons.add_rounded, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Future<void> _joinRoom(String roomId, String hostId, String title) async {
    final gate = ref.read(interactionGateProvider).valueOrNull ??
        InteractionGate.loading;
    if (!gate.canSocialJoin) {
      if (mounted) showGatingPopup(context, 'Add a photo first', 'Upload a photo to join events and rooms.');
      return;
    }
    final result = await ref.read(roomListProvider.notifier).joinRoom(roomId);
    if (!mounted) return;
    if (result == 'joined') {
      _openRoom(roomId, hostId, title);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result),
          backgroundColor: context.surfaceColor,
        ),
      );
    }
  }

  void _openRoom(String roomId, String hostId, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoomChatScreen(
          roomId: roomId,
          hostId: hostId,
          roomTitle: title,
        ),
      ),
    );
  }

  Future<void> _createRoom() async {
    final gate = ref.read(interactionGateProvider).valueOrNull ??
        InteractionGate.loading;
    if (!gate.canSocialCreate) {
      if (mounted) {
        showGatingPopup(context, 'Verify your photo',
            'Verify your profile photo to host events and create rooms.',
            type: GatePopupType.verifyPhoto);
      }
      return;
    }
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreateRoomScreen()),
    );
    if (created == true) ref.read(roomListProvider.notifier).load();
  }
}

class _EmptyRooms extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _violet.withValues(alpha: 0.04),
                border: Border.all(color: _violet.withValues(alpha: 0.1)),
              ),
              child: Icon(
                Icons.forum_outlined,
                color: _violet.withValues(alpha: 0.4),
                size: 28,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text(
              'No rooms yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: context.textPrimary,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Start a topic room and chat with\npeople nearby.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.textMuted,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
