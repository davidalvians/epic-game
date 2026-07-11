import 'package:get/get.dart';
import 'package:epic_app/data/repositories/auth_repository.dart';
import 'package:epic_app/shared/controllers/session_controller.dart';
import 'package:epic_app/core/services/audio_service.dart';
import 'package:epic_app/core/services/draft_service.dart';
import 'package:epic_app/core/services/ai_scoring_service.dart';
import 'package:epic_app/core/services/app_config_service.dart';

/// Binding awal yang meng-inject semua controller dan service.
class InitialBinding extends Bindings {
  @override
  void dependencies() {
    // Konfigurasi sistem dari admin panel — HARUS didaftarkan pertama
    // agar nilai maxNyawa, timer, dll sudah tersedia sebelum dipakai
    Get.put<AppConfigService>(AppConfigService(), permanent: true);

    // Global repositories
    Get.put<AuthRepository>(AuthRepository(), permanent: true);

    // Global services
    Get.put<AudioService>(AudioService(), permanent: true);

    // Global controllers
    Get.put<SessionController>(SessionController(), permanent: true);
    Get.put<DraftService>(DraftService(), permanent: true);
    Get.put<AIScoringService>(AIScoringService(), permanent: true);
  }
}
