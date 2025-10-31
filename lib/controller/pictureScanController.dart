import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui'; // Ensure Rect is imported
import 'dart:typed_data';
import 'package:durian_leaf_disease_detector_new/controller/historyController.dart';
import 'package:durian_leaf_disease_detector_new/service/permissions.dart';
import 'package:durian_leaf_disease_detector_new/service/yolo_detector.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

// Helper function to decode Rect from Map.
// Assume raw map keys {x, y, w, h} correspond directly to {left, top, width, height}
Rect _rectFromMap(Map<String, dynamic> boxData) {
  // Use 'x' as left, 'y' as top, 'w' as width, 'h' as height
  final left = (boxData['x'] as num?)?.toDouble() ?? 0.0;
  final top = (boxData['y'] as num?)?.toDouble() ?? 0.0;
  final width = (boxData['w'] as num?)?.toDouble() ?? 0.0;
  final height = (boxData['h'] as num?)?.toDouble() ?? 0.0;

  // The model's post-processing should have already converted from center-based
  // to top-left based coordinates before returning the map.

  return Rect.fromLTWH(
    left,
    top,
    width.abs(), // Still good practice to use abs()
    height.abs(),
  );
}

class PictureScanController extends GetxController {
  final _picker = ImagePicker();
  final _detector = YoloDetector();

  Rx<File?> selectedImage = Rx<File?>(null);
  RxList<Map<String, dynamic>> results = RxList<Map<String, dynamic>>([]);
  RxBool isProcessing = false.obs;
  RxBool modelLoaded = false.obs;
  RxInt imageWidth = 0.obs;
  RxInt imageHeight = 0.obs;

  @override
  void onInit() {
    super.onInit();
    _initDetector();
    // 💡 IMPORTANT: Load history on init to ensure correct data structure is used
    // If results are loaded from history, they must be converted back to Rect here.
    _loadHistoryResults();
  }

  // New function to handle loading history and fixing data types
  Future<void> _loadHistoryResults() async {
    final prefs = await SharedPreferences.getInstance();
    final historyList = prefs.getStringList('detection_history') ?? [];

    if (historyList.isNotEmpty) {
      // Assuming you want to load the last detection result upon opening the screen
      final lastEntry = jsonDecode(historyList.last);
      final savedResults = (lastEntry['results'] as List)
          .cast<Map<String, dynamic>>();

      final fixedResults = savedResults.map((r) {
        final boxData = r['box'] as Map<String, dynamic>;
        return {
          'box': _rectFromMap(boxData), // Convert Map back to Rect
          'confidence': r['confidence'],
          'label': r['label'],
        };
      }).toList();

      // Only assign if you want the last result displayed on startup
      // results.assignAll(fixedResults);
    }
  }

  Future<void> _initDetector() async {
    try {
      debugPrint("📥 Loading YOLO model...");
      await _detector.loadModel();
      modelLoaded.value = true;
      debugPrint("✅ YOLO model loaded successfully");
    } catch (e) {
      debugPrint('❌ Error loading YOLO model: $e');
      Get.snackbar('Error', 'Failed to load detection model: $e');
    }
  }

  Future<void> pickImage() async {
    if (isProcessing.value) return;
    if (!modelLoaded.value) {
      Get.snackbar('Error', 'Model is still loading. Please wait...');
      return;
    }

    final granted = await PermissionService.requestStorage();
    if (!granted) {
      Get.snackbar('Permission Denied', 'Storage permission is required.');
      return;
    }

    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    debugPrint("📸 Image selected: ${pickedFile.path}");

    // ✅ Set the image first and clear old results
    selectedImage.value = File(pickedFile.path);
    results.clear();

    // ✅ Allow one render frame before doing anything heavy
    await Future.delayed(const Duration(milliseconds: 800));

    // ✅ Now run detection (this will trigger the spinner AFTER image is on screen)
    unawaited(_runDetection(selectedImage.value!));
  }

  Future<void> _runDetection(File imageFile) async {
    debugPrint("🔍 Starting detection process...");
    isProcessing.value = true;

    try {
      final bytes = await imageFile.readAsBytes();
      final decoded = await compute(_decodeImage, bytes);
      if (decoded == null) throw Exception("Failed to decode image");

      // ✅ Fix EXIF rotation before resizing
      final oriented = img.bakeOrientation(decoded);

      // ✅ Force resize to 640x640 for both detection and UI
      final resizedImage = img.copyResize(oriented, width: 640, height: 640);

      // ✅ Update UI dimensions to match resized
      imageWidth.value = 640;
      imageHeight.value = 640;

      // Run detection
      // Assuming _detector.runInference returns List<Map<String, dynamic>> where 'box' is a Rect
      final detectionResults = await Future(
        () => _detector.runInference(
          resizedImage,
          confidenceThreshold: 0.25,
          nmsThreshold: 0.45,
        ),
      );
      debugPrint(
        '--- Raw Detector Output: ${detectionResults.length} results ---',
      );
      for (var result in detectionResults) {
        debugPrint('Raw Result: $result');
      }
      debugPrint('----------------------------------------------------');
      // 🔥 FIX: Ensure all 'box' values are cast to Rect here before assigning to results.
      // This is the most likely cause if the detector returns a Map by mistake.
      final fixedResults = detectionResults.map((r) {
        final boxData = r['box'];
        Rect box;

        // This handles the error type: Map<String, num>
        if (boxData is Map<String, num> || boxData is Map<String, dynamic>) {
          box = _rectFromMap(boxData.cast<String, num>());
        } else if (boxData is Rect) {
          box = boxData;
        } else {
          // If the data is neither Map nor Rect, it's a critical error
          throw FormatException(
            "Detection box data is not a Rect or a valid Map. Type: ${boxData.runtimeType}",
          );
        }

        return {
          'box': box, // Now guaranteed to be Rect
          'confidence': r['confidence'],
          'label': r['label'],
        };
      }).toList();

      debugPrint("✨ Detection Results: ${fixedResults.length} boxes found");

      // Assign the list containing only Rect objects for 'box'
      results.assignAll(fixedResults);

      // ✅ Save normalized image (so you can view same result later)
      final dir = await getApplicationDocumentsDirectory();
      final fileName =
          'normalized_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final normalizedFile = File('${dir.path}/$fileName')
        ..writeAsBytesSync(img.encodeJpg(resizedImage));
      selectedImage.value = normalizedFile;

      final savedPath = await _saveImageLocally(normalizedFile);
      // Pass the fixedResults (which contain Rect) to save detection
      await _saveDetection(savedPath, fixedResults);

      if (fixedResults.isEmpty) {
        Get.snackbar(
          'Detection Complete',
          'No diseases detected (or threshold too high).',
          duration: const Duration(seconds: 2),
        );
      }

      debugPrint("💾 Detection completed and saved!");
    } catch (e, st) {
      debugPrint('❌ Detection error: $e');
      debugPrint('$st');
      Get.snackbar('Error', 'Detection failed: ${e.toString()}');
    } finally {
      isProcessing.value = false;
      debugPrint("🏁 Detection finished - isProcessing=${isProcessing.value}");
    }
  }

  static img.Image? _decodeImage(Uint8List bytes) {
    try {
      final decoded = img.decodeImage(bytes);
      debugPrint(
        "🎨 Image decoded in isolate: ${decoded?.width}x${decoded?.height}",
      );
      return decoded;
    } catch (e) {
      debugPrint("❌ Error decoding image: $e");
      return null;
    }
  }

  Future<String> _saveImageLocally(File image) async {
    final dir = await getApplicationDocumentsDirectory();
    final fileName =
        'detection_${DateTime.now().millisecondsSinceEpoch}${path.extension(image.path)}';
    final savedImage = await image.copy('${dir.path}/$fileName');
    return savedImage.path;
  }

  Future<void> _saveDetection(
    String imagePath,
    List<Map<String, dynamic>> results,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final historyList = prefs.getStringList('detection_history') ?? [];

    // 🔥 FIX: Convert the Rect objects to Maps (for JSON) before saving.
    final jsonResults = results.map((r) {
      final box =
          r['box']
              as Rect; // This cast is safe now because of the fix in _runDetection
      return {
        'box': {
          'left': box.left,
          'top': box.top,
          'width': box.width,
          'height': box.height,
        },
        'confidence': r['confidence'],
        'label': r['label'],
      };
    }).toList();

    final newEntry = {
      'imagePath': imagePath,
      'dateTime': DateTime.now().toIso8601String(),
      'results': jsonResults,
    };

    historyList.add(jsonEncode(newEntry)); // ✅ Proper JSON
    await prefs.setStringList('detection_history', historyList);

    // Call history controller to refresh its list (which must also convert Map->Rect on load)
    final historyController = Get.find<HistoryController>();
    await historyController.loadHistory();
  }

  @override
  void onClose() {
    _detector.close();
    super.onClose();
  }
}
