// Session Controller untuk mengelola state global user (berbasis Firebase)
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:epic_app/data/models/drawing_session_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:epic_app/core/services/draft_service.dart';
import 'package:flutter/foundation.dart';
import 'package:epic_app/data/models/user_model.dart';
import 'package:epic_app/data/repositories/auth_repository.dart';
import 'package:epic_app/data/repositories/user_repository.dart';
import 'package:epic_app/core/routes/app_routes.dart';
import 'package:epic_app/core/utils/epic_notification.dart';
import 'package:epic_app/features/kelas/kelas_controller.dart'
    as epic_app_kelas_controller;
import 'package:epic_app/data/repositories/misi_harian_repository.dart';
import 'package:epic_app/core/services/app_config_service.dart';

/// Controller global untuk mengelola sesi pengguna menggunakan Firebase Auth.
class SessionController extends GetxController {
  final AuthRepository _authRepo = Get.find<AuthRepository>();
  final UserRepository _userRepo = UserRepository();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _lastFirebaseUid;

  StreamSubscription? _userSub;

  // Draft state - bound to DraftService to resolve SharedPreferences vs File System conflict
  final RxList<DrawingSessionModel> activeDrafts = <DrawingSessionModel>[].obs;

  // Observable state
  final RxBool isLoading = true.obs;
  final Rx<UserModel?> currentUser = Rx<UserModel?>(null);

  // Observable state untuk active kelas (Bug 7)
  final RxString activeKelasId = ''.obs;

  bool get isLoggedIn => currentUser.value != null;
  UserModel? get user => currentUser.value;

  /// Role helpers
  bool get isMurid => currentUser.value?.isMurid ?? true;
  bool get isGuru => currentUser.value?.isGuru ?? false;
  bool get isAdmin => currentUser.value?.isAdmin ?? false;

  bool get isGuruVerified => currentUser.value?.isGuruVerified ?? false;
  bool get isGuruApproved => isGuruVerified;
  bool get isGuruPending => currentUser.value?.isGuruPending ?? false;
  bool get isGuruRejected => currentUser.value?.isGuruRejected ?? false;
  bool get isProfileComplete => currentUser.value?.isProfileComplete ?? false;
  bool get hasGeminiPermission => currentUser.value?.geminiPermission ?? false;

  /// Nyawa efektif (sudah diperhitungkan reset harian).
  int get nyawaEfektif => currentUser.value?.nyawaEfektif ?? 0;

  /// Total poin user saat ini.
  int get poin => currentUser.value?.poin ?? 0;

  @override
  void onInit() {
    super.onInit();

    // ROOT-FIX-1: Selalu mulai dengan isLoading = true.
    // Jangan pernah set false sebelum authStateChanges() pertama kali merespons.
    // Firebase Auth membutuhkan waktu async untuk restore token dari storage lokal
    // setelah app di-kill dari Recent Apps. Jika kita set false terlalu cepat,
    // splash screen akan navigasi ke onboarding meskipun user sebenarnya login.
    isLoading.value = true;

    final initialUser = _auth.currentUser;
    if (initialUser != null) {
      _lastFirebaseUid = initialUser.uid;
      // authStateChanges() adalah satu-satunya sumber kebenaran auth state.
      _auth.authStateChanges().listen(_onAuthStateChanged);
    } else {
      // FIX: Jika initialUser null di Android, Firebase Auth mungkin kehilangan session
      // Coba restore secara transparan dengan Google Sign In sebelum menyatakan logout.
      _autoRestoreSession();
    }

    // Safety timeout: jika authStateChanges tidak merespons dalam 10 detik
    // (sangat tidak normal), hentikan loading agar app tidak stuck di splash.
    Future.delayed(const Duration(seconds: 10), () {
      if (isLoading.value) {
        debugPrint(
            '⚠️ Safety timeout: isLoading masih true setelah 10 detik, dihentikan paksa.');
        isLoading.value = false;
      }
    });
  }

  Future<void> _autoRestoreSession() async {
    debugPrint('🔄 Menjalankan _autoRestoreSession...');
    final restored = await _authRepo.restoreSessionIfPossible();

    // Listen authStateChanges setelah auto restore selesai (atau gagal)
    _auth.authStateChanges().listen(_onAuthStateChanged);

    if (!restored) {
      // Jika memang tidak bisa direstore, akhiri loading.
      if (_auth.currentUser == null) {
        isLoading.value = false;
      }
    }
  }

  // Load active kelas ID from SharedPreferences (Bug 7)
  Future<void> loadActiveKelasId() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = currentUser.value?.uid;
    if (uid != null) {
      activeKelasId.value = prefs.getString('active_kelas_id_$uid') ?? '';
    }
  }

  // Set active kelas ID (Bug 7)
  Future<void> setActiveKelasId(String kelasId) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = currentUser.value?.uid;
    if (uid != null) {
      activeKelasId.value = kelasId;
      await prefs.setString('active_kelas_id_$uid', kelasId);
    }
  }

  // _loadInitialUser dihapus — logika dipindahkan ke _onAuthStateChanged
  // untuk menghindari duplikasi dan race condition.

  /// Memulai subscription Firestore untuk perubahan data user
  void _listenToUserChanges(String uid) {
    _userSub?.cancel();
    _userSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((doc) async {
      if (!doc.exists) {
        debugPrint('⚠️ Akun ini telah dihapus dari database!');
        await logout();
        EpicNotification.error(
          'Sesi Berakhir 🔒',
          'Akun Anda tidak lagi terdaftar atau telah dihapus.',
          duration: const Duration(seconds: 5),
        );
        return;
      }

      final data = doc.data();
      if (data != null) {
        final String status = data['status']?.toString() ?? 'active';
        final bool isActive = data['isActive'] ?? true;
        if (status == 'suspended' || !isActive) {
          debugPrint('⚠️ Akun ini telah ditangguhkan (suspend) via stream!');
          final freshUser = UserModel.fromJson({...data, 'uid': uid});
          currentUser.value = freshUser;
          Get.offAllNamed(Routes.suspended);
          return;
        }

        final freshUser = UserModel.fromJson({...data, 'uid': uid});
        currentUser.value = freshUser;
        final revokedDeviceIds = data['revokedDeviceIds'] is List
            ? Set<String>.from(
                (data['revokedDeviceIds'] as List).map((entry) => '$entry'),
              )
            : <String>{};
        _checkIfDeviceKicked(revokedDeviceIds);
      }
    }, onError: (e) async {
      debugPrint('⚠️ Error pada user sub stream listener: $e');
      await logout();
      EpicNotification.error(
        'Akun Ditangguhkan 🔒',
        'Akun Anda telah ditangguhkan oleh Administrator.',
        duration: const Duration(seconds: 8),
      );
    });
  }

  /// Dipanggil otomatis setiap kali status auth Firebase berubah.
  /// Ini adalah satu-satunya entry point untuk memuat data user saat startup.
  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    final uid = firebaseUser?.uid;

    // Abaikan jika UID sama persis (sudah diproses atau sedang diproses)
    if (uid != null && uid == _lastFirebaseUid) {
      // Jika sudah ada user tapi isLoading masih true (startup pertama fast-path),
      // artinya kita perlu tetap load dari Firestore.
      // Jika isLoading sudah false, berarti sudah selesai — skip.
      if (!isLoading.value) return;
    }
    _lastFirebaseUid = uid;

    _userSub?.cancel();
    _userSub = null;

    if (firebaseUser == null) {
      // ROOT-FIX-3: Firebase Auth benar-benar tidak punya user (explicit signout)
      // Baru boleh clear state.
      currentUser.value = null;
      activeKelasId.value = '';

      // Jika auto restore masih berjalan, JANGAN set isLoading = false di sini
      isLoading.value = false;
      return;
    }

    // Firebase Auth punya user — muat profil dari Firestore
    isLoading.value = true;
    try {
      final UserModel? userModel = await _authRepo.getCurrentUser();

      if (userModel == null) {
        // ROOT-FIX-3: JANGAN panggil logout() di sini!
        // getCurrentUser() bisa return null karena:
        //   a) Firestore offline / jaringan buruk
        //   b) Cache belum tersedia
        // Memanggil logout() akan menghapus Firebase Auth token via _auth.signOut(),
        // yang menyebabkan user harus login ulang dari awal setiap restart app.
        //
        // Solusi: Set currentUser = null tanpa clear Firebase token.
        // Splash screen akan cek Firebase Auth langsung dan navigasi ke auth screen
        // (bukan onboarding), sehingga user bisa retry tanpa Google Sign-In lagi.
        debugPrint(
            '⚠️ Profil Firestore tidak dapat dimuat — Firebase Auth masih valid. TIDAK logout.');
        currentUser.value = null;
        return;
      }

      if (userModel.status == 'suspended' || !userModel.isActive) {
        debugPrint('⚠️ Akun ini telah ditangguhkan!');
        currentUser.value = userModel;
        Get.offAllNamed(Routes.suspended);
        return;
      }

      // Sinkronisasi nyawa & keaktifan (background, non-blocking untuk startup)
      () async {
        try {
          if (Get.isRegistered<AppConfigService>()) {
            await Get.find<AppConfigService>()
                .whenReady
                .timeout(const Duration(seconds: 2), onTimeout: () {});
          }
          final syncedUser = await _userRepo.syncNyawa(userModel);
          if (currentUser.value?.uid == syncedUser.uid) {
            currentUser.value = syncedUser;
          }
        } catch (e) {
          debugPrint('⚠️ syncNyawa error: $e');
        }
      }();
      if (userModel.isMurid) {
        () async {
          try {
            await _userRepo.updateLastActive(userModel.uid);
          } catch (e) {
            debugPrint('⚠️ updateLastActive error: $e');
          }
        }();
        () async {
          try {
            await MisiHarianRepository()
                .incrementByType(uid: userModel.uid, tipe: 'login_streak');
          } catch (e) {
            debugPrint('⚠️ login_streak error: $e');
          }
        }();
      }

      // Load kelas dan register device (background)
      loadActiveKelasId();
      _registerOrUpdateCurrentDevice(firebaseUser.uid);

      // Mulai streaming perubahan data user dari Firestore
      _listenToUserChanges(firebaseUser.uid);

      // Set user aktif — ini yang ditunggu splash screen
      currentUser.value = userModel;
    } catch (e) {
      debugPrint('Error _onAuthStateChanged: $e');
      currentUser.value = null;
    } finally {
      isLoading.value = false;
    }
  }

  /// Set user aktif secara langsung (setelah login/register berhasil).
  void setUser(UserModel user) {
    currentUser.value = user;
  }

  /// Update data user aktif (misal setelah dapat poin, kurangi nyawa, dll).
  void updateUser(UserModel updatedUser) {
    if (isLoggedIn && currentUser.value?.uid == updatedUser.uid) {
      currentUser.value = updatedUser;
    }
  }

  /// Kurangi nyawa user (saat timer habis). Throws jika nyawa habis.
  Future<void> gunakanNyawa() async {
    final user = currentUser.value;
    if (user == null) throw Exception('User belum login!');

    final updatedUser = await _userRepo.gunakanNyawa(user);
    currentUser.value = updatedUser;
  }

  /// Tambah poin setelah menyelesaikan game.
  Future<void> tambahPoin(int poinBaru) async {
    final user = currentUser.value;
    if (user == null) return;

    final updatedUser = await _userRepo.tambahPoin(user, poinBaru);
    currentUser.value = updatedUser;
  }

  /// Refresh data user dari Firestore (setelah poin/data berubah).
  Future<void> refreshUser() async {
    final user = currentUser.value;
    if (user == null) return;
    try {
      final fresh = await _userRepo.getUser(user.uid);
      if (fresh != null) currentUser.value = fresh;
    } catch (_) {
      // Silent fail
    }
  }

  // --- Draft Management (Bug 8) ---

  /// Memuat semua draft aktif (status=draft) dari DraftService
  Future<void> loadActiveDrafts() async {
    try {
      if (Get.isRegistered<DraftService>()) {
        final draftService = Get.find<DraftService>();
        await draftService.loadAllDrafts();
      }
    } catch (e) {
      debugPrint('Error loading active drafts: $e');
    }
  }

  /// Menyimpan atau mengupdate draft menggunakan DraftService
  Future<void> saveDraft(DrawingSessionModel draft) async {
    try {
      if (Get.isRegistered<DraftService>()) {
        final draftService = Get.find<DraftService>();
        await draftService.saveDraft(draft);
      }
    } catch (e) {
      debugPrint('Error saving draft: $e');
    }
  }

  /// Logout dan kembali ke auth screen.
  // --- Keamanan Akun Sesi & Device Sync ---

  bool _isKickedChecking = false;

  Future<void> _checkIfDeviceKicked(Set<String> revokedDeviceIds) async {
    if (_isKickedChecking) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? deviceId = prefs.getString('epic_device_unique_id');
      if (deviceId == null) return; // Device ID belum dibuat, lewati

      // Logout hanya jika ada pencabutan eksplisit dari server. Daftar device
      // yang belum terbentuk saat startup bukan lagi dianggap sebagai kick.
      if (revokedDeviceIds.contains(deviceId)) {
        _isKickedChecking = true;
        debugPrint(
            '⚠️ Perangkat ini ($deviceId) telah dikeluarkan dari Firestore dari jauh!');

        // Hentikan sesi dan logout instan
        await prefs.remove('epic_device_unique_id');
        await logout();

        // Tampilkan notifikasi pop-up pemberitahuan sesi berakhir
        EpicNotification.warning(
          'Sesi Berakhir 🔒',
          'Akun Anda telah dikeluarkan dari perangkat ini dari jauh.',
          duration: const Duration(seconds: 5),
        );
        _isKickedChecking = false;
      }
    } catch (e) {
      debugPrint('Error checking device kick status: $e');
    }
  }

  Future<void> _registerOrUpdateCurrentDevice(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Dapatkan atau buat unique device ID
      String? deviceId = prefs.getString('epic_device_unique_id');
      if (deviceId == null) {
        final random = Random.secure();
        final parts = List.generate(
            4, (_) => random.nextInt(1000000).toString().padLeft(6, '0'));
        deviceId = 'DEV-${parts.join("-")}';
        await prefs.setString('epic_device_unique_id', deviceId);
      }

      final String deviceName = await _getDeviceName();
      final callable = FirebaseFunctions.instance.httpsCallable(
        'registerDeviceSession',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );
      final result = await callable.call<Map<String, dynamic>>({
        'deviceId': deviceId,
        'deviceName': deviceName,
      });
      final revoked = result.data['revoked'] == true;

      if (revoked) {
        await prefs.remove('epic_device_unique_id');
        await logout();
        EpicNotification.warning(
          'Sesi Berakhir 🔒',
          'Perangkat ini telah dikeluarkan dari akun.',
          duration: const Duration(seconds: 5),
        );
        return;
      }

      debugPrint(
          '📱 Perangkat aktif berhasil didaftarkan: $deviceName ($deviceId)');
    } catch (e) {
      debugPrint('⚠️ Gagal mendaftarkan perangkat aktif ke Firestore: $e');
    }
  }

  Future<String> _getDeviceName() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    try {
      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        return webInfo.browserName.name.toUpperCase();
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        final brand = androidInfo.brand.capitalizeFirst ?? '';
        return '$brand ${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.name;
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        return windowsInfo.computerName;
      } else if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        return macInfo.computerName;
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        return linuxInfo.name;
      }
    } catch (e) {
      debugPrint('Gagal mengambil nama perangkat: $e');
    }
    return 'Perangkat Aktif';
  }

  Future<void> logout() async {
    isLoading.value = true;
    _userSub?.cancel();
    _userSub = null;
    try {
      await _removeCurrentDeviceRegistration();
      await _authRepo.logout();
      currentUser.value = null;

      // Hapus controller yang menyimpan state user sebelumnya
      if (Get.isRegistered<epic_app_kelas_controller.KelasController>()) {
        Get.delete<epic_app_kelas_controller.KelasController>(force: true);
      }

      Get.offAllNamed(Routes.auth);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _removeCurrentDeviceRegistration() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('epic_device_unique_id');
      if (deviceId == null) return;

      final callable = FirebaseFunctions.instance.httpsCallable(
        'unregisterDeviceSession',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
      );
      await callable.call<void>({'deviceId': deviceId});
    } catch (error) {
      debugPrint('⚠️ Gagal menutup registrasi perangkat saat logout: $error');
    }
  }

  @override
  void onClose() {
    _userSub?.cancel();
    activeDrafts.clear();
    super.onClose();
  }
}
