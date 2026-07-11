import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:epic_app/shared/controllers/session_controller.dart';
import 'package:epic_app/core/constants/app_assets.dart';

class AnimatedKnightWidget extends StatelessWidget {
  const AnimatedKnightWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final session = Get.find<SessionController>();
      final user = session.currentUser.value;

      String animatedAsset = AppAssets.epiBody;
      if (user != null) {
        if (user.karakterAktif == 'ipeh_default') {
          animatedAsset = AppAssets.ipehBody;
        }
      }

      return Image.asset(
        animatedAsset,
        height: 200, // Diperkecil agar tidak menutupi header profil
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return const SizedBox(
            height: 200,
            child: Icon(Icons.person, size: 80, color: Colors.grey),
          );
        },
      );
    });
  }
}
