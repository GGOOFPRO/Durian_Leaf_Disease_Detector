import 'dart:io';
import 'package:durian_leaf_disease_detector_new/controller/historyController.dart';
import 'package:durian_leaf_disease_detector_new/widget/bottomnav.dart';
import 'package:durian_leaf_disease_detector_new/widget/myWitget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class History extends StatelessWidget {
  History({super.key});

  final HistoryController controller = Get.find<HistoryController>();

  void _showDetectionDialog(
    BuildContext context,
    Map<String, dynamic> entry,
  ) async {
    final imagePath = entry['imagePath'] as String?;
    if (imagePath == null || !File(imagePath).existsSync()) {
      Get.snackbar('Error', 'Image file missing or corrupted.');
      return;
    }

    final results = List<Map<String, dynamic>>.from(entry['results'] ?? []);
    final imageFile = File(imagePath);

    // 🟢 Decode image to get actual width & height
    final decoded = await decodeImageFromList(imageFile.readAsBytesSync());
    final originalWidth = decoded.width.toDouble();
    final originalHeight = decoded.height.toDouble();

    print("🖌️ Decoded image size: ${originalWidth}x${originalHeight}");
    print("📦 Results count: ${results.length}");
    for (var i = 0; i < results.length; i++) {
      print("🔹 Result $i: ${results[i]}");
    }
    const Map<String, Color> labelColors = {
      'algal_leaf_spot': Colors.red,
      'leaf_blight': Colors.orange,
      'leaf_spot': Color(0xFFFFD700),
      'no_disease': Colors.green,
      'pest': Colors.purple,
    };

    Color getColor(String label) => labelColors[label] ?? Colors.black;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.all(10.w),
        child: LayoutBuilder(
          builder: (context, constraints) {
            double displayWidth = constraints.maxWidth;
            double displayHeight = constraints.maxHeight;
            double imageRatio = originalWidth / originalHeight;
            double widgetRatio = displayWidth / displayHeight;

            if (imageRatio > widgetRatio) {
              displayHeight = displayWidth / imageRatio;
            } else {
              displayWidth = displayHeight * imageRatio;
            }

            final offsetX = (constraints.maxWidth - displayWidth) / 2;
            final offsetY = (constraints.maxHeight - displayHeight) / 2;

            final scaleX = displayWidth / originalWidth;
            final scaleY = displayHeight / originalHeight;

            return Stack(
              children: [
                Positioned(
                  left: offsetX,
                  top: offsetY,
                  width: displayWidth,
                  height: displayHeight,
                  child: InteractiveViewer(
                    child: Image.file(imageFile, fit: BoxFit.contain),
                  ),
                ),
                ...results.map((r) {
                  final box = r['box'] as Map<String, dynamic>;
                  final rect = Rect.fromLTWH(
                    (box['left'] as num).toDouble(),
                    (box['top'] as num).toDouble(),
                    (box['width'] as num).toDouble(),
                    (box['height'] as num).toDouble(),
                  );

                  final rawLabel = r['label'] ?? '';
                  final label = rawLabel.toString().tr; // Translate here
                  final conf = r['confidence'] ?? 0.0;
                  final color = getColor(rawLabel); // use raw label for color

                  return Positioned(
                    left: offsetX + rect.left * scaleX,
                    top: offsetY + rect.top * scaleY,
                    width: rect.width * scaleX,
                    height: rect.height * scaleY,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: color, width: 2.w),
                        color: color.withOpacity(0.1),
                      ),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Container(
                          color: color.withOpacity(0.8),
                          padding: EdgeInsets.symmetric(
                            horizontal: 4.w,
                            vertical: 2.h,
                          ),
                          child: MyWidget.normalText(
                            context,
                            "$label ${(conf * 100).toStringAsFixed(1)}%",
                            Colors.white,
                            12.sp,
                            FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
                Positioned(
                  right: 5,
                  top: 5,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appbar(context, 'history'.tr),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.history.isEmpty) {
          return Center(
            child: MyWidget.normalText(
              context,
              'no_history_yet'.tr,
              Colors.grey,
              18.0,
              FontWeight.w500,
            ),
          );
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 12.w),
          itemCount: controller.history.length,
          itemBuilder: (context, index) {
            final entry = controller.history[index];
            final imagePath = entry['imagePath'] as String?;
            final dateTime = DateTime.tryParse(entry['dateTime'] ?? '');

            if (imagePath == null ||
                !File(imagePath).existsSync() ||
                dateTime == null) {
              return const SizedBox.shrink();
            }

            return GestureDetector(
              onTap: () => _showDetectionDialog(context, entry),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 6.h),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(imagePath),
                        width: double.infinity,
                        height: 200.h,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      bottom: 8.h,
                      left: 8.w,
                      child: Container(
                        color: Colors.black54,
                        padding: EdgeInsets.symmetric(
                          horizontal: 6.w,
                          vertical: 2.h,
                        ),
                        child: MyWidget.normalText(
                          context,
                          "${dateTime.day}/${dateTime.month}/${dateTime.year} "
                          "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}",
                          Colors.white,
                          12.0,
                          FontWeight.bold,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8.h,
                      right: 8.w,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.white,
                            size: 18.0,
                          ),
                          onPressed: () => controller.deleteHistoryItem(index),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }),
      bottomNavigationBar: bottomNav(),
    );
  }
}
