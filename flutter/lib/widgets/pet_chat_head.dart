// lib/widgets/pet_head_floating.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controller/petController.dart';

/// Draggable floating pet head.
/// - Stays on top (add it as the last child in your Stack)
/// - Clamped away from status bar & bottom nav area
class PetHeadFloating extends StatefulWidget {
  const PetHeadFloating({
    super.key,
    this.bottomReserve = 88, // keep clear of bottom nav / pill
    this.size = 56,
    this.onTap,              // optional action when user taps the pet
  });

  final double bottomReserve;
  final double size;
  final VoidCallback? onTap;

  @override
  State<PetHeadFloating> createState() => _PetHeadFloatingState();
}

class _PetHeadFloatingState extends State<PetHeadFloating> {
  // Start near bottom-right by default; we finalize in build with screen size.
  Offset _pos = const Offset(0, 0);
  bool _initialized = false;

  String _imgFor(int mood) {
    if (mood >= 70) return 'assets/dance.gif';
    if (mood <= 25) return 'assets/sad.png';
    return 'assets/eat.gif';
  }

  @override
  Widget build(BuildContext context) {
    final pet = Get.find<PetController>();

    final mq = MediaQuery.of(context);
    final topPad = mq.padding.top;
    final width = mq.size.width;
    final height = mq.size.height;

    // Usable area for the top-left of the circle
    final minX = 8.0;
    final minY = topPad + 8.0;
    final maxX = width - widget.size - 8.0;
    final maxY = height - widget.size - widget.bottomReserve;

    // First build: place near bottom-right
    if (!_initialized) {
      _pos = Offset(maxX, maxY);
      _initialized = true;
    }

    // Ensure we stay clamped after rotations / resizes
    Offset _clamp(Offset p) => Offset(
          p.dx.clamp(minX, maxX).toDouble(),
          p.dy.clamp(minY, maxY).toDouble(),
        );
    _pos = _clamp(_pos);

    return Obx(() {
      final asset = _imgFor(pet.emotion.value);

      return Positioned(
        left: _pos.dx,
        top: _pos.dy,
        child: GestureDetector(
          onPanUpdate: (d) => setState(() => _pos = _clamp(_pos + d.delta)),
          onTap: widget.onTap,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [BoxShadow(blurRadius: 8, color: Colors.black26)],
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(asset, fit: BoxFit.cover),
          ),
        ),
      );
    });
  }
}
