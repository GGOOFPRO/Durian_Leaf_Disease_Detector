import 'package:durian_leaf_disease_detector_new/controller/historyController.dart';
import 'package:durian_leaf_disease_detector_new/service/translation.dart';
import 'package:durian_leaf_disease_detector_new/view/history.dart';
import 'package:durian_leaf_disease_detector_new/view/home.dart';
import 'package:durian_leaf_disease_detector_new/view/picturescan.dart';
import 'package:durian_leaf_disease_detector_new/view/realtimescan.dart';
import 'package:durian_leaf_disease_detector_new/view/setting.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize your HistoryController once and make it permanent
  Get.put(HistoryController(), permanent: true);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: Size(360, 690),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return GetMaterialApp(
          translations: MyTranslations(),
          locale: Locale('th', 'TH'),
          fallbackLocale: Locale('en', 'US'),
          debugShowCheckedModeBanner: false,
          title: 'durian_leaf_diseases_detector',
          initialRoute: '/home',
          getPages: [
            GetPage(name: '/home', page: () => Home()),
            GetPage(name: '/history', page: () => History()),
            GetPage(name: '/realtimescan', page: () => RealtimeScan()),
            GetPage(name: '/picturescan', page: () => PictureScan()),
            GetPage(name: '/setting', page: () => SettingsPage()),
          ],
        );
      },
    );
  }
}
