import 'package:durian_leaf_disease_detector_new/controller/real-timeScanController.dart';
import 'package:durian_leaf_disease_detector_new/widget/myWitget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:camera/camera.dart';

// ========== MODIFIED: Converted to StatefulWidget ==========
class RealtimeScan extends StatefulWidget {
  const RealtimeScan({super.key});

  @override
  State<RealtimeScan> createState() => _RealtimeScanState();
}

class _RealtimeScanState extends State<RealtimeScan> {
  final ctrl = Get.put(RealtimeScanController());
  // Tracks if the AI model loading dialog is currently visible
  bool _isDialogShowing = false;

  @override
  void initState() {
    super.initState();

    // Listener 1: Manages the 'warming_up' dialog.
    // Triggers whenever camera or isolate readiness changes.
    ever(ctrl.isCameraInitialized, _updateDialogState);
    ever(ctrl.isIsolateReady, _updateDialogState);
  }

  /// This function shows/hides the **'warming_up'** dialog based on the controller's state.
  /// This dialog only appears *after* the camera is ready (isCamReady is true).
  void _updateDialogState(bool _) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bool isCamReady = ctrl.isCameraInitialized.value;
      final bool isIsolateReady = ctrl.isIsolateReady.value;

      // Logic: Show the dialog ONLY when: Camera is ready AND Isolate is NOT ready (AI loading)
      final bool shouldShowDialog = isCamReady && !isIsolateReady;

      if (shouldShowDialog && !_isDialogShowing) {
        // --- Show the dialog (AI warming up) ---
        _isDialogShowing = true;
        if (mounted) {
             Get.dialog(
              Dialog(
                backgroundColor: Colors.black.withOpacity(0.5),
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Colors.white),
                      const SizedBox(height: 16),
                      Text(
                        // This text is now correctly associated with the dialog
                        "warming_up".tr, 
                        style: const TextStyle(
                          color: Colors.white, 
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              barrierDismissible: false,
            );
        }
       
      } else if (!shouldShowDialog && _isDialogShowing) {
        // --- Hide the dialog (AI is ready) ---
        _isDialogShowing = false;
        if (Get.isDialogOpen ?? false) {
           Get.back(); // Dismisses the dialog when the model load is complete
        }
      }
    });
  }
  
  @override
  void dispose() {
    if (_isDialogShowing && (Get.isDialogOpen ?? false)) {
      Get.back();
    }
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: appbar(context, "real_time_scan".tr),
      body: Obx(() {
        // ===============================================
        // Initial Loading Spinner (for camera initialization)
        // This runs BEFORE the camera starts, just showing a spinner.
        if (!ctrl.isCameraInitialized.value) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                // Removed the "warming_up".tr text from here to avoid redundancy
              ],
            ),
          );
        }
        // ===============================================

        final previewSize = ctrl.cameraController!.value.previewSize!;
        final previewW = previewSize.height;
        final previewH = previewSize.width;

        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight =
            MediaQuery.of(context).size.height * 0.5;

        final previewAspect = previewW / previewH;
        final widgetAspect = screenWidth / screenHeight;

        double scaleX, scaleY;
        double offsetX = 0, offsetY = 0;

        if (previewAspect > widgetAspect) {
          scaleX = screenWidth / previewW;
          scaleY = scaleX;
          offsetY = (screenHeight - previewH * scaleY) / 2;
        } else {
          scaleY = screenHeight / previewH;
          scaleX = scaleY;
          offsetX = (screenWidth - previewW * scaleX) / 2;
        }

        return Stack(
          children: [
            // Camera feed top half
            Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: screenWidth,
                height: screenHeight,
                child: CameraPreview(ctrl.cameraController!),
              ),
            ),

            // Bounding boxes overlay
            Positioned(
              left: 0,
              top: 0,
              width: screenWidth,
              height: screenHeight,
              child: CustomPaint(
                painter: BoundingBoxPainter(
                  results: ctrl.results,
                  scaleX: scaleX,
                  scaleY: scaleY,
                  offsetX: offsetX,
                  offsetY: offsetY,
                ),
              ),
            ),

            // Debug info
            Positioned(
              bottom: 20,
              left: 10,
              child: Text(
                ctrl.isDetecting.value
                    ? "Detecting..."
                    : "Detections: ${ctrl.results.length}",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  backgroundColor: Colors.black54,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}


// ========================================
// BoundingBoxPainter (No changes needed here)
// ========================================
class BoundingBoxPainter extends CustomPainter {
  final List<Map<String, dynamic>> results;
  final double scaleX;
  final double scaleY;
  final double offsetX;
  final double offsetY;

  BoundingBoxPainter({
    required this.results,
    required this.scaleX,
    required this.scaleY,
    required this.offsetX,
    required this.offsetY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (results.isEmpty) return;
    
    for (final r in results) {
      final box = r['box'];
      if (box == null) continue;

      // Accessing LabelColors in the same file
      final color = LabelColors.getColor(r['label'] ?? ''); 
      final rect = Rect.fromLTWH(
        offsetX + box['x'] * scaleX,
        offsetY + box['y'] * scaleY,
        box['w'] * scaleX,
        box['h'] * scaleY,
      );

      final paint = Paint()
        ..color = color
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke;
      canvas.drawRect(rect, paint);

      final label =
          "${(r['label'] ?? '').toString().tr} ${(r['confidence'] * 100).toStringAsFixed(1)}%";
      final textStyle = const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      );

      final textPainter = TextPainter(
        text: TextSpan(text: label, style: textStyle),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout(maxWidth: rect.width - 4);

      final labelRect = Rect.fromLTWH(
        rect.left,
        rect.bottom - textPainter.height - 4,
        textPainter.width + 8,
        textPainter.height + 4,
      );

      final bgPaint = Paint()..color = color.withOpacity(0.8);
      canvas.drawRect(labelRect, bgPaint);

      textPainter.paint(
        canvas,
        Offset(rect.left + 4, rect.bottom - textPainter.height - 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ========================================
// LabelColors class
// ========================================
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