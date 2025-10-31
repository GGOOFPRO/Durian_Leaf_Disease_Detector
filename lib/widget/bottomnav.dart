// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

Widget bottomNav() {
  return Container(
    height: 80.0.h,
    padding: EdgeInsets.only(top: 5.0.h),
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        navItem(
          icon: Icons.home,
          label: 'home'.tr,
          onTap: () => Get.offAllNamed('/home'),
        ),
        navItem(
          icon: Icons.history,
          label: 'history'.tr,
          onTap: () => Get.offAllNamed('/history'),
        ),
        navItem(
          icon: Icons.settings,
          label: 'settings'.tr,
          onTap: () => Get.offAllNamed('/setting'),
        ),
      ],
    ),
  );
}

Widget navItem({
  required IconData icon,
  required String label,
  required VoidCallback onTap,
}) {
  return Material(
    color: Colors.blue.shade50,
    borderRadius: BorderRadius.circular(8.0.r),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.r),
      splashColor: Colors.blue.withOpacity(0.15),
      highlightColor: Colors.blue.withOpacity(0.05),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 4.0.h, horizontal: 8.0.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 30.0, color: Colors.blue), // smaller icon
            SizedBox(height: 1.5.h),
            Text(
              label,
              style: TextStyle(
                fontSize: 15.0,
                color: Colors.blue,
              ), // smaller text
            ),
          ],
        ),
      ),
    ),
  );
}
