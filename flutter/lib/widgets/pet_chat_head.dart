import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../screens/pet_chat_screen.dart';

class PetChatHead extends StatefulWidget {
  const PetChatHead({super.key});
  @override
  State<PetChatHead> createState() => _PetChatHeadState();
}

class _PetChatHeadState extends State<PetChatHead> {
  // bubble size
  final double size = 56;

  // starting position
  Offset pos = const Offset(16, 420);

  void _onDrag(DragUpdateDetails d) {
    final mq = MediaQuery.of(context);
    final screen = mq.size;
    final insets = mq.padding;

    // new tentative position
    final next = pos + d.delta;

    // clamp inside safe area
    final minX = 8.0;
    final maxX = screen.width - size - 8.0;
    final minY = insets.top + 8.0;
    final maxY = screen.height - size - insets.bottom - 8.0;

    setState(() {
      pos = Offset(
        next.dx.clamp(minX, maxX),
        next.dy.clamp(minY, maxY),
      );
    });
  }

  void _snapToEdge(DragEndDetails d) {
    // snap left/right for a nicer feel
    final screenW = MediaQuery.of(context).size.width;
    final targetX = (pos.dx + size / 2 < screenW / 2) ? 8.0 : screenW - size - 8.0;
    setState(() => pos = Offset(targetX, pos.dy));
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: pos.dx,
      top: pos.dy,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: _onDrag,
        onPanEnd: _snapToEdge,
        onTap: () => Get.to(() => const PetChatScreen()),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black26)],
          ),
          // ⬇️ real scaling: just pad the image inside the circle
          child: Padding(
            padding: const EdgeInsets.all(10), // increase to make the icon smaller
            child: Image.asset(
              'assets/logo.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
