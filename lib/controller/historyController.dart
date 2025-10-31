import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryController extends GetxController {
  final RxList<Map<String, dynamic>> history = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    loadHistory();
  }

  Future<void> loadHistory() async {
    isLoading.value = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList('detection_history') ?? [];

      final decodedHistory = <Map<String, dynamic>>[];
      for (var e in stored) {
        try {
          decodedHistory.add(jsonDecode(e) as Map<String, dynamic>);
        } catch (ex) {
          debugPrint("❌ Skipped invalid history entry: $ex");
        }
      }

      history.assignAll(decodedHistory.reversed);
      debugPrint("✅ Loaded history items: ${history.length}");
    } catch (e) {
      debugPrint("❌ Failed to load history: $e");
      history.clear();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> deleteHistoryItem(int uiIndex) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('detection_history') ?? [];

    if (uiIndex < 0 || uiIndex >= history.length) return;

    final actualIndex = stored.length - 1 - uiIndex; // map UI index to stored
    stored.removeAt(actualIndex);

    await prefs.setStringList('detection_history', stored);

    history.removeAt(uiIndex); // UI updates instantly
  }
}
