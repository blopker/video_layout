import 'dart:math';

import 'package:flutter/material.dart';

import 'layout.dart';
import 'webcam.dart';

void main() {
  runApp(const PrototypeApp());
}

class PrototypeApp extends StatelessWidget {
  const PrototypeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Adaptive Call Layout — Prototype',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(
        useMaterial3: true,
      ).copyWith(scaffoldBackgroundColor: const Color(0xFF0E0F13)),
      home: const PrototypeHome(),
    );
  }
}

class PrototypeHome extends StatefulWidget {
  const PrototypeHome({super.key});

  @override
  State<PrototypeHome> createState() => _PrototypeHomeState();
}

class _PrototypeHomeState extends State<PrototypeHome> {
  // ── Tunable prototype state ────────────────────────────────────────────────
  bool _showSpeaker = true;
  double _aspect = 4 / 5; // width / height
  double _spacing = 10;
  bool _showStats = true;
  bool _webcamReady = false;
  bool _useKeys = false; // #3: propagate stable keys to the layout's tiles?

  // Stable participant identities, so a shuffle reorders the *same* people.
  final List<int> _ids = [1, 2, 3, 4];
  int _nextId = 5;

  int get _participantCount => _ids.length;

  void _setCount(int n) {
    setState(() {
      while (_ids.length < n) {
        _ids.add(_nextId++);
      }
      while (_ids.length > n) {
        _ids.removeLast();
      }
    });
  }

  void _shuffle() => setState(() => _ids.shuffle());

  static const _aspects = <String, double>{
    '4:5': 4 / 5,
    '1:1': 1.0,
    '4:3': 4 / 3,
    '16:9': 16 / 9,
  };

  @override
  void initState() {
    super.initState();
    // Ask for the camera; on success every tile shares the one feed.
    startWebcam().then((ok) {
      if (ok && mounted) setState(() => _webcamReady = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    // One live <video> per tile, all bound to the same camera stream.
    Widget? video() => _webcamReady ? buildWebcamView() : null;

    final layout = AdaptiveCallLayout(
      tileAspectRatio: _aspect,
      spacing: _spacing,
      speaker: _showSpeaker
          ? _FakeVideo(
              label: 'Active Speaker',
              seed: 0,
              speaking: true,
              big: true,
              video: video(),
            )
          : null,
      participants: [
        for (final id in _ids)
          _FakeVideo(
            // #3: with keys, per-tile state follows the person across a
            // shuffle; without, it stays glued to the slot.
            key: _useKeys ? ValueKey(id) : null,
            label: _names[id % _names.length],
            seed: id,
            video: video(),
          ),
      ],
    );

    return Scaffold(
      body: Row(
        children: [
          _ControlPanel(
            participantCount: _participantCount,
            showSpeaker: _showSpeaker,
            aspect: _aspect,
            spacing: _spacing,
            showStats: _showStats,
            useKeys: _useKeys,
            aspects: _aspects,
            onParticipants: _setCount,
            onShuffle: _shuffle,
            onUseKeys: (v) => setState(() => _useKeys = v),
            onShowSpeaker: (v) => setState(() => _showSpeaker = v),
            onAspect: (v) => setState(() => _aspect = v),
            onSpacing: (v) => setState(() => _spacing = v),
            onShowStats: (v) => setState(() => _showStats = v),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) => Stack(
                children: [
                  // The viewport the layout engine actually fills.
                  Positioned.fill(child: layout),
                  if (_showStats && c.maxWidth.isFinite && c.maxHeight.isFinite)
                    Positioned(
                      left: 12,
                      bottom: 12,
                      child: _SizeReadout(
                        width: c.maxWidth,
                        height: c.maxHeight,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _names = [
    'Ada',
    'Linus',
    'Grace',
    'Dennis',
    'Margaret',
    'Alan',
    'Barbara',
    'Ken',
    'Radia',
    'Tim',
    'Edsger',
    'Katherine',
  ];
}

// ── Control panel ─────────────────────────────────────────────────────────────

class _ControlPanel extends StatelessWidget {
  const _ControlPanel({
    required this.participantCount,
    required this.showSpeaker,
    required this.aspect,
    required this.spacing,
    required this.showStats,
    required this.useKeys,
    required this.aspects,
    required this.onParticipants,
    required this.onShuffle,
    required this.onUseKeys,
    required this.onShowSpeaker,
    required this.onAspect,
    required this.onSpacing,
    required this.onShowStats,
  });

  final int participantCount;
  final bool showSpeaker;
  final double aspect;
  final double spacing;
  final bool showStats;
  final bool useKeys;
  final Map<String, double> aspects;
  final ValueChanged<int> onParticipants;
  final VoidCallback onShuffle;
  final ValueChanged<bool> onUseKeys;
  final ValueChanged<bool> onShowSpeaker;
  final ValueChanged<double> onAspect;
  final ValueChanged<double> onSpacing;
  final ValueChanged<bool> onShowStats;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF15171E),
      child: SizedBox(
        width: 260,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: _children(),
        ),
      ),
    );
  }

  List<Widget> _children() {
    return [
      const Text(
        'Adaptive Call Layout',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 4),
      Text(
        'Resize the window to cross the 540px breakpoint.',
        style: TextStyle(
          fontSize: 12,
          color: Colors.white.withValues(alpha: 0.5),
        ),
      ),
      const SizedBox(height: 24),

      _Label('Participants: $participantCount'),
      Slider(
        value: participantCount.toDouble(),
        min: 0,
        max: 12,
        divisions: 12,
        label: '$participantCount',
        onChanged: (v) => onParticipants(v.round()),
      ),

      const SizedBox(height: 8),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Featured speaker'),
        value: showSpeaker,
        onChanged: onShowSpeaker,
      ),

      const Divider(height: 32),
      const _Label('Reorder experiment (#3)'),
      const SizedBox(height: 4),
      Text(
        'Each tile picks a random ring colour + #id once. Shuffle and watch '
        'whether that state follows the name.',
        style: TextStyle(
          fontSize: 12,
          color: Colors.white.withValues(alpha: 0.5),
        ),
      ),
      const SizedBox(height: 10),
      FilledButton.tonalIcon(
        onPressed: participantCount > 1 ? onShuffle : null,
        icon: const Icon(Icons.shuffle, size: 18),
        label: const Text('Shuffle participants'),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Propagate keys'),
        subtitle: Text(
          useKeys ? 'state follows the person' : 'state sticks to the slot',
        ),
        value: useKeys,
        onChanged: onUseKeys,
      ),
      const Divider(height: 32),

      const SizedBox(height: 16),
      const _Label('Tile aspect ratio'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        children: [
          for (final entry in aspects.entries)
            ChoiceChip(
              label: Text(entry.key),
              selected: (aspect - entry.value).abs() < 0.001,
              onSelected: (_) => onAspect(entry.value),
            ),
        ],
      ),

      const SizedBox(height: 24),
      _Label('Spacing: ${spacing.round()}px'),
      Slider(
        value: spacing,
        min: 0,
        max: 32,
        divisions: 32,
        label: '${spacing.round()}',
        onChanged: onSpacing,
      ),

      const SizedBox(height: 8),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Show size readout'),
        value: showStats,
        onChanged: onShowStats,
      ),
    ];
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
  );
}

// ── A live readout of the rendered viewport size ────────────────────────────

class _SizeReadout extends StatelessWidget {
  const _SizeReadout({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final mode = width < 540 ? 'mobile / column' : 'desktop / row';
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '${width.round()} × ${height.round()}  ·  $mode',
          style: const TextStyle(
            fontSize: 12,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

// ── Fake "video" tile: a colored gradient with a name + mic indicator ────────
//
// Stateful on purpose: each tile picks a random accent + session id ONCE in
// initState. That state is what the keys experiment (#3) is about — on a
// reorder, does this state follow the *person* (keyed) or stay glued to the
// *slot* (unkeyed)?

class _FakeVideo extends StatefulWidget {
  const _FakeVideo({
    super.key,
    required this.label,
    required this.seed,
    this.speaking = false,
    this.big = false,
    this.video,
  });

  final String label;
  final int seed;
  final bool speaking;
  final bool big;

  /// Live video (e.g. the webcam) to cover-fill the tile. When null, a
  /// simulated native-ratio placeholder is shown instead.
  final Widget? video;

  // Simulated *native* source shapes (label, width / height), varied per tile
  // so cover-cropping is visible. A real app would get these from each stream.
  static const _nativeSources = <(String, double)>[
    ('16:9', 16 / 9),
    ('9:16', 9 / 16),
    ('4:3', 4 / 3),
    ('1:1', 1.0),
    ('3:2', 3 / 2),
  ];

  @override
  State<_FakeVideo> createState() => _FakeVideoState();
}

class _FakeVideoState extends State<_FakeVideo> {
  // Per-instance state, assigned once. If the layout reorders tiles without
  // honoring keys, this state stays with the slot, not the person.
  late final Color _accent;
  late final int _sessionId;

  @override
  void initState() {
    super.initState();
    final rnd = Random();
    _accent = HSLColor.fromAHSL(1, rnd.nextDouble() * 360, 0.85, 0.6).toColor();
    _sessionId = 1000 + rnd.nextInt(9000);
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final hue = (w.seed * 47) % 360;
    final base = HSLColor.fromAHSL(1, hue.toDouble(), 0.45, 0.45).toColor();
    final dark = HSLColor.fromAHSL(1, hue.toDouble(), 0.5, 0.22).toColor();
    final initials = w.label.isNotEmpty ? w.label[0].toUpperCase() : '?';
    final (nativeLabel, nativeAspect) =
        _FakeVideo._nativeSources[w.seed % _FakeVideo._nativeSources.length];

    return LayoutBuilder(
      builder: (context, c) {
        // On tiny thumbnails there's no room for labels — drop the chrome
        // rather than overflow it (a real grid hides labels on small tiles too).
        final showChrome = c.maxWidth >= 72 && c.maxHeight >= 56;
        return DecoratedBox(
          // Accent ring = per-instance state, painted over the video so it's
          // visible even on tiny tiles. Watch whether it follows the name.
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(w.big ? 14 : 10),
            border: Border.all(color: _accent, width: w.big ? 4 : 3),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(w.big ? 14 : 10),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── "Video" layer. The webcam's <video> already does object-fit
                // cover, so it fills the tile box directly. Otherwise fall back
                // to a fixed native-ratio frame, cover-cropped to fill — the
                // pattern any real video widget should follow.
                if (w.video != null)
                  w.video!
                else
                  FittedBox(
                    fit: BoxFit.cover,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: 1000 * nativeAspect,
                      height: 1000,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [base, dark],
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 6,
                          ),
                        ),
                        child: Center(
                          child: SizedBox(
                            width: 260,
                            height: 260,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  initials,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 120,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Session-id badge (state), top-right — colored to match the
                // accent ring so it's clearly the same per-instance state.
                if (showChrome)
                  Positioned(
                    right: 8,
                    top: 6,
                    child: _tag('#$_sessionId', _accent),
                  ),
                // Source tag, top-left.
                if (showChrome)
                  Positioned(
                    left: 8,
                    top: 6,
                    child: _tag(w.video != null ? 'LIVE' : 'src $nativeLabel'),
                  ),
                // Name + mic chip, bottom-left.
                if (showChrome)
                  Positioned(
                    left: 8,
                    bottom: 8,
                    right: 8,
                    child: ClipRect(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            w.speaking ? Icons.mic : Icons.mic_off,
                            size: 14,
                            color: w.speaking
                                ? const Color(0xFF4ADE80)
                                : Colors.white70,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              w.label,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: w.big ? 15 : 12,
                                fontWeight: FontWeight.w500,
                                shadows: const [
                                  Shadow(blurRadius: 3, color: Colors.black54),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _tag(String text, [Color? color]) {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 10,
            fontWeight: color != null ? FontWeight.w700 : FontWeight.w400,
            color: color ?? Colors.white70,
          ),
        ),
      ),
    );
  }
}
