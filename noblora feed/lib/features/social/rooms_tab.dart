import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/premium.dart';
import '../../providers/room_provider.dart';
import '../../providers/interaction_gate_provider.dart';
import 'room_card_widget.dart';
import 'room_chat_screen.dart';
import 'create_room_screen.dart';

const _accent = AppColors.emerald700;

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
          const Center(child: CircularProgressIndicator(color: _accent))
        else if (state.rooms.isEmpty)
          _EmptyRooms()
        else
          RefreshIndicator(
            color: _accent,
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
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: Premium.emeraldGlow(intensity: 0.8),
            ),
            child: FloatingActionButton(
              heroTag: 'create_room_fab',
              backgroundColor: AppColors.emerald600,
              onPressed: _createRoom,
              child: const Icon(Icons.add_rounded, color: Colors.white),
            ),
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
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
          decoration: Premium.emptyStateDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [_accent.withValues(alpha: 0.10), _accent.withValues(alpha: 0.03)],
                  ),
                  border: Border.all(color: _accent.withValues(alpha: 0.12), width: 0.5),
                ),
                child: Icon(Icons.forum_outlined, color: _accent.withValues(alpha: 0.45), size: 26),
              ),
              const SizedBox(height: 24),
              Text(
                'No rooms yet',
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Start a topic room and chat with\npeople nearby',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.textMuted,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
