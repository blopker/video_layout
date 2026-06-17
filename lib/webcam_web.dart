import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

const _viewType = 'webcam-video';

web.MediaStream? _stream;
bool _registered = false;

bool get webcamReady => _stream != null;

/// Requests the camera once and registers a platform-view factory that mints a
/// fresh `<video>` element per call, all bound to the same [MediaStream] so the
/// one camera feed can paint into every tile at once.
Future<bool> startWebcam() async {
  if (_stream != null) return true;
  try {
    final stream = await web.window.navigator.mediaDevices
        .getUserMedia(
          web.MediaStreamConstraints(video: true.toJS, audio: false.toJS),
        )
        .toDart;
    _stream = stream;

    if (!_registered) {
      ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
        final video =
            web.document.createElement('video') as web.HTMLVideoElement
              ..autoplay = true
              ..muted = true
              ..srcObject = _stream;
        video.setAttribute('playsinline', 'true');
        video.style
          ..width = '100%'
          ..height = '100%'
          ..objectFit = 'cover'; // fill the tile box, crop the overflow
        return video;
      });
      _registered = true;
    }
    return true;
  } catch (_) {
    // Permission denied / no camera / insecure context.
    return false;
  }
}

Widget buildWebcamView() => const HtmlElementView(viewType: _viewType);
