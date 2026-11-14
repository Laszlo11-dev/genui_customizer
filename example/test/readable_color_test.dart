import 'package:a2ui_tech_reader/readable_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('repairs low contrast colors and preserves readable colors', () {
    expect(readableColor(Colors.white, Colors.white), Colors.black);
    expect(readableColor(Colors.black, Colors.black), Colors.white);
    expect(
      readableColor(Colors.blue.shade900, Colors.white),
      Colors.blue.shade900,
    );
    expect(readableColor(const Color(0x11000000), Colors.white), Colors.black);
  });
}
