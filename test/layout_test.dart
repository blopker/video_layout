// Verifies that participant tile state survives the structural transitions
// that used to tear the grid down: the desktop↔mobile breakpoint (Row/Column →
// Flex) and the featured-speaker toggle (Center ↔ Flex, bridged by a GlobalKey).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_layout/layout.dart';

// A probe tile that counts how many times its State is initialised. If the
// element is reused (reparented/updated), initState does NOT run again.
int _inits = 0;

class _Probe extends StatefulWidget {
  const _Probe({super.key});
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    _inits++;
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

Widget _harness({Widget? speaker, required double width}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: SizedBox(
        width: width,
        height: 600,
        child: AdaptiveCallLayout(
          speaker: speaker,
          participants: const [_Probe(key: ValueKey('a'))],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('tile state survives the speaker toggle', (tester) async {
    _inits = 0;

    // Grid only (no speaker) → content is Center(grid).
    await tester.pumpWidget(_harness(speaker: null, width: 800));
    expect(_inits, 1);

    // Add the speaker → content becomes Flex; the grid is reparented via its
    // GlobalKey rather than rebuilt.
    await tester.pumpWidget(
      _harness(speaker: const ColoredBox(color: Color(0xFF112233)), width: 800),
    );
    await tester.pump();
    expect(_inits, 1, reason: 'grid should reparent, not rebuild');

    // Remove it again.
    await tester.pumpWidget(_harness(speaker: null, width: 800));
    await tester.pump();
    expect(_inits, 1);
  });

  testWidgets('tile state survives the desktop→mobile breakpoint', (
    tester,
  ) async {
    _inits = 0;

    // Wide → landscape "row" Flex.
    await tester.pumpWidget(
      _harness(speaker: const ColoredBox(color: Color(0xFF112233)), width: 800),
    );
    expect(_inits, 1);

    // Narrow → stacked "column" Flex. Same widget type, only the axis changes.
    await tester.pumpWidget(
      _harness(speaker: const ColoredBox(color: Color(0xFF112233)), width: 400),
    );
    await tester.pump();
    expect(_inits, 1, reason: 'breakpoint should flip the Flex axis in place');
  });
}
