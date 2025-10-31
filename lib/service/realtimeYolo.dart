// realtime_yolo_detector.dart
// Separate detector for realtime scanning only
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class RealtimeYoloDetector {
  final List<String> labels = [
    'algal_leaf_spot',
    'leaf_blight',
    'leaf_spot',
    'no_disease',
    'pest',
  ];

  late Interpreter _interpreter;
  bool _isLoaded = false;

  /// Load from buffer - used inside isolate
  Future<void> loadModelFromBuffer(Uint8List buffer) async {
    // Use NNAPI (Android's built-in neural network acceleration)
    final options = InterpreterOptions()
      ..useNnApiForAndroid = true
      ..threads = 4;
    
    _interpreter = Interpreter.fromBuffer(buffer, options: options);
    _isLoaded = true;
    print('✅ Realtime YOLO model loaded (NNAPI + 4 threads)');
  }

  bool get isLoaded => _isLoaded;

  void close() {
    try {
      _interpreter.close();
    } catch (_) {}
    _isLoaded = false;
  }

  List<Map<String, dynamic>> runInference(
    img.Image image, {
    double confidenceThreshold = 0.25,
    double nmsThreshold = 0.3,
  }) {
    if (!_isLoaded) throw Exception("Model not loaded");

    const inputSize = 640;
    final originalWidth = image.width;
    final originalHeight = image.height;

    // Resize to input
    final resized = img.copyResize(image, width: inputSize, height: inputSize);
    final input = Float32List(inputSize * inputSize * 3);

    int idx = 0;
    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        final pixel = resized.getPixel(x, y);
        input[idx++] = img.getRed(pixel) / 255.0;
        input[idx++] = img.getGreen(pixel) / 255.0;
        input[idx++] = img.getBlue(pixel) / 255.0;
      }
    }

    // Output placeholder (model-specific shape)
    final output = List.generate(
      1,
      (_) => List.generate(9, (_) => List.filled(8400, 0.0)),
    );

    final startTime = DateTime.now();
    _interpreter.run(input.reshape([1, inputSize, inputSize, 3]), output);
    final inferenceTime = DateTime.now().difference(startTime).inMilliseconds;
    print('⏱️ Inference: ${inferenceTime}ms');

    final raw = output[0];
    final numBoxes = raw[0].length;

    final detections = <Map<String, dynamic>>[];
    int validBoxes = 0;

    for (int i = 0; i < numBoxes; i++) {
      double x = raw[0][i];
      double y = raw[1][i];
      double w = raw[2][i];
      double h = raw[3][i];

      final classScores = [
        raw[4][i],
        raw[5][i],
        raw[6][i],
        raw[7][i],
        raw[8][i],
      ];

      final maxClassScore = classScores.reduce(max);
      final classId = classScores.indexOf(maxClassScore);

      if (maxClassScore >= confidenceThreshold) {
        validBoxes++;

        final xPixel = x * inputSize;
        final yPixel = y * inputSize;
        final wPixel = w * inputSize;
        final hPixel = h * inputSize;

        final scaleX = originalWidth / inputSize;
        final scaleY = originalHeight / inputSize;

        final left = (xPixel - wPixel / 2) * scaleX;
        final top = (yPixel - hPixel / 2) * scaleY;
        final width = wPixel * scaleX;
        final height = hPixel * scaleY;

        // Return box as Map for realtime painting
        detections.add({
          'box': {
            'x': left.clamp(0, originalWidth.toDouble()),
            'y': top.clamp(0, originalHeight.toDouble()),
            'w': width.clamp(0, originalWidth.toDouble()),
            'h': height.clamp(0, originalHeight.toDouble()),
          },
          'confidence': maxClassScore,
          'label': labels[classId],
        });
      }
    }

    final filtered = _applyNMS(detections, nmsThreshold);
    print(
      '📦 Boxes above threshold: $validBoxes → after NMS: ${filtered.length}',
    );
    return filtered;
  }

  List<Map<String, dynamic>> _applyNMS(
    List<Map<String, dynamic>> detections,
    double iouThreshold,
  ) {
    if (detections.isEmpty) return [];

    detections.sort(
      (a, b) =>
          (b['confidence'] as double).compareTo(a['confidence'] as double),
    );

    final filtered = <Map<String, dynamic>>[];

    for (var det in detections) {
      bool keep = true;
      for (var f in filtered) {
        if (_iou(det['box'] as Map<String, dynamic>, 
                 f['box'] as Map<String, dynamic>) > iouThreshold) {
          keep = false;
          break;
        }
      }
      if (keep) filtered.add(det);
    }

    return filtered;
  }

  double _iou(Map<String, dynamic> a, Map<String, dynamic> b) {
    final aX = (a['x'] as num).toDouble();
    final aY = (a['y'] as num).toDouble();
    final aW = (a['w'] as num).toDouble();
    final aH = (a['h'] as num).toDouble();
    final bX = (b['x'] as num).toDouble();
    final bY = (b['y'] as num).toDouble();
    final bW = (b['w'] as num).toDouble();
    final bH = (b['h'] as num).toDouble();

    final x1 = max(aX, bX);
    final y1 = max(aY, bY);
    final x2 = min(aX + aW, bX + bW);
    final y2 = min(aY + aH, bY + bH);

    final interArea = max(0.0, x2 - x1) * max(0.0, y2 - y1);
    final unionArea = aW * aH + bW * bH - interArea;
    return unionArea == 0 ? 0 : interArea / unionArea;
  }
}

class LabelColors {
  static const Map<String, Color> colors = {
    'algal_leaf_spot': Colors.red,
    'leaf_blight': Colors.orange,
    'leaf_spot': Color(0xFFFFD700),
    'no_disease': Colors.green,
    'pest': Colors.purple,
  };

  static Color getColor(String label) => colors[label] ?? Colors.black;
}