import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../service/yolo_detector.dart';
import '../widget/myWitget.dart';

class DetectionPreview extends StatelessWidget {
  final File imageFile;
  final List<Map<String, dynamic>> results;
  final double originalWidth;
  final double originalHeight;

  const DetectionPreview({
    super.key,
    required this.imageFile,
    required this.results,
    required this.originalWidth,
    required this.originalHeight,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
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
              child: Image.file(imageFile, fit: BoxFit.contain),
            ),
            ...results.map((r) {
              final boxData = r['box'];
              final label = r['label'].tr.toString();
              final conf = (r['confidence'] ?? 0.0) as double;
              final color = LabelColors.getColor(label);

              final left = offsetX + boxData['left'] * scaleX;
              final top = offsetY + boxData['top'] * scaleY;
              final width = boxData['width'] * scaleX;
              final height = boxData['height'] * scaleY;

              return Positioned(
                left: left,
                top: top,
                width: width,
                height: height,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: color, width: 3.w),
                    color: color.withOpacity(0.15),
                  ),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Container(
                      color: color.withOpacity(0.9),
                      padding: EdgeInsets.symmetric(
                        horizontal: 6.w,
                        vertical: 4.h,
                      ),
                      child: MyWidget.normalText(
                        context,
                        "$label ${(conf * 100).toStringAsFixed(1)}%",
                        Colors.white,
                        13.sp,
                        FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }
}
