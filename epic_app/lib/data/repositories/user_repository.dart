import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:epic_app/data/models/user_model.dart';
import 'package:epic_app/data/models/character_model.dart';
import 'package:epic_app/data/models/score_model.dart';
import 'package:epic_app/core/services/app_config_service.dart';

/// Repository untuk mengelola data User di Firestore.
class UserRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = 'users';

  // ─── READ ──────────────────────────────────────────────────────────────────

  /// Mendapatkan data user dari Firestore (sekali ambil).
  Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection(_collection).doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return UserModel.fromJson({...doc.data()!, 'uid': uid});
    }
    return null;
  }

  /// Stream real-time data user.
  Stream<UserModel?> watchUser(String uid) {
    return _db.collection(_collection).doc(uid).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return UserModel.fromJson({...doc.data()!, 'uid': uid});
      }
      return null;
    });
  }

  // ─── POIN ──────────────────────────────────────────────────────────────────

  /// Tambah poin user secara transactional. Mengembalikan UserModel yang sudah diupdate.
  Future<UserModel> tambahPoin(UserModel user, int poinBaru) async {
    final docRef = _db.collection(_collection).doc(user.uid);
    
    return await _db.runTransaction<UserModel>((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) throw Exception('User tidak ditemukan!');
      
      final currentPoin = (snapshot.data()?['poin'] as num?)?.toInt() ?? 0;
      final newPoin = currentPoin + poinBaru;
      
      transaction.update(docRef, {
        'poin': newPoin,
      });
      
      return user.copyWith(poin: newPoin);
    });
  }

  // ─── NYAWA ─────────────────────────────────────────────────────────────────

  /// Ambil nilai maxNyawa dari AppConfigService jika sudah dimuat,
  /// atau fallback ke UserModel.maxNyawa jika service belum tersedia.
  int _getMaxNyawa() {
    if (Get.isRegistered<AppConfigService>()) {
      return Get.find<AppConfigService>().maxNyawa.value;
    }
    return UserModel.maxNyawa;
  }

  /// Cek dan reset nyawa jika hari baru, lalu kurangi nyawa.
  /// Throws Exception jika nyawa habis.
  Future<UserModel> gunakanNyawa(UserModel user) async {
    final docRef = _db.collection(_collection).doc(user.uid);

    return await _db.runTransaction<UserModel>((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) throw Exception('User tidak ditemukan!');

      final data = snapshot.data()!;
      final now = DateTime.now();

      // Cek apakah perlu reset nyawa (hari baru)
      DateTime lastReset;
      final rawReset = data['nyawaLastReset'];
      if (rawReset is Timestamp) {
        lastReset = rawReset.toDate().toLocal();
      } else {
        lastReset = DateTime(2000); // Default: sudah lama, pasti perlu reset
      }

      final isNewDay = now.year != lastReset.year ||
          now.month != lastReset.month ||
          now.day != lastReset.day;

      final maxNyawa = _getMaxNyawa();
      int currentNyawa = isNewDay
          ? maxNyawa
          : (data['nyawa'] as int? ?? maxNyawa);

      if (currentNyawa <= 0) {
        throw Exception('Nyawa habis! Coba lagi besok.');
      }

      final newNyawa = currentNyawa - 1;
      final Map<String, dynamic> updateData = {'nyawa': newNyawa};
      if (isNewDay) {
        updateData['nyawaLastReset'] = Timestamp.fromDate(now);
      }

      transaction.update(docRef, updateData);

      return user.copyWith(
        nyawa: newNyawa,
        nyawaLastReset: isNewDay ? now : user.nyawaLastReset,
      );
    });
  }

  /// Sync nyawa dari Firestore (cek reset harian tanpa mengurangi).
  Future<UserModel> syncNyawa(UserModel user) async {
    if (!user.perluResetNyawa) return user;

    // Reset nyawa ke max karena hari baru
    final maxNyawa = _getMaxNyawa();
    await _db.collection(_collection).doc(user.uid).update({
      'nyawa': maxNyawa,
      'nyawaLastReset': Timestamp.fromDate(DateTime.now()),
    });
    return user.copyWith(
      nyawa: maxNyawa,
      nyawaLastReset: DateTime.now(),
    );
  }

  // ─── KARAKTER ──────────────────────────────────────────────────────────────

  /// Unlock karakter berdasarkan threshold poin (bukan beli).
  /// Karakter otomatis ter-unlock saat poin cukup, method ini hanya update daftar.
  Future<UserModel> unlockKarakter(UserModel user, String characterId) async {
    if (user.karakterDimiliki.contains(characterId)) {
      throw Exception('Karakter sudah dimiliki!');
    }

    final newList = [...user.karakterDimiliki, characterId];
    await _db.collection(_collection).doc(user.uid).update({
      'karakterDimiliki': newList,
      'karakterAktif': characterId,
    });

    return user.copyWith(
      karakterDimiliki: newList,
      karakterAktif: characterId,
    );
  }

  /// Ganti karakter aktif.
  Future<UserModel> setKarakterAktif(UserModel user, String characterId) async {
    final ownedList = List<String>.from(user.karakterDimiliki);
    if (characterId == 'ipeh_default' && !ownedList.contains('ipeh_default')) {
      ownedList.add('ipeh_default');
    }
    if (!ownedList.contains(characterId) && characterId != 'epi_default') {
      throw Exception('Karakter belum di-unlock!');
    }
    
    final Map<String, dynamic> updateData = {
      'karakterAktif': characterId,
    };
    if (characterId == 'ipeh_default') {
      updateData['karakterDimiliki'] = ownedList;
    }
    
    await _db.collection(_collection).doc(user.uid).update(updateData);
    return user.copyWith(
      karakterAktif: characterId,
      karakterDimiliki: ownedList,
    );
  }

  // ─── PROFIL ────────────────────────────────────────────────────────────────

  /// Update profil user (nama, sekolah, dll).
  Future<UserModel> updateProfil(UserModel user, Map<String, dynamic> updates) async {
    await _db.collection(_collection).doc(user.uid).update(updates);

    final String? newNamaLengkap = updates['namaLengkap'];
    final String? newNamaPanggilan = updates['namaPanggilan'];
    
    if (newNamaLengkap != null || newNamaPanggilan != null) {
      final String newName = (newNamaLengkap != null && newNamaLengkap.trim().isNotEmpty)
          ? newNamaLengkap.trim()
          : (newNamaPanggilan != null && newNamaPanggilan.trim().isNotEmpty)
              ? newNamaPanggilan.trim()
              : (user.namaLengkap.isNotEmpty ? user.namaLengkap : user.namaPanggilan);
              
      // Cari semua kelas milik guru ini dan perbarui field 'guruNama' secara batch
      final classesQuery = await _db
          .collection('kelas')
          .where('guruUid', isEqualTo: user.uid)
          .get();
          
      if (classesQuery.docs.isNotEmpty) {
        final batch = _db.batch();
        for (final doc in classesQuery.docs) {
          batch.update(doc.reference, {'guruNama': newName});
        }
        await batch.commit();
      }
    }

    // Return updated user
    return await getUser(user.uid) ?? user;
  }

  /// Update avatar URL setelah upload ke Storage.
  Future<UserModel> updateAvatar(UserModel user, String newAvatarUrl) async {
    await _db.collection(_collection).doc(user.uid).update({
      'avatarUrl': newAvatarUrl,
    });
    return user.copyWith(avatarUrl: newAvatarUrl);
  }

  // ─── KARAKTER LIST ─────────────────────────────────────────────────────────

  /// Mendapatkan daftar karakter aktif dari Firestore.
  Future<List<CharacterModel>> getCharacters() async {
    try {
      final snapshot = await _db
          .collection('characters')
          .where('isActive', isEqualTo: true)
          .orderBy('poinUnlock', descending: false)
          .get();

      final List<CharacterModel> list = [];
      if (snapshot.docs.isNotEmpty) {
        list.addAll(snapshot.docs.map((doc) {
          return CharacterModel.fromJson({...doc.data(), 'id': doc.id});
        }));
      }

      // Pastikan epi_default dan ipeh_default selalu ada
      if (!list.any((c) => c.id == 'epi_default')) {
        list.insert(0, const CharacterModel(
          id: 'epi_default',
          nama: 'Epi Si Cerdas',
          deskripsi: 'Karakter utama yang tangguh dan cerdas.',
          tier: 'common',
          poinUnlock: 0,
          imageUrl: '',
          isActive: true,
        ));
      }
      if (!list.any((c) => c.id == 'ipeh_default')) {
        list.insert(1, const CharacterModel(
          id: 'ipeh_default',
          nama: 'Ipeh Si Manis',
          deskripsi: 'Karakter gratis langsung unlock tanpa syarat.',
          tier: 'common',
          poinUnlock: 0,
          imageUrl: 'assets/images/character/ipeh/character_static.png',
          isActive: true,
        ));
      }
      return list;
    } catch (e) {
      // Return fallback if offline or error
      return [
        const CharacterModel(
          id: 'epi_default',
          nama: 'Epi Si Cerdas',
          deskripsi: 'Karakter utama yang tangguh dan cerdas.',
          tier: 'common',
          poinUnlock: 0,
          imageUrl: '',
          isActive: true,
        ),
        const CharacterModel(
          id: 'ipeh_default',
          nama: 'Ipeh Si Manis',
          deskripsi: 'Karakter gratis langsung unlock tanpa syarat.',
          tier: 'common',
          poinUnlock: 0,
          imageUrl: 'assets/images/character/ipeh/character_static.png',
          isActive: true,
        ),
      ];
    }
  }

  // ─── LEADERBOARD ───────────────────────────────────────────────────────────

  /// Stream real-time leaderboard (top 100 berdasarkan poin).
  Stream<List<ScoreModel>> watchLeaderboard({int limit = 100}) {
    return _db
        .collection(_collection)
        .orderBy('poin', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.where((doc) {
        final data = doc.data();
        final role = data['role'] ?? 'murid';
        final isProfileComplete = data['isProfileComplete'] == true;
        return role != 'guru' && role != 'admin' && isProfileComplete;
      }).map((doc) {
        final data = {...doc.data(), 'uid': doc.id};
        final rawPoin = data['poin'];
        final int poinVal = rawPoin is num ? rawPoin.toInt() : (int.tryParse(rawPoin?.toString() ?? '') ?? 0);
        final rawGameSelesai = data['gameSelesai'];
        final int gameSelesaiVal = rawGameSelesai is num ? rawGameSelesai.toInt() : (int.tryParse(rawGameSelesai?.toString() ?? '') ?? 0);

        return ScoreModel(
          uid: doc.id,
          nama: data['namaPanggilan']?.toString().isNotEmpty == true
              ? data['namaPanggilan']
              : data['namaLengkap']?.toString() ?? '-',
          avatarUrl: data['avatarUrl']?.toString().isNotEmpty == true
              ? data['avatarUrl']
              : null,
          namaSekolah: data['sekolah']?.toString() ?? '',
          totalPoin: poinVal,
          gameSelesai: gameSelesaiVal,
        );
      }).toList();
    });
  }

  // ─── GAME PROGRESS ─────────────────────────────────────────────────────────

  /// Simpan progress level drawing game user ke Firestore secara atomik.
  Future<void> simpanProgress({
    required String uid,
    required String kategori,
    required int level,
    required int skorBaru,
    required int poinBaru,
  }) async {
    final progressRef = _db
        .collection(_collection)
        .doc(uid)
        .collection('game_progress')
        .doc(kategori);
        
    final userRef = _db.collection(_collection).doc(uid);

    await _db.runTransaction((transaction) async {
      // 1. Ambil data progress game & data user
      final progressDoc = await transaction.get(progressRef);
      final userDoc = await transaction.get(userRef);

      if (!userDoc.exists) throw Exception('User tidak ditemukan!');

      Map<String, dynamic> levels = {};
      if (progressDoc.exists && progressDoc.data() != null) {
        levels = Map<String, dynamic>.from(progressDoc.data()!['levels'] ?? {});
      }

      final currentBestSkor = (levels['$level']?['bestSkor'] ?? 0) as int;
      final currentBestPoin = (levels['$level']?['bestPoin'] ?? 0) as int;

      // Hanya lakukan perubahan jika skor baru lebih tinggi
      if (skorBaru > currentBestSkor) {
        levels['$level'] = {
          'bestSkor': skorBaru,
          'bestPoin': poinBaru,
          'unlocked': true,
          'completedAt': Timestamp.fromDate(DateTime.now()),
        };

        // Unlock level berikutnya jika skor >= 60
        if (skorBaru >= 60 && level < 4) {
          levels['${level + 1}'] = {
            ...Map<String, dynamic>.from(levels['${level + 1}'] ?? {}),
            'unlocked': true,
          };
        }

        // Set progress game
        transaction.set(progressRef, {
          'kategori': kategori,
          'levels': levels,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        }, SetOptions(merge: true));

        // Update poin user secara atomik jika poin baru lebih tinggi dari best poin
        if (poinBaru > currentBestPoin) {
          final selisihPoin = poinBaru - currentBestPoin;
          final currentPoin = (userDoc.data()?['poin'] as num?)?.toInt() ?? 0;
          final currentGameSelesai = (userDoc.data()?['gameSelesai'] as num?)?.toInt() ?? 0;

          transaction.update(userRef, {
            'poin': currentPoin + selisihPoin,
            'gameSelesai': currentGameSelesai + 1,
          });
        }
      }
    });
  }

  /// Ambil progress drawing game user untuk satu kategori.
  Future<Map<String, dynamic>> getProgress(String uid, String kategori) async {
    final doc = await _db
        .collection(_collection)
        .doc(uid)
        .collection('game_progress')
        .doc(kategori)
        .get();

    if (doc.exists && doc.data() != null) {
      return doc.data()!;
    }
    return {'levels': {'1': {'unlocked': true, 'bestSkor': 0, 'bestPoin': 0}}};
  }

  /// Ambil aktivitas game terbaru user
  Future<List<Map<String, dynamic>>> getRecentActivities(String uid, {int limit = 5}) async {
    final snapshot = await _db
        .collection(_collection)
        .doc(uid)
        .collection('game_progress')
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  /// Update last active timestamp
  Future<void> updateLastActive(String uid) async {
    try {
      await _db.collection(_collection).doc(uid).update({
        'lastActiveAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Ignore or log error
    }
  }
}
