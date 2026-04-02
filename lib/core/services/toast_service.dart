import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';
import '../../shared/widgets/swipe_toast.dart';

export '../../shared/widgets/swipe_toast.dart' show ToastType;

class ToastService {
  static OverlayEntry? _current;
  static final Queue<_ToastRequest> _queue = Queue();
  static bool _showing = false;

  static void show(
    BuildContext context, {
    required String message,
    ToastType type = ToastType.system,
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onTap,
  }) {
    _queue.add(_ToastRequest(message: message, type: type, duration: duration, onTap: onTap));
    if (!_showing) _showNext(context);
  }

  static OverlayState? _overlay;
  static double _topPadding = 0;

  static void _showNext(BuildContext? ctx) {
    if (_queue.isEmpty) {
      _showing = false;
      return;
    }
    _showing = true;
    final req = _queue.removeFirst();

    if (ctx != null) {
      _overlay = Overlay.of(ctx, rootOverlay: true);
      _topPadding = MediaQuery.of(ctx).padding.top;
    }
    if (_overlay == null) { _showing = false; return; }

    _current = OverlayEntry(
      builder: (_) => Positioned(
        top: _topPadding + 8,
        left: 0,
        right: 0,
        child: Material(
          color: Colors.transparent,
          child: SwipeToast(
            message: req.message,
            type: req.type,
            duration: req.duration,
            onTap: req.onTap,
            onDismiss: () {
              _current?.remove();
              _current = null;
              Future.delayed(const Duration(milliseconds: 150), () => _showNext(null));
            },
          ),
        ),
      ),
    );
    _overlay!.insert(_current!);
  }

  static void dismiss() {
    _current?.remove();
    _current = null;
    _showing = false;
    _queue.clear();
  }
}

class _ToastRequest {
  final String message;
  final ToastType type;
  final Duration duration;
  final VoidCallback? onTap;

  const _ToastRequest({
    required this.message,
    required this.type,
    required this.duration,
    this.onTap,
  });
}
