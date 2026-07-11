import 'package:get/get.dart';
import 'package:epic_app/data/services/local_storage_service.dart';

class GameSettingsController extends GetxController {
  final LocalStorageService _storage = Get.find<LocalStorageService>();

  var isSoundEnabled = true.obs;

  @override
  void onInit() {
    super.onInit();
    isSoundEnabled.value = _storage.isSoundEnabled;
  }

  void toggleSound(bool value) {
    isSoundEnabled.value = value;
    _storage.setSoundEnabled(value);
  }
}
