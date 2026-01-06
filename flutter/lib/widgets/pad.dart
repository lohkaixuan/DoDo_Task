// ==================================================
// Program Name   : pad.dart
// Purpose        : Provide reusable padding utilities to ensure consistent spacing and layout across UI components.
// Developer      : Miss. Yap Shuet Khey
// Student ID     : TP074066
// Course         : Bachelor of Software Engineering (Hons)
// Created Date   : 20 August 2025
// Last Modified  : 28 November 2025
// ==================================================

import 'package:flutter/material.dart';

/// Extra bottom space so scrollables don't collide with BottomAppBar, FAB and pet head.
EdgeInsets padAll(BuildContext context, {double h = 16, double v = 16}) {
  final bottom = MediaQuery.of(context).padding.bottom;
  const fab = kBottomNavigationBarHeight; // ~56
  const pet = 72.0;                       // pet chat head diameter
  final extra = bottom + fab + pet + 16;  // safety
  return EdgeInsets.fromLTRB(h, v, h, v + extra);
}
