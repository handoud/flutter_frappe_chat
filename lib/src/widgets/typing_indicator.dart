import 'package:flutter/material.dart';

class AnimatedTypingIndicator extends StatefulWidget {
  final String username;

  const AnimatedTypingIndicator({
    Key? key,
    required this.username,
  }) : super(key: key);

  @override
  _AnimatedTypingIndicatorState createState() =>
      _AnimatedTypingIndicatorState();
}

class _AnimatedTypingIndicatorState extends State<AnimatedTypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine initial
    String initial =
        widget.username.isNotEmpty ? widget.username[0].toUpperCase() : "?";

    return Row(
      children: [
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, -_animation.value),
              child: child,
            );
          },
          child: Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Colors.green, // WhatsApp-like green
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          "typing...",
          style: TextStyle(
            fontSize: 12,
            fontStyle: FontStyle.italic,
            color: Colors.grey[600],
          ),
        )
      ],
    );
  }
}
