
import 'package:durian_leaf_disease_detector_new/widget/bottomnav.dart';
import 'package:durian_leaf_disease_detector_new/widget/myWitget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appbar(context, 'settings'.tr),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: MyWidget.normalText(
              context,
              'change_language'.tr,
              Colors.black,
              16.0,
              FontWeight.normal,
            ),
            subtitle: MyWidget.normalText(
              context,
              Get.locale?.languageCode == 'th' ? 'ไทย' : 'English',
              Colors.grey,
              14.0,
              FontWeight.normal,
            ),
            value: Get.locale?.languageCode == 'th',
            onChanged: (value) {
              if (value) {
                Get.updateLocale(const Locale('th', 'TH'));
              } else {
                Get.updateLocale(const Locale('en', 'US'));
              }
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.camera_alt, color: Colors.blue),
            title: MyWidget.normalText(
              context,
              'camera_permission'.tr,
              Colors.black,
              16.0,
              FontWeight.bold,
            ),
            subtitle: MyWidget.normalText(
              context,
              'camera_permission_desc'.tr,
              Colors.grey,
              14.0,
              FontWeight.normal,
            ),
            onTap: () async => await openAppSettings(),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.sd_storage, color: Colors.orange),
            title: MyWidget.normalText(
              context,
              'storage_permission'.tr,
              Colors.black,
              16.0,
              FontWeight.bold,
            ),
            subtitle: MyWidget.normalText(
              context,
              'storage_permission_desc'.tr,
              Colors.grey,
              14.0,
              FontWeight.normal,
            ),
            onTap: () async => await openAppSettings(),
          ),
        ],
      ),
      bottomNavigationBar: bottomNav(),
    );
  }
}
