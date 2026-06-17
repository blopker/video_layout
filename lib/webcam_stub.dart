import 'package:flutter/widgets.dart';

/// Off the web there's no camera here — report unavailable and render nothing.
bool get webcamReady => false;

Future<bool> startWebcam() async => false;

Widget buildWebcamView() => const SizedBox.shrink();
