import 'dart:isolate';
import 'dart:typed_data';
import 'dart:async';
import 'package:durian_leaf_disease_detector_new/service/realtimeYolo.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:camera/camera.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as img;
import 'package:durian_leaf_disease_detector_new/service/permissions.dart';

class RealtimeScanController extends GetxController {
  RxBool hasPermission = false.obs;
  RxBool isDetecting = false.obs;
  RxList<Map<String, dynamic>> results = RxList<Map<String, dynamic>>([]);
  RxBool isInitializing = true.obs;
  RxString errorMessage = ''.obs;
  RxBool isCameraInitialized = false.obs;

  // 🔥 FIXED: Observable to control the 'warming_up' dialog
  RxBool isIsolateReady = false.obs;

  CameraController? cameraController;
  bool _initialized = false;
  bool _disposed = false;

  Isolate? _isolate;
  ReceivePort? _receivePort;
  SendPort? _sendPort;

  final int frameThrottleMs = 1500;
  DateTime _lastSent = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void onInit() {
    super.onInit();
    print('🔵 onInit() called');
    initialize();
  }

  Future<void> initialize() async {
    if (_initialized) {
      print('⚠️ Already initialized.');
      return;
    }
    print('🔵 Initializing realtime scan controller...');
    _initialized = true;
    isInitializing.value = true;
    _disposed = false;

    // Reset state before starting initialization
    isIsolateReady.value = false;

    try {
      print('📦 Loading model bytes...');
      // FIXED: Use consistent model file
      final modelData = await rootBundle.load(
        'assets/ai_model/best_float32.tflite',
      );
      final modelBytes = modelData.buffer.asUint8List();
      print('✅ Model bytes loaded (${modelBytes.lengthInBytes} bytes)');

      _receivePort = ReceivePort();
      print('🧩 Spawning isolate...');
      _isolate = await Isolate.spawn(_processFrameIsolate, {
        'mainSend': _receivePort!.sendPort,
        'modelBytes': modelBytes,
      });

      _receivePort!.listen((message) {
        if (_disposed) return;

        if (message is SendPort) {
          print('✅ Main received SendPort — isolate ready!');
          _sendPort = message;

          // 🔥 FIXED: Set this to true *after* the isolate confirms model load.
          isIsolateReady.value = true;
        } else if (message is List) {
          print('📥 Main received detections: ${message.length} results');
          results.assignAll(message.cast<Map<String, dynamic>>());
          isDetecting.value = false;
        } else if (message is String && message.startsWith('ERROR:')) {
          print('🚨 Isolate error: $message');
          errorMessage.value = message;
          isDetecting.value = false;
        } else {
          print('⚙️ Unknown message from isolate: $message');
        }
      });

      await _initPermissionsAndCamera();
    } catch (e, st) {
      print('🚨 Initialization failed: $e\n$st');
      errorMessage.value = 'Initialization failed: $e';
    } finally {
      isInitializing.value = false;
    }
  }

  Future<void> _initPermissionsAndCamera() async {
    print('📷 Requesting camera permission...');
    final ok = await PermissionService.requestCamera();
    if (!ok) {
      hasPermission.value = false;
      errorMessage.value = 'Camera permission denied';
      print('🚫 Camera permission denied.');
      return;
    }
    print('✅ Camera permission granted.');
    hasPermission.value = true;
    await _initCamera();
  }

  Future<void> _initCamera() async {
    print('📷 Initializing camera...');
    final cameras = await availableCameras();
    if (cameras.isEmpty) throw Exception('No camera found.');
    final back = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    cameraController = CameraController(
      back,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await cameraController!.initialize();
    print('✅ Camera initialized (${back.name})');

    await cameraController!.startImageStream(_onImageAvailable);
    isCameraInitialized.value = true;
    print('📸 Camera stream started.');
  }

  void _onImageAvailable(CameraImage image) {
    // 🔥 FIXED: Wait for isolate to be ready before sending any frames
    if (_disposed || _sendPort == null || !isIsolateReady.value) return;

    final now = DateTime.now();
    if (now.difference(_lastSent).inMilliseconds < frameThrottleMs) return;
    _lastSent = now;

    if (isDetecting.value) return;
    isDetecting.value = true;

    print('📤 Sending frame to isolate (${image.width}x${image.height})');

    final planes = image.planes.map((p) {
      return {
        'bytes': p.bytes,
        'bytesPerRow': p.bytesPerRow,
        'bytesPerPixel': p.bytesPerPixel ?? 1,
      };
    }).toList();

    _sendPort!.send({
      'width': image.width,
      'height': image.height,
      'planes': planes,
    });
  }

  @override
  void onClose() {
    super.onClose();
    _cleanup();
  }

  Future<void> _cleanup() async {
    if (_disposed) return;
    _disposed = true;

    print('🧹 Cleaning up realtime scan controller...');
    try {
      await cameraController?.stopImageStream();
      await cameraController?.dispose();
      cameraController = null;

      _receivePort?.close();
      _isolate?.kill(priority: Isolate.immediate);
      _receivePort = null;
      _sendPort = null;
      _isolate = null;

      isIsolateReady.value = false;

      _initialized = false;
      print('✅ Cleanup complete.');
    } catch (e) {
      print('⚠️ Cleanup error: $e');
    }
  }
}

// ------------------ ISOLATE ------------------
void _processFrameIsolate(Map args) async {
  final SendPort mainSend = args['mainSend'] as SendPort;
  final Uint8List modelBytes = args['modelBytes'] as Uint8List;

  print('🧩 Isolate started.');
  final receivePort = ReceivePort();

  final detector = RealtimeYoloDetector();
  try {
    await detector.loadModelFromBuffer(modelBytes);
    print('✅ RealtimeYoloDetector initialized inside isolate');

    // Send the port *after* the model is loaded to signal readiness!
    mainSend.send(receivePort.sendPort);
  } catch (e) {
    mainSend.send('ERROR:Model loading failed - $e');
    return;
  }

  receivePort.listen((message) async {
    if (message is! Map) return;
    try {
      print('📥 Isolate received frame data...');
      final width = message['width'] as int;
      final height = message['height'] as int;
      final planes = message['planes'] as List;

      final imgRgb = _convertYUV420toImageColor(planes, width, height);
      final rotated = img.copyRotate(imgRgb, 90);

      print('🖼️ Frame converted & rotated for inference');

      final detections = detector.runInference(
        rotated,
        confidenceThreshold: 0.10,
        nmsThreshold: 0.3,
      );
      print('📊 Inference complete — ${detections.length} detections found');
      mainSend.send(detections);
    } catch (e, st) {
      print('🚨 Isolate error while processing frame: $e\n$st');
      mainSend.send('ERROR:Processing failed - $e');
    }
  });
}

img.Image _convertYUV420toImageColor(List planes, int width, int height) {
  print('🎨 Converting YUV420 → RGB image...');
  final yPlane = planes[0]['bytes'] as Uint8List;
  final uPlane = planes[1]['bytes'] as Uint8List;
  final vPlane = planes[2]['bytes'] as Uint8List;
  final yRowStride = planes[0]['bytesPerRow'] as int;
  final uvRowStride = planes[1]['bytesPerRow'] as int;
  final uvPixelStride = planes[1]['bytesPerPixel'] as int;

  final image = img.Image(width, height);

  for (int row = 0; row < height; row++) {
    final uvRow = (row >> 1) * uvRowStride;
    final yRow = row * yRowStride;
    for (int col = 0; col < width; col++) {
      final yIndex = yRow + col;
      final uvIndex = uvRow + (col >> 1) * uvPixelStride;

      final yp = yPlane[yIndex].toDouble();
      final up = uPlane[uvIndex].toDouble() - 128.0;
      final vp = vPlane[uvIndex].toDouble() - 128.0;

      double r = yp + 1.370705 * vp;
      double g = yp - 0.337633 * up - 0.698001 * vp;
      double b = yp + 1.732446 * up;

      image.setPixelRgba(
        col,
        row,
        r.clamp(0, 255).toInt(),
        g.clamp(0, 255).toInt(),
        b.clamp(0, 255).toInt(),
        255,
      );
    }
  }
  print('✅ YUV→RGB conversion done.');
  return image;
}
