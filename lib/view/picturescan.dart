import 'package:durian_leaf_disease_detector_new/controller/pictureScanController.dart';
import 'package:durian_leaf_disease_detector_new/service/yolo_detector.dart';
import 'package:durian_leaf_disease_detector_new/widget/myWitget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
// NOTE: Assuming LabelColors is in your scope, perhaps defined in yolo_detector.dart or similar.
// import '../service/yolo_detector.dart'; // Uncomment if LabelColors is here


class PictureScan extends StatelessWidget {
  const PictureScan({super.key});

  @override
  Widget build(BuildContext context) {
    // You should use Get.find if the controller is already initialized in a previous binding/page.
    // Use Get.put if this is the first time you are creating it.
    final controller = Get.put(PictureScanController());

    return Scaffold(
      appBar: appbar(context, 'picture_scan'.tr),
      body: Obx(() {
        final image = controller.selectedImage.value;

        if (image == null) {
          return Center(
            child: ElevatedButton.icon(
              onPressed: controller.pickImage,
              icon: const Icon(Icons.photo_library),
              label: MyWidget.normalText(
                context,
                'select_image'.tr,
                Colors.black,
                16.0,
                FontWeight.bold,
              ),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
              ),
            ),
          );
        }

        // Image exists -> use LayoutBuilder with reactive updates
        return LayoutBuilder(
          builder: (context, constraints) {
            return Obx(() {
              // The YOLO model uses a fixed input size of 640x640
              const double modelInputSize = 640.0;
              final imgWidth = modelInputSize;
              final imgHeight = modelInputSize;

              final isProcessing = controller.isProcessing.value;

              // 1. Calculate the size and position of the "Image" widget itself (using BoxFit.contain)

              final screenWidth = constraints.maxWidth;
              final screenHeight = constraints.maxHeight;

              final screenAspect = screenWidth / screenHeight;
              final imageAspect = imgWidth / imgHeight; // 1.0 (640/640)

              double displayWidth;
              double displayHeight;

              // Since both are 640x640, imageAspect is 1.0. This logic determines
              // the size of the image's container within the LayoutBuilder constraints.
              if (imageAspect > screenAspect) {
                // Image is wider than screen aspect (e.g., landscape screen)
                displayWidth = screenWidth;
                displayHeight = displayWidth / imageAspect;
              } else {
                // Image is taller than screen aspect (e.g., portrait screen)
                displayHeight = screenHeight;
                displayWidth = displayHeight * imageAspect;
              }

              // 2. Calculate the offset for the entire image container (centering)
              final containerOffsetX = (screenWidth - displayWidth) / 2;
              final containerOffsetY = (screenHeight - displayHeight) / 2;

              // 3. CRITICAL FIX: Calculate the scaling factor. This is correct as
              // the model result is 640x640 and the base display size is displayWidth/displayHeight
              final scaleX = displayWidth / imgWidth;
              final scaleY = displayHeight / imgHeight;

              return Stack(
                children: [
                  // Image (This is positioned at containerOffsetX/Y)
                  Positioned(
                    left: containerOffsetX,
                    top: containerOffsetY,
                    width: displayWidth,
                    height: displayHeight,
                    child: Image.file(image, fit: BoxFit.contain),
                  ),

                  // Detection boxes
                  if (!isProcessing && controller.results.isNotEmpty)
                    ...controller.results.map((r) {
                      final box = r['box'] as Rect;
                      final label = (r['label'] ?? '').toString().tr;
                      final conf = r['confidence'];
                      final color = LabelColors.getColor(r['label']);

                      // --- DEBUGGING ---
                      // Check if the calculated box is reasonable.
                      debugPrint('--- Box Data ---');
                      debugPrint(
                        'Model Box: L:${box.left}, T:${box.top}, W:${box.width}, H:${box.height}',
                      );
                      debugPrint('Scaling: S_x:$scaleX, S_y:$scaleY');
                      debugPrint(
                        'Container Offset: X:$containerOffsetX, Y:$containerOffsetY',
                      );
                      debugPrint(
                        'Result Box Pos: L:${box.left * scaleX}, T:${box.top * scaleY}, W:${box.width * scaleX}, H:${box.height * scaleY}',
                      );
                      // --- END DEBUGGING ---

                      // Position the box relative to the screen, accounting for the image container's offset.
                      return Positioned(
                        left: containerOffsetX + (box.left * scaleX),
                        top: containerOffsetY + (box.top * scaleY),
                        width: box.width * scaleX,
                        height: box.height * scaleY,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: color, width: 2.w),
                            color: color.withOpacity(0.1),
                          ),
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: Container(
                              color: color.withOpacity(0.9),
                              padding: EdgeInsets.symmetric(
                                horizontal: 4.w,
                                vertical: 2.h,
                              ),
                              child: Text(
                                "$label ${(conf * 100).toStringAsFixed(1)}%",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),

                  // Loading overlay
                  if (isProcessing)
                    const Positioned.fill(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              );
            });
          },
        );
      }),
      floatingActionButton: Obx(() {
        final isProcessing = controller.isProcessing.value;

        return FloatingActionButton(
          onPressed: isProcessing ? null : controller.pickImage,
          backgroundColor: isProcessing ? Colors.grey : null,
          child: const Icon(Icons.add_photo_alternate),
        );
      }),
    );
  }
}
