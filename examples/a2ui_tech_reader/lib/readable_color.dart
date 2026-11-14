import 'package:flutter/material.dart';

/// Keeps text and controls legible when AI or Touch supplies arbitrary colors.
Color readableColor(Color preferred, Color background) {
  final surface = Color.alphaBlend(background, Colors.white);
  final visible = Color.alphaBlend(preferred, surface);
  if (_contrast(visible, surface) >= 4.5) return preferred;
  const black = Colors.black;
  const white = Colors.white;
  return _contrast(black, surface) >= _contrast(white, surface) ? black : white;
}

double _contrast(Color a, Color b) {
  final light = a.computeLuminance() + 0.05;
  final dark = b.computeLuminance() + 0.05;
  return light >= dark ? light / dark : dark / light;
}
