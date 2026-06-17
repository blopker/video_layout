// Smoke tests for the Adaptive Call Layout prototype.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:video_layout/main.dart';

void main() {
  testWidgets('prototype boots and shows the speaker tile', (tester) async {
    await tester.pumpWidget(const PrototypeApp());

    expect(find.text('Active Speaker'), findsOneWidget);
    // Default state shows 4 participants in the grid.
    expect(find.text('Adaptive Call Layout'), findsOneWidget);
  });

  testWidgets('participants slider drives the grid', (tester) async {
    await tester.pumpWidget(const PrototypeApp());

    // Dragging the participants slider down to 0 should remove named tiles
    // but keep the featured speaker.
    final slider = find.byType(Slider).first;
    await tester.drag(slider, const Offset(-1000, 0));
    await tester.pumpAndSettle();

    expect(find.text('Active Speaker'), findsOneWidget);
  });
}
