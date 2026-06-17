import 'dart:math' as math;
import 'package:flutter/widgets.dart';

/// Adaptive turn-taking call layout — **layout engine only**.
///
/// Arranges an optional featured *speaker* tile plus a grid of *participant*
/// tiles, keeping every tile at a fixed aspect ratio (4:5 by default) and
/// re-fitting the grid to the available space and the number of tiles.
///
/// Behaviour mirrors the web prototype:
///   • Wide (>= [mobileBreakpoint]) → "row": speaker on the left takes the
///     lion's share of the width, participants in a grid on the right.
///   • Narrow (< [mobileBreakpoint]) → "column": speaker pinned to the top,
///     full-bleed (no padding), participants on a strip below.
///   • Single breakpoint: orientation and padding flip together.
///   • [speaker] == null → no featured tile (e.g. the local user is the one
///     speaking and has no self-view); the participant grid fills the area.
///
/// You only supply the video widgets — drop any [Widget] into [speaker] and
/// [participants] (a texture, platform view, image, decorated box, etc.).
///
class AdaptiveCallLayout extends StatefulWidget {
  const AdaptiveCallLayout({
    super.key,
    required this.participants,
    this.speaker,
    this.spacing = 10,
    this.tileAspectRatio = 4 / 5, // width / height
    this.mobileBreakpoint = 540,
    this.desktopPadding = 16,
    this.mobilePadding = 0,
    this.speakerMaxWidthFraction = 0.62,
    this.portraitMinStripFraction = 0.20,
    this.portraitMinStrip = 70,
    this.portraitMaxStrip = 150,
  });

  /// The active speaker, rendered large. Pass `null` for no featured tile.
  final Widget? speaker;

  /// Everyone else — laid out as equal, fixed-ratio tiles in an adaptive grid.
  final List<Widget> participants;

  /// Gap between tiles (and between speaker and grid), in logical pixels.
  final double spacing;

  /// Tile aspect ratio as width / height. 4:5 portrait => 0.8.
  final double tileAspectRatio;

  /// Below this width the layout switches to the stacked "mobile" form.
  final double mobileBreakpoint;

  /// Outer padding on desktop / mobile respectively (mobile is full-bleed).
  final double desktopPadding;
  final double mobilePadding;

  /// In the landscape "row" form, the speaker may grow up to this fraction of
  /// the width before listeners start claiming space.
  final double speakerMaxWidthFraction;

  /// In the stacked "column" form, how much height to reserve for the
  /// participant strip beneath the speaker.
  final double portraitMinStripFraction;
  final double portraitMinStrip;
  final double portraitMaxStrip;

  @override
  State<AdaptiveCallLayout> createState() => _AdaptiveCallLayoutState();
}

class _AdaptiveCallLayoutState extends State<AdaptiveCallLayout> {
  // Stable across rebuilds. Anchoring the grid to a GlobalKey lets it survive
  // structural swaps — desktop↔mobile orientation and speaker on↔off — by
  // being *reparented* rather than torn down and rebuilt, so each tile's state
  // (and its bound video stream) is preserved through those transitions.
  final GlobalKey _gridKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final participants = widget.participants;
    final spacing = widget.spacing;
    final speaker = widget.speaker;

    return LayoutBuilder(
      builder: (context, constraints) {
        final spec = _solve(
          width: constraints.maxWidth.isFinite ? constraints.maxWidth : 0,
          height: constraints.maxHeight.isFinite ? constraints.maxHeight : 0,
        );

        // Build the participant grid: a centered Wrap of fixed-size tiles whose
        // width is pinned so exactly `cols` fit per row.
        Widget? grid;
        if (participants.isNotEmpty && spec.tileW > 0 && spec.tileH > 0) {
          grid = KeyedSubtree(
            key: _gridKey,
            child: SizedBox(
              width: spec.gridContentWidth,
              child: Wrap(
                spacing: spacing,
                runSpacing: spacing,
                alignment: WrapAlignment.center,
                runAlignment: WrapAlignment.center,
                children: [
                  for (final p in participants)
                    // Propagate the caller's key past the SizedBox wrapper so a
                    // reordered participant list reuses element/state correctly
                    // (otherwise tiles are matched by index and state leaks).
                    KeyedSubtree(
                      key: p.key,
                      child: SizedBox(
                        width: spec.tileW,
                        height: spec.tileH,
                        child: p,
                      ),
                    ),
                ],
              ),
            ),
          );
        }

        Widget? featured;
        if (speaker != null && spec.speakerW > 0 && spec.speakerH > 0) {
          featured = SizedBox(
            width: spec.speakerW,
            height: spec.speakerH,
            child: speaker,
          );
        }

        late final Widget content;
        if (featured == null) {
          // No speaker tile (e.g. you are speaking): just the centred grid.
          content = Center(child: grid ?? const SizedBox.shrink());
        } else if (grid == null) {
          // Speaker only.
          content = Center(child: featured);
        } else {
          // Speaker + grid. Use Flex (not Row/Column) so the widget type stays
          // constant across the breakpoint — only the axis changes, so the
          // element updates in place instead of being rebuilt.
          content = Flex(
            direction: spec.isRow ? Axis.horizontal : Axis.vertical,
            mainAxisAlignment: spec.isRow
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              featured,
              SizedBox(
                width: spec.isRow ? spacing : 0,
                height: spec.isRow ? 0 : spacing,
              ),
              Flexible(child: grid),
            ],
          );
        }

        return Padding(padding: EdgeInsets.all(spec.padding), child: content);
      },
    );
  }

  /// Pure layout solver — no side effects, depends only on the incoming size.
  _LayoutSpec _solve({required double width, required double height}) {
    final speaker = widget.speaker;
    final participants = widget.participants;
    final spacing = widget.spacing;
    final speakerMaxWidthFraction = widget.speakerMaxWidthFraction;
    final portraitMinStrip = widget.portraitMinStrip;
    final portraitMinStripFraction = widget.portraitMinStripFraction;
    final portraitMaxStrip = widget.portraitMaxStrip;

    final w = math.max(60.0, width);
    final h = math.max(60.0, height);
    final aspect = widget.tileAspectRatio; // width / height

    final mobile = w < widget.mobileBreakpoint;
    final pad = mobile ? widget.mobilePadding : widget.desktopPadding;
    final iw = math.max(40.0, w - 2 * pad); // usable content width
    final ih = math.max(40.0, h - 2 * pad); // usable content height
    final isRow = !mobile;

    final hasFeatured = speaker != null;
    final m = participants.length;

    double fw = 0, fh = 0, gridW = iw, gridH = ih;

    if (hasFeatured) {
      if (m == 0) {
        // Speaker fills the whole area.
        fh = math.min(ih, iw / aspect);
        fw = fh * aspect;
        if (fw > iw) {
          fw = iw;
          fh = math.min(ih, fw / aspect);
        }
        gridW = 0;
        gridH = 0;
      } else if (isRow) {
        // Landscape: speaker takes the lion's share of the width.
        fh = ih;
        fw = fh * aspect;
        final maxFw = iw * speakerMaxWidthFraction;
        if (fw > maxFw) {
          fw = maxFw;
          fh = math.min(ih, fw / aspect);
          fw = fh * aspect;
        }
        gridW = iw - fw - spacing;
        gridH = ih;
      } else {
        // Portrait: full-width speaker on top, listeners on a strip below.
        final minStrip = math.max(
          portraitMinStrip,
          math.min(ih * portraitMinStripFraction, portraitMaxStrip),
        );
        fw = iw;
        fh = fw / aspect;
        if (fh > ih - minStrip) {
          fh = ih - minStrip;
          fw = fh * aspect;
        }
        if (fw > iw) {
          fw = iw;
          fh = fw / aspect;
        }
        gridW = iw;
        gridH = math.max(0, ih - fh - spacing);
      }
    }

    final g = m > 0
        ? _bestGrid(m, gridW, gridH, spacing, aspect)
        : const _Grid(0, 0, 0, 0);

    final tileW = g.tileW.floorToDouble();
    final tileH = g.tileH.floorToDouble();
    final gridContentWidth = g.cols > 0
        ? g.cols * tileW + (g.cols - 1) * spacing
        : 0.0;

    return _LayoutSpec(
      isRow: isRow,
      padding: pad,
      speakerW: fw.floorToDouble(),
      speakerH: fh.floorToDouble(),
      tileW: tileW,
      tileH: tileH,
      gridContentWidth: gridContentWidth,
      cols: g.cols,
      rows: g.rows,
    );
  }

  /// Pick the column count that maximizes tile size while keeping the fixed
  /// aspect ratio and fitting `m` tiles within `W` x `H`.
  static _Grid _bestGrid(int m, double W, double H, double gap, double aspect) {
    W = math.max(0, W);
    H = math.max(0, H);
    var best = _Grid(1, m, 0, 0);
    for (var c = 1; c <= m; c++) {
      final r = (m / c).ceil();
      final twByWidth = (W - (c - 1) * gap) / c;
      final twByHeight = ((H - (r - 1) * gap) / r) * aspect;
      final tw = math.min(twByWidth, twByHeight);
      if (tw > best.tileW) {
        best = _Grid(c, r, math.max(0, tw), math.max(0, tw / aspect));
      }
    }
    return best;
  }
}

/// Result of [_bestGrid]: a grid of `cols` x `rows` tiles sized `tileW`/`tileH`.
class _Grid {
  const _Grid(this.cols, this.rows, this.tileW, this.tileH);
  final int cols;
  final int rows;
  final double tileW;
  final double tileH;
}

/// Fully-resolved layout for one set of constraints.
class _LayoutSpec {
  const _LayoutSpec({
    required this.isRow,
    required this.padding,
    required this.speakerW,
    required this.speakerH,
    required this.tileW,
    required this.tileH,
    required this.gridContentWidth,
    required this.cols,
    required this.rows,
  });

  final bool isRow;
  final double padding;
  final double speakerW;
  final double speakerH;
  final double tileW;
  final double tileH;
  final double gridContentWidth;
  final int cols;
  final int rows;
}

// ───────────────────────────────────────────────────────────────────────────
// Example usage — delete or adapt. Shows how to slot in your own video widgets.
//
//   AdaptiveCallLayout(
//     speaker: VideoView(stream: activeSpeakerStream),   // null while you speak
//     participants: [
//       for (final p in otherParticipants) VideoView(stream: p.stream),
//     ],
//   )
//
// `speaker` and each `participants[i]` are laid out into correctly-sized boxes;
// make your video widget fill its box (e.g. FittedBox(fit: BoxFit.cover, ...)).
// ───────────────────────────────────────────────────────────────────────────
