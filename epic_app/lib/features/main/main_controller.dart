import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Controller untuk shell utama - mengontrol tab yang aktif dan transisi PageView.
class MainController extends GetxController {
  final RxInt currentIndex = 0.obs;
  late PageController pageController;

  @override
  void onInit() {
    super.onInit();
    pageController = PageController(initialPage: currentIndex.value);
  }

  void changeTab(int index) {
    if (currentIndex.value == index) return;
    currentIndex.value = index;
    if (pageController.hasClients) {
      pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  void onClose() {
    pageController.dispose();
    super.onClose();
  }

  // Index helper
  bool get isHome => currentIndex.value == 0;
  bool get isRanking => currentIndex.value == 1;
  bool get isGaleri => currentIndex.value == 2;
  bool get isAvatar => currentIndex.value == 3;
  bool get isProfil => currentIndex.value == 4;
}
