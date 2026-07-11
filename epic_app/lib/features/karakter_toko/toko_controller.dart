import 'package:epic_app/core/utils/epic_snackbar.dart';
import 'package:get/get.dart';
import 'package:epic_app/data/models/character_model.dart';
import 'package:epic_app/shared/controllers/session_controller.dart';
import 'package:epic_app/data/repositories/user_repository.dart';

class TokoController extends GetxController {
  final SessionController _session = Get.find<SessionController>();
  final UserRepository _userRepo = UserRepository();

  final RxList<CharacterModel> characters = <CharacterModel>[].obs;
  final RxBool isLoading = true.obs;
  
  /// Karakter yang sedang dilihat pratinjaunya.
  final Rxn<CharacterModel> selectedPreviewChar = Rxn<CharacterModel>();

  /// Poin user saat ini.
  int get userPoin => _session.currentUser.value?.poin ?? 0;

  @override
  void onInit() {
    super.onInit();
    loadCharacters();
  }

  void loadCharacters() async {
    isLoading.value = true;
    try {
      final chars = await _userRepo.getCharacters();
      characters.value = chars;
      
      // Set default pratinjau ke karakter aktif saat ini
      final activeId = _session.currentUser.value?.karakterAktif;
      selectedPreviewChar.value = chars.firstWhereOrNull((c) => c.id == activeId) ?? chars.firstOrNull;
    } catch (e) {
      EpicSnackbar.error('Error', 'Gagal memuat karakter: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void selectPreviewChar(CharacterModel character) {
    selectedPreviewChar.value = character;
  }

  bool isOwned(String characterId) {
    return _session.currentUser.value?.karakterDimiliki.contains(characterId) ?? false;
  }

  /// Ganti karakter aktif ke karakter yang sudah dimiliki.
  Future<void> pakaiKarakter(String characterId) async {
    final user = _session.currentUser.value;
    if (user == null) return;
    if (!isOwned(characterId)) return;

    try {
      final updatedUser = await _userRepo.setKarakterAktif(user, characterId);
      _session.updateUser(updatedUser);
      EpicSnackbar.success('Yeay!', 'Karakter berhasil diganti!');
    } catch (e) {
      EpicSnackbar.error('Ups!', e.toString());
    }
  }

  /// Unlock karakter jika poin user sudah cukup (threshold-based, bukan beli).
  Future<void> unlockKarakter(CharacterModel character) async {
    final user = _session.currentUser.value;
    if (user == null) return;

    if (user.poin < character.poinUnlock) {
      EpicSnackbar.error(
        'Ups!',
        'Kamu butuh ${character.poinUnlock} poin untuk membuka karakter ini. '
        'Saat ini kamu punya ${user.poin} poin.',
      );
      return;
    }

    try {
      final updatedUser = await _userRepo.unlockKarakter(user, character.id);
      _session.updateUser(updatedUser);
      EpicSnackbar.success(
        'Selamat! 🎉',
        'Karakter ${character.nama} berhasil dibuka!',
      );
    } catch (e) {
      EpicSnackbar.error('Ups!', e.toString().replaceAll('Exception: ', ''));
    }
  }
}
