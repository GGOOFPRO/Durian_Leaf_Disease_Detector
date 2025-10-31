
import 'package:durian_leaf_disease_detector_new/widget/bottomnav.dart';
import 'package:durian_leaf_disease_detector_new/widget/fancybutton.dart';
import 'package:durian_leaf_disease_detector_new/widget/myWitget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appbar(context, 'home'.tr),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                fancyScanOption(
                  icon: Icons.camera_alt,
                  label: 'real_time_scan'.tr,
                  onPressed: () => Get.toNamed('/realtimescan'),
                ),
                fancyScanOption(
                  icon: Icons.image,
                  label: 'picture_scan'.tr,
                  onPressed: () => Get.toNamed('/picturescan'),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: bottomNav(),
    );
  }
}
