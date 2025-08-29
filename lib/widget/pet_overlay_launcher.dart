import 'package:flutter/material.dart';
import '../screen/pet.dart';

class PetOverlayLauncher extends StatelessWidget {
  const PetOverlayLauncher({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.pets),
      tooltip: 'Open Pet',
      onPressed: () {
        // Navigator.of(context).push(
        //   MaterialPageRoute(builder: (_) => const PetScreen()),
        // );
      },
    );
  }
}
