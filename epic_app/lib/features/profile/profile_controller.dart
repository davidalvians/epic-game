import 'package:get/get.dart';
import 'package:epic_app/data/models/user_model.dart';
import 'package:epic_app/shared/controllers/session_controller.dart';
import 'package:epic_app/core/constants/app_strings.dart';

class ProfileController extends GetxController {
  final SessionController _session = Get.find<SessionController>();

  UserModel? get user => _session.currentUser.value;

  void logout() {
    Get.defaultDialog(
      title: 'Keluar',
      middleText: AppStrings.logoutConfirm,
      textConfirm: 'Ya',
      textCancel: 'Tidak',
      onConfirm: () {
        Get.back();
        _session.logout();
      },
    );
  }
}
