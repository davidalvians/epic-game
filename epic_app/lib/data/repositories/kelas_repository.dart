// Repository untuk manajemen kelas — join, leave, create, CRUD murid
import 'dart:math';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:epic_app/data/models/kelas_model.dart';
import 'package:epic_app/data/models/artwork_model.dart';
import 'package:get/get.dart';
import 'package:epic_app/data/services/storage_service.dart';

/// Repository untuk operasi CRUD kelas di Firestore.
class KelasRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _kelasCollection = 'kelas';
  static const String _usersCollection = 'users';

  // ─── MURID: Join & Leave ──────────────────────────────────────────────

  /// Gabung ke kelas menggunakan kode EPIC-XXXX.
  /// Mengembalikan KelasModel jika berhasil.
  Future<KelasModel> joinKelas(String kodeKelas, String muridUid) async {
    final cleanCode = kodeKelas.trim().toUpperCase();

    // Cari kelas berdasarkan kode
    final query = await _db
        .collection(_kelasCollection)
        .where('kodeKelas', isEqualTo: cleanCode)
        .where('status', isEqualTo: 'aktif')
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw Exception('Kode kelas "$cleanCode" tidak ditemukan atau sudah tidak aktif.');
    }

    final doc = query.docs.first;
    final kelas = KelasModel.fromJson({...doc.data(), 'kelasId': doc.id});

    // Cek apakah sudah bergabung
    if (kelas.muridIds.contains(muridUid)) {
      throw Exception('Kamu sudah bergabung di kelas "${kelas.namaKelas}"!');
    }

    // Tambah murid ke kelas (hanya update muridIds agar tidak diblokir aturan Firestore murid)
    await _db.collection(_kelasCollection).doc(kelas.kelasId).update({
      'muridIds': FieldValue.arrayUnion([muridUid]),
    });

    // Tambah kelasId ke user
    await _db.collection(_usersCollection).doc(muridUid).update({
      'kelasIds': FieldValue.arrayUnion([kelas.kelasId]),
    });

    debugPrint('✅ Murid $muridUid bergabung ke kelas ${kelas.namaKelas}');
    return kelas.copyWith(muridIds: [...kelas.muridIds, muridUid]);
  }

  /// Keluar dari kelas.
  Future<void> leaveKelas(String kelasId, String muridUid) async {
    // 1. Ambil data nama murid terlebih dahulu untuk dicatat di riwayat keluar
    String namaLengkap = 'Murid';
    String namaPanggilan = 'Murid';
    try {
      final userSnap = await _db.collection(_usersCollection).doc(muridUid).get();
      if (userSnap.exists && userSnap.data() != null) {
        final data = userSnap.data()!;
        namaLengkap = data['namaLengkap']?.toString() ?? '';
        namaPanggilan = data['namaPanggilan']?.toString() ?? '';
      }
    } catch (e) {
      debugPrint('⚠️ Gagal mengambil nama lengkap murid saat keluar sendiri: $e');
    }

    final exitLog = {
      'uid': muridUid,
      'namaLengkap': namaLengkap.isNotEmpty ? namaLengkap : namaPanggilan,
      'namaPanggilan': namaPanggilan,
      'tanggalKeluar': DateTime.now().toIso8601String(),
      'alasan': 'keluar_sendiri',
    };

    // 2. Coba masukkan ke riwayat keluar (bisa gagal jika aturan Firestore melarang penulisan field log oleh murid)
    try {
      final classSnap = await _db.collection(_kelasCollection).doc(kelasId).get();
      List<dynamic> exitedList = [];
      if (classSnap.exists && classSnap.data() != null) {
        exitedList = List.from(classSnap.data()!['exitedMurids'] ?? []);
      }
      exitedList.removeWhere((e) => e is Map && e['uid'] == muridUid);
      exitedList.add(exitLog);

      // Guard MED-07: batasi panjang array agar dokumen tidak melebihi 1MB Firestore.
      // Jika record melebihi 200, hapus yang paling lama (FIFO) agar dokumen tetap ramping.
      const int kMaxExitedRecords = 200;
      if (exitedList.length > kMaxExitedRecords) {
        exitedList = exitedList.sublist(exitedList.length - kMaxExitedRecords);
        debugPrint('⚠️ exitedMurids melebihi $kMaxExitedRecords record — record lama dipangkas.');
      }

      await _db.collection(_kelasCollection).doc(kelasId).update({
        'exitedMurids': exitedList,
      });
      debugPrint('✅ Berhasil mencatat log keluar murid tanpa duplikat');
    } catch (e) {
      debugPrint('⚠️ Mengabaikan kegagalan mencatat exitedMurids (masalah izin): $e');
    }

    // 3 & 4. Hapus murid dari kelas dan hapus kelasId dari profil murid secara atomik (batch write)
    //        Jika salah satu gagal, keduanya di-rollback agar data tidak inkonsisten.
    final batch = _db.batch();
    batch.update(
      _db.collection(_kelasCollection).doc(kelasId),
      {'muridIds': FieldValue.arrayRemove([muridUid])},
    );
    batch.update(
      _db.collection(_usersCollection).doc(muridUid),
      {'kelasIds': FieldValue.arrayRemove([kelasId])},
    );
    await batch.commit();

    debugPrint('✅ Murid $muridUid keluar dari kelas $kelasId');
  }

  /// Mendapatkan detail kelas berdasarkan ID kelas.
  Future<KelasModel?> getKelas(String kelasId) async {
    try {
      final doc = await _db.collection(_kelasCollection).doc(kelasId).get();
      if (doc.exists && doc.data() != null) {
        return KelasModel.fromJson({...doc.data()!, 'kelasId': doc.id});
      }
      return null;
    } catch (e) {
      debugPrint('⚠️ Error fetching kelas $kelasId: $e');
      return null;
    }
  }

  /// Mencari kelas aktif berdasarkan kode kelas (EPIC-XXXX).
  Future<KelasModel?> findKelasByKode(String kodeKelas) async {
    final cleanCode = kodeKelas.trim().toUpperCase();
    final query = await _db
        .collection(_kelasCollection)
        .where('kodeKelas', isEqualTo: cleanCode)
        .where('status', isEqualTo: 'aktif')
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    final doc = query.docs.first;
    return KelasModel.fromJson({...doc.data(), 'kelasId': doc.id});
  }

  Future<List<KelasModel>> getKelasByMurid(String muridUid) async {
    final query = await _db
        .collection(_kelasCollection)
        .where('muridIds', arrayContains: muridUid)
        .get();

    return query.docs
        .map((doc) => KelasModel.fromJson({...doc.data(), 'kelasId': doc.id}))
        .where((kelas) => kelas.isActive || kelas.status == 'arsip')
        .toList();
  }

  // ─── GURU: Create & Manage ────────────────────────────────────────────

  /// Buat kelas baru (hanya guru terverifikasi).
  /// Otomatis generate kode EPIC-XXXX.
  Future<KelasModel> createKelas({
    required String guruUid,
    required String guruNama,
    required String namaSekolah,
    required String namaKelas,
    String tingkat = '',
    String mataPelajaran = '',
    String tahunAjaran = '',
  }) async {
    // Generate kode unik EPIC-XXXX
    String kodeKelas;
    bool exists = true;

    do {
      kodeKelas = _generateKodeKelas();
      final query = await _db
          .collection(_kelasCollection)
          .where('kodeKelas', isEqualTo: kodeKelas)
          .limit(1)
          .get();
      exists = query.docs.isNotEmpty;
    } while (exists);

    // Buat dokumen kelas
    final kelasId = _db.collection(_kelasCollection).doc().id;
    final kelas = KelasModel(
      kelasId: kelasId,
      namaKelas: namaKelas,
      kodeKelas: kodeKelas,
      qrData: '{"type":"epic_kelas","kode":"$kodeKelas"}',
      guruUid: guruUid,
      guruNama: guruNama,
      namaSekolah: namaSekolah,
      tingkat: tingkat,
      tahunAjaran: tahunAjaran.isNotEmpty
          ? tahunAjaran
          : '${DateTime.now().year}/${DateTime.now().year + 1}',
      mataPelajaran: mataPelajaran,
      status: 'aktif',
      muridIds: const [],
      totalMurid: 0,
      totalKarya: 0,
      avgNilai: 0.0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _db.collection(_kelasCollection).doc(kelasId).set(kelas.toJson());

    // Tambah kelasId ke user guru
    await _db.collection(_usersCollection).doc(guruUid).update({
      'kelasIds': FieldValue.arrayUnion([kelasId]),
    });

    debugPrint('✅ Kelas "${kelas.namaKelas}" dibuat dengan kode $kodeKelas');
    return kelas;
  }

  Future<List<KelasModel>> getKelasByGuru(String guruUid) async {
    final query = await _db
        .collection(_kelasCollection)
        .where('guruUid', isEqualTo: guruUid)
        .get();

    final list = query.docs
        .map((doc) => KelasModel.fromJson({...doc.data(), 'kelasId': doc.id}))
        .toList();
    
    // Urutkan secara lokal untuk menghindari error Composite Index di Firestore
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Ubah status aktif kelas.
  Future<void> toggleStatusKelas(String kelasId, bool isActive) async {
    final status = isActive ? 'aktif' : 'nonaktif';
    await _db.collection(_kelasCollection).doc(kelasId).update({
      'status': status,
      'isActive': isActive, // backward compatibility
      if (!isActive) 'nonaktifkanAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    debugPrint('✅ Kelas $kelasId status diubah menjadi $status');
  }

  /// Hapus kelas secara permanen dari database beserta referensinya di data guru dan murid.
  Future<void> deleteKelasPermanen(String kelasId, String guruUid) async {
    try {
      // Skenario Penghapusan Karya (Sesuai Komentar Pengguna):
      // 1. Karya yang sudah dihapus murid (deletedByMurid == true) -> Hapus Permanen dari Firestore & Storage
      // 2. Karya yang tidak dihapus murid -> Unlink (kelasId = null) sehingga menjadi karya pribadi murid
      final artworksSnap = await _db
          .collection('artworks')
          .where('kelasId', isEqualTo: kelasId)
          .get();
          
      if (artworksSnap.docs.isNotEmpty) {
        final artworksBatch = _db.batch();
        for (final doc in artworksSnap.docs) {
          final data = doc.data();
          final deletedByMurid = data['deletedByMurid'] == true;
          final imageUrl = data['imageUrl']?.toString() ?? '';
          
          if (deletedByMurid) {
            artworksBatch.delete(doc.reference);
            if (imageUrl.isNotEmpty) {
              try {
                final storage = Get.find<StorageService>();
                await storage.deleteFile(imageUrl);
              } catch (storageErr) {
                debugPrint('⚠️ Gagal menghapus file gambar di Storage saat hapus kelas: $storageErr');
              }
            }
          } else {
            artworksBatch.update(doc.reference, {'kelasId': null});
          }
        }
        await artworksBatch.commit();
        debugPrint('✅ Berhasil menyelaraskan ${artworksSnap.docs.length} karya terkait kelas');
      }
    } catch (e) {
      debugPrint('⚠️ Gagal memproses data karya saat hapus kelas: $e');
    }

    // Hapus dokumen kelas
    await _db.collection(_kelasCollection).doc(kelasId).delete();

    // Hapus id kelas dari array kelasIds milik guru (diizinkan karena dokumen sendiri)
    await _db.collection(_usersCollection).doc(guruUid).update({
      'kelasIds': FieldValue.arrayRemove([kelasId]),
    });
    
    debugPrint('✅ Kelas $kelasId dihapus permanen');
  }

  /// Hapus murid dari kelas (oleh guru).
  Future<void> removeMurid(String kelasId, String muridUid) async {
    // 1. Ambil data nama murid terlebih dahulu untuk dicatat di riwayat keluar
    String namaLengkap = 'Murid';
    String namaPanggilan = 'Murid';
    try {
      final userSnap = await _db.collection(_usersCollection).doc(muridUid).get();
      if (userSnap.exists && userSnap.data() != null) {
        final data = userSnap.data()!;
        namaLengkap = data['namaLengkap']?.toString() ?? '';
        namaPanggilan = data['namaPanggilan']?.toString() ?? '';
      }
    } catch (e) {
      debugPrint('⚠️ Gagal mengambil nama lengkap murid saat dikeluarkan: $e');
    }

    final exitLog = {
      'uid': muridUid,
      'namaLengkap': namaLengkap.isNotEmpty ? namaLengkap : namaPanggilan,
      'namaPanggilan': namaPanggilan,
      'tanggalKeluar': DateTime.now().toIso8601String(),
      'alasan': 'dikeluarkan',
    };

    // 2. Hapus murid dari aktif dan masukkan ke riwayat keluar secara aman tanpa duplikat
    final classSnap = await _db.collection(_kelasCollection).doc(kelasId).get();
    List<dynamic> exitedList = [];
    if (classSnap.exists && classSnap.data() != null) {
      exitedList = List.from(classSnap.data()!['exitedMurids'] ?? []);
    }
    exitedList.removeWhere((e) => e is Map && e['uid'] == muridUid);
    exitedList.add(exitLog);

    await _db.collection(_kelasCollection).doc(kelasId).update({
      'muridIds': FieldValue.arrayRemove([muridUid]),
      'exitedMurids': exitedList,
    });

    try {
      await _db.collection(_usersCollection).doc(muridUid).update({
        'kelasIds': FieldValue.arrayRemove([kelasId]),
      });
    } catch (e) {
      debugPrint('⚠️ Silent warning: Gagal memperbarui kelasIds murid secara langsung (masalah izin). Ini normal jika aturan Firestore membatasi akses antar-user. Klien murid akan melakukan sinkronisasi otomatis. Detail: $e');
    }

    debugPrint('✅ Murid $muridUid dikeluarkan dari kelas $kelasId dan riwayat dicatat');
  }

  /// Membersihkan riwayat murid keluar sepenuhnya dari kelas.
  Future<void> clearExitedMuridHistory(String kelasId, String muridUid) async {
    final doc = await _db.collection(_kelasCollection).doc(kelasId).get();
    if (!doc.exists || doc.data() == null) return;
    
    final List<dynamic> exitedList = doc.data()!['exitedMurids'] ?? [];
    final updatedList = exitedList.where((e) => e['uid'] != muridUid).toList();
    
    await _db.collection(_kelasCollection).doc(kelasId).update({
      'exitedMurids': updatedList,
    });
    debugPrint('✅ Membersihkan riwayat keluar untuk murid $muridUid di kelas $kelasId');
  }

  /// Mengarsipkan kelas secara permanen (read-only).
  Future<void> archiveKelas(String kelasId) async {
    await _db.collection(_kelasCollection).doc(kelasId).update({
      'status': 'arsip',
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    debugPrint('✅ Kelas $kelasId berhasil diarsipkan');
  }

  /// Stream detail kelas (real-time).
  Stream<KelasModel?> watchKelasDetail(String kelasId) {
    return _db.collection(_kelasCollection).doc(kelasId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return KelasModel.fromJson({...doc.data()!, 'kelasId': doc.id});
    });
  }

  /// Ambil detail kelas beserta data anggotanya.
  Future<KelasModel?> getKelasDetail(String kelasId) async {
    final doc = await _db.collection(_kelasCollection).doc(kelasId).get();
    if (!doc.exists || doc.data() == null) return null;
    return KelasModel.fromJson({...doc.data()!, 'kelasId': doc.id});
  }

  /// Stream leaderboard kelas (real-time).
  Stream<List<Map<String, dynamic>>> watchLeaderboardKelas(String kelasId) {
    late StreamController<List<Map<String, dynamic>>> controller;
    StreamSubscription? kelasSub;
    StreamSubscription? usersSub;
    StreamSubscription? artworksSub;

    List<String> actualMuridIds = [];
    List<Map<String, dynamic>> lastUsers = [];
    List<ArtworkModel> classArtworks = [];

    bool kelasEmitted = false;
    bool usersEmitted = false;

    void emitMerged() {
      // Hanya kirim data jika kelas & user stream pendukung sudah melakukan emisi pertama.
      // Kita tidak menahan emisi hanya karena artworks belum siap demi mencegah infinite loading.
      if (!kelasEmitted || !usersEmitted) return;
      if (controller.isClosed) return;
      
      final List<Map<String, dynamic>> leaderboard = [];

      // Map uid to sum of poinDapat in this class
      final Map<String, int> studentClassPoints = {};
      for (final art in classArtworks) {
        if (art.kelasId == kelasId) {
          studentClassPoints[art.uid] = (studentClassPoints[art.uid] ?? 0) + (art.poinDapat ?? 0);
        }
      }

      for (final userData in lastUsers) {
        final uid = userData['uid'];
        if (actualMuridIds.contains(uid)) {
          // Ganti poin global dengan poin khusus kelas ini (default 0 jika belum berkarya)
          final classPoints = studentClassPoints[uid] ?? 0;
          leaderboard.add({
            ...userData,
            'poin': classPoints, // Timpa dengan poin khusus kelas
          });
        }
      }

      // Sort by class-specific poin descending secara aman
      leaderboard.sort((a, b) => (b['poin'] as int? ?? 0).compareTo(a['poin'] as int? ?? 0));
      controller.add(leaderboard);
    }

    controller = StreamController<List<Map<String, dynamic>>>.broadcast(
      onListen: () {
        // 1. Listen to class doc
        kelasSub = _db.collection(_kelasCollection).doc(kelasId).snapshots().listen((kelasSnap) {
          kelasEmitted = true;
          if (kelasSnap.exists && kelasSnap.data() != null) {
            actualMuridIds = List<String>.from(kelasSnap.data()!['muridIds'] ?? []);
          } else {
            actualMuridIds = [];
          }
          emitMerged();
        }, onError: (e) {
          debugPrint('⚠️ Error loading kelas doc in watchLeaderboardKelas: $e');
          kelasEmitted = true;
          actualMuridIds = [];
          emitMerged();
          if (!controller.isClosed) controller.addError(e);
        });

        // 2. Listen to users query
        usersSub = _db
            .collection(_usersCollection)
            .where('kelasIds', arrayContains: kelasId)
            .snapshots()
            .listen((usersSnap) {
          usersEmitted = true;
          lastUsers = [];
          for (final doc in usersSnap.docs) {
            final data = doc.data();
            final role = data['role'] ?? 'murid';
            final isProfileComplete = data['isProfileComplete'] == true;
            if (role != 'guru' && role != 'admin' && isProfileComplete) {
              final rawPoin = data['poin'];
              final int poinVal = rawPoin is num ? rawPoin.toInt() : (int.tryParse(rawPoin?.toString() ?? '') ?? 0);
              final rawGameSelesai = data['gameSelesai'];
              final int gameSelesaiVal = rawGameSelesai is num ? rawGameSelesai.toInt() : (int.tryParse(rawGameSelesai?.toString() ?? '') ?? 0);

              lastUsers.add({
                'uid': doc.id,
                'namaLengkap': data['namaLengkap'] ?? '',
                'namaPanggilan': data['namaPanggilan'] ?? '',
                'username': data['username'] ?? '',
                'avatarUrl': data['avatarUrl'] ?? '',
                'poin': poinVal,
                'gameSelesai': gameSelesaiVal,
                'namaSekolah': data['sekolah'] ?? '',
                'lastActiveAt': data['lastActiveAt'],
              });
            }
          }
          emitMerged();
        }, onError: (e) {
          debugPrint('⚠️ Error loading users query in watchLeaderboardKelas: $e');
          usersEmitted = true;
          lastUsers = [];
          emitMerged();
          if (!controller.isClosed) controller.addError(e);
        });

        // 3. Listen to class artworks
        artworksSub = _db
            .collection('artworks')
            .where('kelasId', isEqualTo: kelasId)
            .snapshots()
            .listen((artworksSnap) {
          classArtworks = artworksSnap.docs
              .map((doc) => ArtworkModel.fromJson(doc.data()))
              .toList();
          emitMerged();
        }, onError: (e) {
          debugPrint('⚠️ Error loading artworks query in watchLeaderboardKelas: $e');
          classArtworks = [];
          emitMerged();
          if (!controller.isClosed) controller.addError(e);
        });
      },
      onCancel: () {
        kelasSub?.cancel();
        usersSub?.cancel();
        artworksSub?.cancel();
      },
    );

    return controller.stream;
  }

  /// Stream daftar kelas milik guru (real-time).
  Stream<List<KelasModel>> watchKelasByGuru(String guruUid) {
    return _db
        .collection(_kelasCollection)
        .where('guruUid', isEqualTo: guruUid)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => KelasModel.fromJson({...doc.data(), 'kelasId': doc.id}))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Stream daftar kelas aktif yang diikuti murid (real-time).
  Stream<List<KelasModel>> watchKelasByMurid(String muridUid) {
    return _db
        .collection(_kelasCollection)
        .where('muridIds', arrayContains: muridUid)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => KelasModel.fromJson({...doc.data(), 'kelasId': doc.id}))
          .where((kelas) => kelas.isActive || kelas.status == 'arsip')
          .toList();
    });
  }


  // ─── HELPERS ──────────────────────────────────────────────────────────

  /// Generate kode kelas format EPIC-XXXX (4 karakter alfanumerik uppercase).
  String _generateKodeKelas() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // tanpa I,O,0,1
    final random = Random.secure();
    final code =
        List.generate(4, (_) => chars[random.nextInt(chars.length)]).join();
    return 'EPIC-$code';
  }
}
