import 'package:flutter/material.dart';

import '../models/chat_theme.dart';

/// An animated "… is typing" bubble.
class AnimatedTypingIndicator extends StatefulWidget {
  /// Display name of the person typing.
  final String username;

  /// Colours for the bubble. Defaults to [FrappeChatTheme].
  final FrappeChatTheme theme;

  const AnimatedTypingIndicator({
    super.key,
    required this.username,
    this.theme = const FrappeChatTheme(),
  });

  @override
  State<AnimatedTypingIndicator> createState() =>
      _AnimatedTypingIndicatorState();
}

class _AnimatedTypingIndicatorState extends State<AnimatedTypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;

    return Semantics(
      liveRegion: true,
      label: '${widget.username} is typing',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: theme.incomingBubble,
          borderRadius: BorderRadius.circular(theme.bubbleRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.username,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.senderNameColor,
              ),
            ),
            const SizedBox(width: 8),
            for (var i = 0; i < 3; i++) _Dot(_controller, i, theme.metaColor),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final AnimationController controller;
  final int index;
  final Color color;

  const _Dot(this.controller, this.index, this.color);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        // Stagger each dot by a third of the cycle.
        final phase = (controller.value + index / 3) % 1.0;
        final lift = (phase < 0.5 ? phase : 1 - phase) * 8;
        return Padding(
          padding: EdgeInsets.only(right: 3, bottom: lift),
          child: child,
        );
      },
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
