// Repository untuk manajemen misi harian
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:epic_app/data/models/misi_harian_model.dart';

/// Repository untuk operasi CRUD misi harian di Firestore.
class MisiHarianRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Ambil misi harian hari ini untuk user.
  /// Membaca dari koleksi misi_templates. Jika kosong, gunakan default.
  Future<List<MisiHarianModel>> getMisiHariIni(String uid) async {
    final now = DateTime.now();
    final todayKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    try {
      final doc = await _db
          .collection('users')
          .doc(uid)
          .collection('mission_progress')
          .doc(todayKey)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final missions = data['missions'] as List?;
        if (missions != null && missions.isNotEmpty) {
          return missions
              .map((m) => MisiHarianModel.fromJson(Map<String, dynamic>.from(m)))
              .toList();
        }
      }

      // Ambil template aktif dari koleksi misi_templates
      final templateSnap = await _db
          .collection('misi_templates')
          .where('isActive', isEqualTo: true)
          .get();

      List<MisiHarianModel> newMissions;
      
      if (templateSnap.docs.isNotEmpty) {
        newMissions = templateSnap.docs.map((d) {
          final data = d.data();
          return MisiHarianModel(
            // MED-08 Fix: ID deterministic — sama untuk hari yang sama.
            // Sebelumnya pakai millisecondsSinceEpoch yang berbeda setiap kali
            // app dibuka, sehingga updateProgress() tidak bisa menemukan misi.
            misiId: 'daily_${d.id}_$todayKey',
            judul: data['judul'] ?? 'Misi Tanpa Judul',
            deskripsi: data['deskripsi'] ?? '',
            tipe: data['tipe'] ?? 'play_game',
            target: (data['target'] is num) ? (data['target'] as num).toInt() : 1,
            reward: (data['poinReward'] is num) ? (data['poinReward'] as num).toInt() : 10,
            tanggal: now,
          );
        }).toList();
      } else {
        // Jika tidak ada template di db, jangan buat misi harian (kembalikan kosong agar sinkron)
        newMissions = [];
      }

      await _saveMisi(uid, todayKey, newMissions);
      return newMissions;
    } catch (e) {
      debugPrint('⚠️ Error getMisiHariIni: $e');
      return [];
    }
  }

  /// Update progress misi tertentu.
  Future<void> updateProgress({
    required String uid,
    required String misiId,
    required int progressBaru,
  }) async {
    final now = DateTime.now();
    final todayKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    try {
      final docRef = _db
          .collection('users')
          .doc(uid)
          .collection('mission_progress')
          .doc(todayKey);

      final doc = await docRef.get();
      if (!doc.exists || doc.data() == null) return;

      final data = doc.data()!;
      final missions = (data['missions'] as List?)
              ?.map((m) => MisiHarianModel.fromJson(Map<String, dynamic>.from(m)))
              .toList() ??
          [];

      final updatedMissions = missions.map((m) {
        if (m.misiId == misiId) {
          final newProgress = progressBaru;
          final completed = newProgress >= m.target;
          return m.copyWith(
            progress: newProgress,
            isCompleted: completed,
          );
        }
        return m;
      }).toList();

      await docRef.update({
        'missions': updatedMissions.map((m) => m.toJson()).toList(),
      });
    } catch (e) {
      debugPrint('⚠️ Error updateProgress: $e');
    }
  }

  /// Increment progress misi berdasarkan tipe secara efisien (1 read, maksimal 1 write).
  Future<void> incrementByType({
    required String uid,
    required String tipe,
    int amount = 1,
  }) async {
    try {
      // 1. Ambil misi hari ini (ini juga menjamin dokumen di Firestore sudah terinisialisasi)
      final missions = await getMisiHariIni(uid);
      if (missions.isEmpty) return;

      bool hasChanges = false;
      final updatedMissions = missions.map((m) {
        if (m.tipe == tipe && !m.isCompleted) {
          final newProgress = m.progress + amount;
          final completed = newProgress >= m.target;
          hasChanges = true;
          return m.copyWith(
            progress: newProgress,
            isCompleted: completed,
          );
        }
        return m;
      }).toList();

      // 2. Tulis perubahan ke Firestore dalam satu kali operasi jika ada progress yang bertambah
      if (hasChanges) {
        final now = DateTime.now();
        final todayKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        
        await _db
            .collection('users')
            .doc(uid)
            .collection('mission_progress')
            .doc(todayKey)
            .update({
          'missions': updatedMissions.map((m) => m.toJson()).toList(),
        });
      }
    } catch (e) {
      debugPrint('⚠️ Error incrementByType: $e');
    }
  }

  /// Klaim reward misi.
  Future<int> claimReward({
    required String uid,
    required String misiId,
  }) async {
    final now = DateTime.now();
    final todayKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    try {
      final docRef = _db
          .collection('users')
          .doc(uid)
          .collection('mission_progress')
          .doc(todayKey);

      final doc = await docRef.get();
      if (!doc.exists || doc.data() == null) return 0;

      final data = doc.data()!;
      final missions = (data['missions'] as List?)
              ?.map((m) => MisiHarianModel.fromJson(Map<String, dynamic>.from(m)))
              .toList() ??
          [];

      int reward = 0;
      final updatedMissions = missions.map((m) {
        if (m.misiId == misiId && m.canClaim) {
          reward = m.reward;
          return m.copyWith(isClaimed: true);
        }
        return m;
      }).toList();

      if (reward > 0) {
        // Update missions + tambah poin
        final batch = _db.batch();
        batch.update(docRef, {
          'missions': updatedMissions.map((m) => m.toJson()).toList(),
        });
        batch.update(_db.collection('users').doc(uid), {
          'poin': FieldValue.increment(reward),
        });
        await batch.commit();
      }

      return reward;
    } catch (e) {
      debugPrint('⚠️ Error claimReward: $e');
      return 0;
    }
  }

  /// Simpan misi ke Firestore.
  Future<void> _saveMisi(
      String uid, String todayKey, List<MisiHarianModel> missions) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('mission_progress')
        .doc(todayKey)
        .set({
      'missions': missions.map((m) => m.toJson()).toList(),
      'tanggal': Timestamp.now(),
    });
  }
}
