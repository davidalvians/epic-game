import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:epic_app/core/utils/epic_snackbar.dart';
import 'package:epic_app/core/constants/app_colors.dart';
import 'package:epic_app/core/constants/app_fonts.dart';
import 'package:epic_app/data/models/kelas_model.dart';
import 'package:epic_app/data/models/user_model.dart';
import 'package:epic_app/data/repositories/kelas_repository.dart';
import 'package:epic_app/data/repositories/user_repository.dart';
import 'package:epic_app/data/repositories/artwork_repository.dart';
import 'package:epic_app/shared/controllers/session_controller.dart';
import 'package:epic_app/features/ranking/ranking_controller.dart';
import 'package:epic_app/core/routes/app_routes.dart';

/// Controller untuk fitur kelas (join kelas, lihat daftar kelas, leaderboard).
class KelasController extends GetxController {
  final KelasRepository _kelasRepo = KelasRepository();
  final SessionController _session = Get.find<SessionController>();

  // Observable state
  final RxList<KelasModel> kelasList = <KelasModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isJoining = false.obs;
  final kodeKelasController = TextEditingController();
  bool isFromKelasScreen = false;

  StreamSubscription? _kelasSub;

  @override
  void onInit() {
    super.onInit();
    _setupRealtimeKelasListener();
  }

  void _setupRealtimeKelasListener() {
    // Listen to currentUser so when login/logout/role changes, we watch the correct stream
    ever(_session.currentUser, (user) {
      _kelasSub?.cancel();
      _kelasSub = null;
      if (user == null) {
        kelasList.clear();
        return;
      }

      isLoading.value = true;
      if (user.role == 'guru') {
        _kelasSub = _kelasRepo.watchKelasByGuru(user.uid).listen(
          (list) {
            kelasList.assignAll(list);
            isLoading.value = false;
          },
          onError: (e) {
            isLoading.value = false;
          },
        );
      } else {
        _kelasSub = _kelasRepo.watchKelasByMurid(user.uid).listen(
          (list) {
            kelasList.assignAll(list);
            isLoading.value = false;
            _syncMuridKelasIds(user, list);
          },
          onError: (e) {
            isLoading.value = false;
          },
        );
      }
    });

    // Initial trigger since currentUser might already be loaded
    if (_session.currentUser.value != null) {
      final user = _session.currentUser.value!;
      isLoading.value = true;
      if (user.role == 'guru') {
        _kelasSub = _kelasRepo.watchKelasByGuru(user.uid).listen(
          (list) {
            kelasList.assignAll(list);
            isLoading.value = false;
          },
          onError: (e) {
            isLoading.value = false;
          },
        );
      } else {
        _kelasSub = _kelasRepo.watchKelasByMurid(user.uid).listen(
          (list) {
            kelasList.assignAll(list);
            isLoading.value = false;
            _syncMuridKelasIds(user, list);
          },
          onError: (e) {
            isLoading.value = false;
          },
        );
      }
    }
  }

  /// Muat daftar kelas secara manual (jika diperlukan refresh manual)
  Future<void> loadKelas() async {
    final user = _session.currentUser.value;
    if (user == null) return;

    isLoading.value = true;
    try {
      List<KelasModel> list;
      if (user.role == 'guru') {
        list = await _kelasRepo.getKelasByGuru(user.uid);
      } else {
        list = await _kelasRepo.getKelasByMurid(user.uid);
      }
      kelasList.assignAll(list);
    } catch (e) {
      EpicSnackbar.error('Ups!', 'Gagal memuat daftar kelas.');
    } finally {
      isLoading.value = false;
    }
  }

  /// Join kelas dengan kode EPIC-XXXX dengan konfirmasi dialog (Bagian 11).
  Future<void> joinKelas(BuildContext context) async {
    String kode = kodeKelasController.text.trim().toUpperCase();
    if (kode.isEmpty) {
      EpicSnackbar.error('Ups!', 'Masukkan kode kelas terlebih dahulu.');
      return;
    }

    // Buang tulisan 'EPIC-' jika user terlanjur mengetiknya
    if (kode.startsWith('EPIC-')) {
      kode = kode.substring(5);
    }

    // Gabungkan menjadi format standar
    kode = 'EPIC-$kode';

    final uid = _session.user?.uid;
    if (uid == null) return;

    isJoining.value = true;
    try {
      // 1. Cari detail kelas terlebih dahulu untuk ditampilkan dalam konfirmasi
      final kelas = await _kelasRepo.findKelasByKode(kode);
      if (kelas == null) {
        EpicSnackbar.error('Ups!', 'Kode kelas "$kode" tidak ditemukan atau sudah tidak aktif.');
        return;
      }

      // Cek apakah murid sudah bergabung di kelas ini
      if (kelas.muridIds.contains(uid)) {
        EpicSnackbar.info('Sudah Bergabung', 'Kamu sudah menjadi anggota kelas "${kelas.namaKelas}"!');
        kodeKelasController.clear();
        return;
      }

      // 2. Tampilkan Dialog Konfirmasi (Sesuai Bagian 11)
      Get.dialog(
        AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          backgroundColor: const Color(0xFFFFF9F0),
          title: Center(
            child: Text(
              'Kelas Ditemukan! 🎉',
              style: AppFonts.heading3(color: AppColors.textPrimary),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.school_rounded, color: AppColors.primary, size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            kelas.namaKelas,
                            style: const TextStyle(
                              fontFamily: 'FredokaOne',
                              fontSize: 16,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      kelas.namaSekolah,
                      style: AppFonts.bodySmall(color: AppColors.textSecondary, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Guru: ${kelas.guruNama}',
                      style: AppFonts.caption(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE), // sky 100
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${kelas.jumlahMurid} murid sudah bergabung',
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0369A1),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Bergabung ke kelas ini?',
                style: AppFonts.bodyText(weight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actionsPadding: const EdgeInsets.only(bottom: 20, left: 12, right: 12),
          actions: [
            OutlinedButton(
              onPressed: () => Get.back(),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey.shade600,
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              ),
              child: const Text('Batal', style: TextStyle(fontFamily: 'FredokaOne')),
            ),
            ElevatedButton(
              onPressed: () async {
                Get.back(); // Tutup dialog konfirmasi
                isJoining.value = true;
                try {
                  final joinedKelas = await _kelasRepo.joinKelas(kode, uid);
                  kelasList.add(joinedKelas);
                  kodeKelasController.clear();

                  // Auto-aktifkan jika belum ada kelas aktif (termasuk jika ini adalah kelas pertama)
                  if (_session.activeKelasId.value.isEmpty) {
                    await _session.setActiveKelasId(joinedKelas.kelasId);
                  }

                  EpicSnackbar.success(
                    'Berhasil! 🎉',
                    'Kamu bergabung di kelas "${joinedKelas.namaKelas}" oleh ${joinedKelas.guruNama}',
                  );

                  // Refresh user data
                  await _session.refreshUser();

                  // Refresh RankingController jika sudah terdaftar (agar dropdown kelas update)
                  if (Get.isRegistered<RankingController>()) {
                    Get.find<RankingController>().refreshKelasLeaderboard();
                  }

                  // Kembali ke/buka "Kelas Saya" secara cerdas
                  final fromKelasScreen = isFromKelasScreen;

                  if (fromKelasScreen) {
                    if (context.mounted) {
                      Navigator.of(context).pop(); // Pop GabungKelasScreen
                    }
                  } else {
                    Get.offNamed(Routes.kelas); // Replaces GabungKelasScreen with KelasScreen
                  }
                } catch (e) {
                  EpicSnackbar.error('Gagal', e.toString().replaceAll('Exception: ', ''));
                } finally {
                  isJoining.value = false;
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              ),
              child: const Text('Ya, Gabung!', style: TextStyle(fontFamily: 'FredokaOne')),
            ),
          ],
        ),
      );
    } catch (e) {
      EpicSnackbar.error('Gagal', e.toString().replaceAll('Exception: ', ''));
    } finally {
      isJoining.value = false;
    }
  }

  /// Keluar dari kelas.
  Future<void> leaveKelas(KelasModel kelas) async {
    final uid = _session.user?.uid;
    if (uid == null) return;

    try {
      await _kelasRepo.leaveKelas(kelas.kelasId, uid);
      kelasList.removeWhere((k) => k.kelasId == kelas.kelasId);

      // Reset activeKelasId menjadi kosong jika keluar dari kelas yang sedang aktif
      if (_session.activeKelasId.value == kelas.kelasId) {
        await _session.setActiveKelasId('');
      }

      await _session.refreshUser();

      // Memicu refresh ranking/leaderboard secara instan
      if (Get.isRegistered<RankingController>()) {
        Get.find<RankingController>().refreshKelasLeaderboard();
      }

      EpicSnackbar.info(
        'Keluar Kelas',
        'Kamu telah keluar dari "${kelas.namaKelas}".',
      );
    } catch (e) {
      EpicSnackbar.error('Gagal', 'Tidak bisa keluar dari kelas saat ini.');
    }
  }

  @override
  void onClose() {
    _kelasSub?.cancel();
    kodeKelasController.dispose();
    super.onClose();
  }

  Future<void> _syncMuridKelasIds(UserModel user, List<KelasModel> actualKelasList) async {
    if (user.role == 'guru') return;
    
    final actualIds = actualKelasList.map((k) => k.kelasId).toList();
    final currentIds = user.kelasIds;
    
    final set1 = Set<String>.from(actualIds);
    final set2 = Set<String>.from(currentIds);
    
    if (set1.length != set2.length || !set1.containsAll(set2) || !set2.containsAll(set1)) {
      debugPrint('⚠️ Murid kelasIds out of sync! Syncing actual classes from Firestore...');
      try {
        final userRepo = UserRepository();
        await userRepo.updateProfil(user, {
          'kelasIds': actualIds,
        });
        debugPrint('✅ Murid kelasIds synchronized successfully!');
      } catch (e) {
        debugPrint('❌ Gagal sinkronisasi kelasIds murid: $e');
      }
    }
  }

  /// Guru: Membuat kelas baru
  Future<KelasModel?> createKelas({
    required String nama,
    String tingkat = '',
    String mataPelajaran = '',
    String tahunAjaran = '',
  }) async {
    final user = _session.user;
    if (user == null || !user.isGuru) {
      EpicSnackbar.error('Akses Ditolak', 'Hanya guru yang dapat membuat kelas.');
      return null;
    }

    isLoading.value = true;
    try {
      final kelasBaru = await _kelasRepo.createKelas(
        guruUid: user.uid,
        guruNama: user.namaLengkap.isNotEmpty ? user.namaLengkap : user.namaPanggilan,
        namaSekolah: user.sekolah,
        namaKelas: nama,
        tingkat: tingkat,
        mataPelajaran: mataPelajaran,
        tahunAjaran: tahunAjaran,
      );
      
      EpicSnackbar.success(
        'Kelas Berhasil Dibuat!',
        'Kode kelas Anda adalah ${kelasBaru.kodeKelas}',
      );
      return kelasBaru;
    } catch (e) {
      EpicSnackbar.error('Gagal Membuat Kelas', 'Error: $e');
      return null;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> toggleStatusKelas(String kelasId, bool isActive) async {
    try {
      await _kelasRepo.toggleStatusKelas(kelasId, isActive);
      
      // Update local state
      final index = kelasList.indexWhere((k) => k.kelasId == kelasId);
      if (index != -1) {
        kelasList[index] = kelasList[index].copyWith(status: isActive ? 'aktif' : 'nonaktif');
        kelasList.refresh();
      }

      EpicSnackbar.success('Berhasil', isActive ? 'Kelas berhasil diaktifkan' : 'Kelas berhasil dinonaktifkan');
      Get.back(); // Kembali dari detail screen
    } catch (e) {
      EpicSnackbar.error('Gagal', 'Tidak dapat mengubah status kelas');
    }
  }

  Future<void> deleteKelasPermanen(String kelasId) async {
    final user = _session.user;
    if (user == null) return;
    
    try {
      await _kelasRepo.deleteKelasPermanen(kelasId, user.uid);
      kelasList.removeWhere((k) => k.kelasId == kelasId);
      EpicSnackbar.success('Berhasil', 'Kelas berhasil dihapus permanen');
    } catch (e) {
      EpicSnackbar.error('Gagal', 'Tidak dapat menghapus kelas secara permanen');
    }
  }

  Future<void> removeMurid(String kelasId, String muridUid) async {
    try {
      await _kelasRepo.removeMurid(kelasId, muridUid);
      // Update local state if needed
      final index = kelasList.indexWhere((k) => k.kelasId == kelasId);
      if (index != -1) {
        final kelas = kelasList[index];
        final newMuridIds = List<String>.from(kelas.muridIds)..remove(muridUid);
        // Refresh local details stream
        kelasList[index] = kelas.copyWith(muridIds: newMuridIds);
        kelasList.refresh();
      }
      EpicSnackbar.success('Berhasil', 'Murid telah dikeluarkan dari kelas');
    } catch (e) {
      EpicSnackbar.error('Gagal', 'Tidak dapat mengeluarkan murid');
    }
  }

  /// Mengarsipkan kelas secara permanen
  Future<void> archiveKelas(String kelasId) async {
    try {
      await _kelasRepo.archiveKelas(kelasId);
      final index = kelasList.indexWhere((k) => k.kelasId == kelasId);
      if (index != -1) {
        kelasList[index] = kelasList[index].copyWith(status: 'arsip');
        kelasList.refresh();
      }
      EpicSnackbar.success('Berhasil diarsipkan 📁', 'Kelas telah dipindahkan ke arsip.');
      Get.back(); // Kembali dari detail screen
    } catch (e) {
      EpicSnackbar.error('Gagal', 'Tidak dapat mengarsipkan kelas');
    }
  }

  /// Menghapus link karya seni murid yang keluar dari kelas ini
  Future<void> removeMuridArtworkLink(String kelasId, String muridUid, String namaMurid) async {
    try {
      final artworkRepo = ArtworkRepository();
      await artworkRepo.removeKelasLinkFromMuridArtworks(kelasId, muridUid);
      EpicSnackbar.success(
        'Berhasil Dihapus 🗑️',
        'Semua karya milik $namaMurid tidak lagi terafiliasi dengan kelas ini.',
      );
    } catch (e) {
      EpicSnackbar.error('Gagal', 'Tidak dapat membersihkan link karya murid: $e');
    }
  }

  /// Membersihkan riwayat murid keluar sepenuhnya dari kelas
  Future<void> clearExitedMuridHistory(String kelasId, String muridUid) async {
    try {
      // Panggil penghapusan link karya terlebih dahulu agar semuanya bersih
      final artworkRepo = ArtworkRepository();
      await artworkRepo.removeKelasLinkFromMuridArtworks(kelasId, muridUid);

      await _kelasRepo.clearExitedMuridHistory(kelasId, muridUid);
      // Update local state exited list
      final index = kelasList.indexWhere((k) => k.kelasId == kelasId);
      if (index != -1) {
        final kelas = kelasList[index];
        final newExited = List<Map<String, dynamic>>.from(kelas.exitedMurids)
          ..removeWhere((m) => m['uid'] == muridUid);
        kelasList[index] = kelas.copyWith(exitedMurids: newExited);
        kelasList.refresh();
      }
      EpicSnackbar.success('Berhasil', 'Riwayat keluar murid dan karya telah dibersihkan');
    } catch (e) {
      EpicSnackbar.error('Gagal', 'Tidak dapat membersihkan riwayat keluar: $e');
    }
  }
}
