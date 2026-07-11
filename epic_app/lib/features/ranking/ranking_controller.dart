import 'dart:async';
import 'package:epic_app/core/utils/epic_snackbar.dart';
import 'package:get/get.dart';
import 'package:epic_app/data/models/score_model.dart';
import 'package:epic_app/shared/controllers/session_controller.dart';
import 'package:epic_app/data/repositories/user_repository.dart';
import 'package:epic_app/data/repositories/kelas_repository.dart';

/// Controller untuk Papan Peringkat — real-time stream dari Firestore.
class RankingController extends GetxController {
  final SessionController _session = Get.find<SessionController>();
  final KelasRepository _kelasRepo = KelasRepository();
  final UserRepository _userRepo = UserRepository();

  // Mode: 0 = Global, 1 = Kelas
  final RxInt selectedTab = 0.obs;

  // Data
  final RxList<ScoreModel> globalScores = <ScoreModel>[].obs;
  final RxList<ScoreModel> kelasScores = <ScoreModel>[].obs;

  // Loading states
  final RxBool isLoadingGlobal = true.obs;
  final RxBool isLoadingKelas = true.obs;

  // Kelas Selection (jika ikut > 1 kelas)
  final RxString selectedKelasId = ''.obs;
  final RxList<Map<String, String>> myKelasList = <Map<String, String>>[].obs;

  // StreamSubscription management (prevent memory leaks)
  StreamSubscription? _globalSub;
  StreamSubscription? _kelasSub;
  StreamSubscription? _kelasListSub;
  Worker? _currentUserWorker;
  List<String> _lastKelasIds = [];

  String? get currentUserId => _session.currentUser.value?.uid;
  bool get isLoading => selectedTab.value == 0 ? isLoadingGlobal.value : isLoadingKelas.value;
  List<ScoreModel> get scores => selectedTab.value == 0 ? globalScores : kelasScores;

  @override
  void onInit() {
    super.onInit();
    _lastKelasIds = List<String>.from(_session.currentUser.value?.kelasIds ?? []);
    _listenGlobalLeaderboard();
    _initKelasLeaderboard();

    // Listen to current user changes so leaderboard updates when student joins/leaves a class
    _currentUserWorker = ever(_session.currentUser, (user) {
      if (user != null) {
        // Only re-init if the list of classes has actually changed to prevent infinite loop
        final ids = List<String>.from(user.kelasIds)..sort();
        final lastIds = List<String>.from(_lastKelasIds)..sort();
        if (ids.length != lastIds.length || !ids.every((id) => lastIds.contains(id))) {
          _lastKelasIds = List<String>.from(user.kelasIds);
          _initKelasLeaderboard();
        }
      } else {
        _lastKelasIds.clear();
        myKelasList.clear();
        kelasScores.clear();
        selectedKelasId.value = '';
        _kelasSub?.cancel();
        _kelasSub = null;
        _kelasListSub?.cancel();
        _kelasListSub = null;
      }
    });
  }

  void _listenGlobalLeaderboard() {
    _globalSub?.cancel();
    _globalSub = _userRepo.watchLeaderboard(limit: 100).listen(
      (users) {
        globalScores.assignAll(users);
        isLoadingGlobal.value = false;
      },
      onError: (e) {
        isLoadingGlobal.value = false;
        if (_session.isLoggedIn && !e.toString().contains('permission-denied')) {
          EpicSnackbar.error('Error', 'Gagal memuat papan peringkat global: $e');
        }
      },
    );
  }

  void _initKelasLeaderboard() {
    final user = _session.currentUser.value;
    if (user == null || user.kelasIds.isEmpty) {
      selectedTab.value = 0; // Force switch to Global leaderboard automatically!
      isLoadingKelas.value = false;
      myKelasList.clear();
      kelasScores.clear();
      selectedKelasId.value = '';
      _kelasSub?.cancel();
      _kelasSub = null;
      _kelasListSub?.cancel();
      _kelasListSub = null;
      return;
    }

    _kelasListSub?.cancel();
    isLoadingKelas.value = true;
    _kelasListSub = _kelasRepo.watchKelasByMurid(user.uid).listen(
      (kelasList) {
        final activeList = kelasList.where((k) => k.status == 'aktif').toList();
        if (activeList.isNotEmpty) {
          final newKelasData = activeList.map((k) => {'id': k.kelasId, 'name': k.namaKelas}).toList();
          final bool listChanged = myKelasList.length != newKelasData.length ||
              !myKelasList.every((existing) => newKelasData.any((n) => n['id'] == existing['id'] && n['name'] == existing['name']));

          if (listChanged) {
            myKelasList.assignAll(newKelasData);
            if (selectedKelasId.value.isEmpty ||
                !myKelasList.any((k) => k['id'] == selectedKelasId.value)) {
              selectedKelasId.value = activeList.first.kelasId;
            }
            _listenKelasLeaderboard(selectedKelasId.value);
          } else {
            if (selectedKelasId.value.isEmpty && myKelasList.isNotEmpty) {
              selectedKelasId.value = myKelasList.first['id']!;
              _listenKelasLeaderboard(selectedKelasId.value);
            }
          }
        } else {
          selectedTab.value = 0; // Force switch to Global leaderboard automatically!
          isLoadingKelas.value = false;
          myKelasList.clear();
          kelasScores.clear();
          selectedKelasId.value = '';
          _kelasSub?.cancel();
          _kelasSub = null;
        }
      },
      onError: (e) {
        isLoadingKelas.value = false;
      },
    );
  }

  void _listenKelasLeaderboard(String kelasId) {
    // Cancel stream lama sebelum buka stream baru
    _kelasSub?.cancel();
    if (kelasScores.isEmpty) {
      isLoadingKelas.value = true;
    }

    _kelasSub = _kelasRepo.watchLeaderboardKelas(kelasId).listen(
      (dataList) {
        final List<ScoreModel> mappedScores = dataList.map((data) {
          final nama = data['namaPanggilan']?.toString().isNotEmpty == true
              ? data['namaPanggilan']
              : data['namaLengkap'];
          return ScoreModel(
            uid: data['uid'] ?? '',
            nama: nama ?? '',
            username: data['username'] ?? '',
            avatarUrl: data['avatarUrl']?.toString().isNotEmpty == true
                ? data['avatarUrl']
                : null,
            namaSekolah: data['namaSekolah'] ?? '',
            totalPoin: (data['poin'] as num?)?.toInt() ?? 0,
            gameSelesai: (data['gameSelesai'] as num?)?.toInt() ?? 0,
          );
        }).toList();

        kelasScores.assignAll(mappedScores);
        isLoadingKelas.value = false;
      },
      onError: (e) {
        isLoadingKelas.value = false;
      },
    );
  }

  void changeKelas(String newKelasId) {
    if (newKelasId == selectedKelasId.value) return;
    selectedKelasId.value = newKelasId;
    _listenKelasLeaderboard(newKelasId);
  }

  /// Dipanggil setelah user bergabung ke kelas baru — refresh dropdown kelas
  Future<void> refreshKelasLeaderboard() async {
    _initKelasLeaderboard();
  }

  @override
  void refresh() {
    if (selectedTab.value == 0) {
      isLoadingGlobal.value = true;
      _listenGlobalLeaderboard();
    } else if (selectedKelasId.value.isNotEmpty) {
      isLoadingKelas.value = true;
      _listenKelasLeaderboard(selectedKelasId.value);
    }
  }

  @override
  void onClose() {
    _currentUserWorker?.dispose();
    _globalSub?.cancel();
    _kelasSub?.cancel();
    _kelasListSub?.cancel();
    super.onClose();
  }
}
