// Webcam access, with a no-op fallback off the web so VM tests still compile.
//
//   await startWebcam();          // request the camera, register the view
//   if (webcamReady) buildWebcamView();  // one <video> per call, shared stream
export 'webcam_stub.dart' if (dart.library.js_interop) 'webcam_web.dart';
