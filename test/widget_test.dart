// Smoke tests for the Adaptive Call Layout prototype.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:video_layout/main.dart';

void main() {
  testWidgets('prototype boots featuring someone other than you', (
    tester,
  ) async {
    await tester.pumpWidget(const PrototypeApp());

    // Queue starts [1,2,0,3,4]; id 1 ("Linus") is the active speaker.
    expect(find.text('Linus'), findsOneWidget);
    // Not presenting, so the local user appears as a normal grid tile.
    expect(find.text('You'), findsOneWidget);
    expect(find.text('Adaptive Call Layout'), findsOneWidget);
  });

  testWidgets('rotating yourself to the front drops your self-view', (
    tester,
  ) async {
    await tester.pumpWidget(const PrototypeApp());
    expect(find.text('You'), findsOneWidget); // a grid tile while watching

    // The rotate button lives in the panel's scrollable; bring it into view.
    final rotate = find.byIcon(Icons.rotate_left);
    await tester.scrollUntilVisible(
      rotate,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(rotate);
    await tester.pumpAndSettle();

    // Rotate twice: [1,2,0,3,4] → [2,0,3,4,1] → [0,3,4,1,2]; now you present.
    await tester.tap(rotate);
    await tester.pumpAndSettle();
    await tester.tap(rotate);
    await tester.pumpAndSettle();

    expect(find.text('You'), findsNothing); // presenting → no self-view
  });

  testWidgets('people slider down to just you shows an empty call', (
    tester,
  ) async {
    await tester.pumpWidget(const PrototypeApp());

    // Dragging the people slider to its minimum leaves only the local user,
    // who has no self-view — so no tiles render at all.
    final slider = find.byType(Slider).first;
    await tester.drag(slider, const Offset(-1000, 0));
    await tester.pumpAndSettle();

    expect(find.text('Linus'), findsNothing);
    expect(find.text('You'), findsNothing);
  });
}
