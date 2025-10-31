import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// ignore: unused_element
Widget fancyScanOption({
  required IconData icon,
  required String label,
  required VoidCallback onPressed,
}) {
  return Container(
    width: 120.0,
    height: 120.0,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20.0.r),
      boxShadow: [
        BoxShadow(
          color: Colors.black12,
          blurRadius: 10.0,
          spreadRadius: 2.0,
          offset: Offset(0, 5.0),
        ),
      ],
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(20.0.r),
      onTap: onPressed,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40.0, color: Colors.blueAccent),
          SizedBox(height: 10.0.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.0,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
