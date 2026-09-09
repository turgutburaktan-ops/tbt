import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'chat_surface.dart';

/// Physical right swipe on either sender's bubble; never dismisses the message.
class SwipeToReply extends StatefulWidget {
  const SwipeToReply({super.key, required this.child, required this.onReply, this.enabled = true});
  final Widget child;
  final VoidCallback onReply;
  final bool enabled;
  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply> {
  double _distance = 0;
  bool _dragging = false;
  static const _threshold = 56.0;

  void _reset() => setState(() { _distance = 0; _dragging = false; });

  @override
  void didUpdateWidget(covariant SwipeToReply oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) { _distance = 0; _dragging = false; }
  }

  @override
  Widget build(BuildContext context) => Semantics(
    customSemanticsActions: widget.enabled ? {
      const CustomSemanticsAction(label: 'Mesajı yanıtla'): widget.onReply,
    } : null,
    child: GestureDetector(
      onHorizontalDragStart: widget.enabled ? (_) => setState(() => _dragging = true) : null,
      onHorizontalDragUpdate: widget.enabled ? (details) {
        setState(() => _distance = (_distance + details.delta.dx).clamp(0.0, 80.0).toDouble());
      } : null,
      onHorizontalDragEnd: widget.enabled ? (_) {
        final reply = _distance >= _threshold;
        _reset();
        if (reply) { HapticFeedback.selectionClick(); widget.onReply(); }
      } : null,
      onHorizontalDragCancel: widget.enabled ? _reset : null,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Positioned(left: 12, child: ExcludeSemantics(child: Opacity(
            opacity: (_distance / _threshold).clamp(0.0, 1.0).toDouble(),
            child: Icon(Icons.reply_rounded, color: _distance >= _threshold ? ChatSurface.accent : Colors.white54),
          ))),
          AnimatedContainer(
            duration: _dragging || MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(_distance, 0, 0),
            child: widget.child,
          ),
        ],
      ),
    ),
  );
}
