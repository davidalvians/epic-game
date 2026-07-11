import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:epic_app/core/routes/app_routes.dart';
import 'package:epic_app/data/services/local_storage_service.dart';

class OnboardingController extends GetxController {
  final PageController pageController = PageController();
  final RxInt currentPage = 0.obs;
  final RxBool isLastPage = false.obs;

  void onPageChanged(int index) {
    currentPage.value = index;
    isLastPage.value = index == 2;
  }

  void nextPage() {
    if (isLastPage.value) {
      _finishOnboarding();
    } else {
      pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeIn,
      );
    }
  }

  void skip() {
    _finishOnboarding();
  }

  void _finishOnboarding() {
    // Set flag isFirstLaunch ke false
    Get.find<LocalStorageService>().setFirstLaunch(false);
    Get.offAllNamed(Routes.auth);
  }

  @override
  void onClose() {
    pageController.dispose();
    super.onClose();
  }
}
