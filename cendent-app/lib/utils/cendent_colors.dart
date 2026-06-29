import 'package:flutter/material.dart';

class CendentColors {
  CendentColors._();

  static const Color bg = Color(0xFFEEF2F7);
  static const Color primary = Color(0xFF1565C0);
  static const Color primaryMid = Color(0xFF1976D2);
  static const Color primaryDeep = Color(0xFF0D47A1);
  static const Color blueLight = Color(0xFF90CAF9);
  static const Color blueTint = Color(0xFFE3F0FC);
  static const Color blueWash = Color(0xFFF4F8FD);

  static const Color card = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF0D1B2A);
  static const Color secondary = Color(0xFF78909C);
  static const Color steel = Color(0xFF546170);
  static const Color muted = Color(0xFFA7B4C0);

  static const Color hairline = Color(0xFFE3E9F0);
  static const Color hairlineSoft = Color(0xFFEEF2F6);

  static const Color green = Color(0xFF2E9E6B);
  static const Color greenSoft = Color(0xFFE4F4EC);
  static const Color amber = Color(0xFFC77700);
  static const Color amberSoft = Color(0xFFFBEFD9);
  static const Color amberRow = Color(0xFFFBEFCD);
  static const Color red = Color(0xFFD5453B);
  static const Color redSoft = Color(0xFFFBE6E4);
  static const Color violet = Color(0xFF7A4FB0);
  static const Color violetSoft = Color(0xFFF0EAF7);
  static const Color teal = Color(0xFF0E8A86);
  static const Color tealSoft = Color(0xFFDEF3F1);

  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x1A1565C0),
      blurRadius: 20,
      spreadRadius: -6,
      offset: Offset(0, 4),
    ),
    BoxShadow(color: Color(0x0A0D1B2A), blurRadius: 2, offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> popShadow = [
    BoxShadow(
      color: Color(0x470D1B2A),
      blurRadius: 50,
      spreadRadius: -12,
      offset: Offset(-8, 0),
    ),
  ];
}
