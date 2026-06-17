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

    // Add the speaker → the tile keeps its slot in the single layout render
    // object, so its element is reused rather than rebuilt.
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

    // Wide → landscape "row".
    await tester.pumpWidget(
      _harness(speaker: const ColoredBox(color: Color(0xFF112233)), width: 800),
    );
    expect(_inits, 1);

    // Narrow → stacked "column". Only constraints change, so there is no
    // rebuild at all — the layout delegate just re-positions the same tiles.
    await tester.pumpWidget(
      _harness(speaker: const ColoredBox(color: Color(0xFF112233)), width: 400),
    );
    await tester.pump();
    expect(_inits, 1, reason: 'resize re-runs layout only, never a rebuild');
  });

  // ── Geometry: the CustomMultiChildLayout positions things sensibly ──────────

  // A tile whose inner box carries the find-key, so the key isn't duplicated
  // onto the engine's LayoutId wrapper (which copies the participant's key).
  Widget tile(String k) => ColoredBox(
    color: const Color(0xFF223344),
    child: SizedBox.expand(key: ValueKey(k)),
  );

  Widget grid({
    required double width,
    required double height,
    required int count,
    required bool speaker,
  }) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: width,
          height: height,
          child: AdaptiveCallLayout(
            speaker: speaker ? tile('speaker') : null,
            participants: [for (var i = 0; i < count; i++) tile('p$i')],
          ),
        ),
      ),
    );
  }

  testWidgets('row: tiles are equal-sized and sit right of the speaker', (
    tester,
  ) async {
    await tester.pumpWidget(
      grid(width: 1000, height: 600, count: 5, speaker: true),
    );

    final firstSize = tester.getSize(find.byKey(const ValueKey('p0')));
    expect(firstSize.width, greaterThan(0));
    expect(firstSize.height, greaterThan(0));
    for (var i = 1; i < 5; i++) {
      expect(
        tester.getSize(find.byKey(ValueKey('p$i'))),
        firstSize,
        reason: 'every participant tile is the same size',
      );
    }

    final speakerRight = tester
        .getTopRight(find.byKey(const ValueKey('speaker')))
        .dx;
    for (var i = 0; i < 5; i++) {
      expect(
        tester.getTopLeft(find.byKey(ValueKey('p$i'))).dx,
        greaterThanOrEqualTo(speakerRight),
        reason: 'grid is to the right of the speaker in row mode',
      );
    }
  });

  testWidgets('column: grid sits below the speaker past the breakpoint', (
    tester,
  ) async {
    await tester.pumpWidget(
      grid(width: 420, height: 900, count: 4, speaker: true),
    );

    final speakerBottom = tester
        .getBottomLeft(find.byKey(const ValueKey('speaker')))
        .dy;
    for (var i = 0; i < 4; i++) {
      expect(
        tester.getTopLeft(find.byKey(ValueKey('p$i'))).dy,
        greaterThanOrEqualTo(speakerBottom),
        reason: 'grid is below the speaker in column mode',
      );
    }
  });
}
