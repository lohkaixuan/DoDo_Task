// lib/widgets/pad.dart
import 'package:flutter/material.dart';

/// Extra bottom space so scrollables don't collide with BottomAppBar, FAB and pet head.
EdgeInsets padAll(BuildContext context, {double h = 16, double v = 16}) {
  final bottom = MediaQuery.of(context).padding.bottom;
  const fab = kBottomNavigationBarHeight; // ~56
  const pet = 72.0;                       // pet chat head diameter
  final extra = bottom + fab + pet + 16;  // safety
  return EdgeInsets.fromLTRB(h, v, h, v + extra);
}
