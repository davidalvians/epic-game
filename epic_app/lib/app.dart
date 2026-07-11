// MaterialApp utama dengan tema global dan routing GetX
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:epic_app/core/constants/app_strings.dart';
import 'package:epic_app/core/routes/app_routes.dart';
import 'package:epic_app/core/theme/app_theme.dart';
import 'package:epic_app/core/bindings/initial_binding.dart';

/// Root widget aplikasi EPIC.
class EpicApp extends StatelessWidget {
  const EpicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      initialRoute: Routes.splash,
      getPages: AppRoutes.pages,
      initialBinding: InitialBinding(),
      defaultTransition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    );
  }
}
