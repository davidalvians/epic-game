import 'package:get/get.dart';
import 'package:epic_app/core/routes/app_routes.dart';
import 'package:epic_app/core/utils/epic_snackbar.dart';
import 'package:epic_app/data/repositories/auth_repository.dart';
import 'package:epic_app/shared/controllers/session_controller.dart';

class AuthController extends GetxController {
  final AuthRepository _authRepo = Get.find<AuthRepository>();
  final SessionController _sessionController = Get.find<SessionController>();

  final RxBool isLoading = false.obs;

  /// Login dengan Google Sign-In.
  /// Jika user baru → redirect ke onboarding.
  /// Jika user lama dengan profil lengkap → redirect ke home.
  Future<void> signInWithGoogle() async {
    isLoading.value = true;
    try {
      final user = await _authRepo.signInWithGoogle();
      _sessionController.setUser(user);

      if (user.status == 'suspended' || !user.isActive) {
        Get.offAllNamed(Routes.suspended);
        return;
      }

      if (!user.isProfileComplete) {
        // User baru — perlu isi profil
        Get.offAllNamed(Routes.profileSetup);
      } else {
        // User lama — langsung ke home
        Get.offAllNamed(Routes.home);
      }
    } catch (e) {
      if (!e.toString().contains('dibatalkan')) {
        EpicSnackbar.error(
            'Ups!', e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      isLoading.value = false;
    }
  }

}
