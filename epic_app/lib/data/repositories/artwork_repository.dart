// Repository untuk karya gambar — menggunakan Firestore + Firebase Storage
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:epic_app/data/models/artwork_model.dart';
import 'package:epic_app/data/services/storage_service.dart';
import 'package:get/get.dart';

/// Repository untuk mengelola Karya Seni/Gambar di Firestore + Firebase Storage.
class ArtworkRepository {
  final StorageService _storage = Get.find<StorageService>();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _collection = 'artworks';

  /// Menyimpan karya gambar baru ke Storage (gambar) dan Firestore (metadata).
  Future<ArtworkModel> saveArtwork({
    required String uid,
    required String judul,
    required String kategori,
    required int level,
    required Uint8List imageBytes,
    int? skorAI,
    String? grade,
    int? poinDapat,
    required int waktuPengerjaan,
    String? templateId,
    Map<String, dynamic> detailPenilaian = const {},
    int nyawaDigunakan = 0,
    String? kelasId,
    String status = 'dinilai',
  }) async {
    final idKarya = 'art_${DateTime.now().millisecondsSinceEpoch}';
    String? imageUrl;

    try {
      // 1. Upload file ke Firebase Storage
      imageUrl = await _storage.uploadBytes(
        'artworks/$uid/$idKarya.png',
        imageBytes,
      );

      // 2. Buat model data
      final artwork = ArtworkModel(
        uid: uid,
        idKarya: idKarya,
        judulKarya: judul,
        imageUrl: imageUrl,
        kategori: kategori,
        level: level,
        templateId: templateId,
        skorAI: skorAI,
        grade: grade ?? (skorAI != null ? ArtworkModel.calculateGrade(skorAI) : '-'),
        detailPenilaian: detailPenilaian,
        poinDapat: poinDapat,
        waktuPengerjaan: waktuPengerjaan,
        nyawaDigunakan: nyawaDigunakan,
        kelasId: kelasId,
        status: status,
        createdAt: DateTime.now(),
      );

      // 3. Simpan metadata ke Firestore
      await _db.collection(_collection).doc(idKarya).set(artwork.toJson());

      return artwork;
    } catch (e) {
      // ROLLBACK: Jika penyimpanan Firestore gagal, hapus file gambar yang sudah diupload
      if (imageUrl != null) {
        try {
          await _storage.deleteFile(imageUrl);
        } catch (deleteError) {
          debugPrint('Gagal rollback gambar: $deleteError');
        }
      }
      throw Exception('Gagal menyimpan karya: $e');
    }
  }



  /// Mendapatkan detail karya seni berdasarkan ID karya.
  Future<ArtworkModel?> getArtwork(String artworkId) async {
    try {
      final doc = await _db.collection(_collection).doc(artworkId).get();
      if (doc.exists && doc.data() != null) {
        return ArtworkModel.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      debugPrint('⚠️ Error fetching artwork $artworkId: $e');
      return null;
    }
  }

  /// Mendapatkan daftar karya milik user dari Firestore.
  Future<List<ArtworkModel>> getUserArtworks(String uid) async {
    try {
      final snapshot = await _db
          .collection(_collection)
          .where('uid', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => ArtworkModel.fromJson(doc.data()))
          .where((art) => !art.deletedByMurid)
          .toList();
    } catch (e) {
      throw Exception('Gagal mengambil daftar karya: $e');
    }
  }

  /// Mendapatkan daftar karya milik beberapa murid sekaligus.
  Future<List<ArtworkModel>> getArtworksByMurids(List<String> muridIds) async {
    if (muridIds.isEmpty) return [];
    
    final List<ArtworkModel> artworks = [];
    try {
      // Bagi ke dalam chunk berisi maksimal 30 item untuk menghindari batas query whereIn Firestore
      for (int i = 0; i < muridIds.length; i += 30) {
        final end = (i + 30 > muridIds.length) ? muridIds.length : i + 30;
        final batch = muridIds.sublist(i, end);
        
        final query = await _db
            .collection(_collection)
            .where('uid', whereIn: batch)
            .get();
            
        for (final doc in query.docs) {
          artworks.add(ArtworkModel.fromJson(doc.data()));
        }
      }
      
      // Urutkan secara menurun berdasarkan tanggal buat (createdAt) secara lokal
      artworks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return artworks;
    } catch (e) {
      throw Exception('Gagal mengambil karya murid: $e');
    }
  }

  /// Stream real-time karya milik beberapa murid sekaligus dengan chunked streaming.
  Stream<List<ArtworkModel>> watchArtworksByMurids(List<String> muridIds) {
    if (muridIds.isEmpty) {
      return Stream.value(<ArtworkModel>[]).asBroadcastStream();
    }
    
    // Bagi muridIds menjadi beberapa chunk berukuran maksimal 30 (limit whereIn Firestore)
    final List<List<String>> chunks = [];
    for (var i = 0; i < muridIds.length; i += 30) {
      final end = (i + 30 > muridIds.length) ? muridIds.length : i + 30;
      chunks.add(muridIds.sublist(i, end));
    }

    late StreamController<List<ArtworkModel>> controller;
    final List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>> subscriptions = [];
    final Map<int, List<ArtworkModel>> latestData = {};

    void emitCombined() {
      if (controller.isClosed) return;
      final List<ArtworkModel> combined = [];
      for (final list in latestData.values) {
        combined.addAll(list);
      }
      // Urutkan secara menurun berdasarkan tanggal buat (createdAt) secara lokal
      combined.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      controller.add(combined);
    }

    controller = StreamController<List<ArtworkModel>>.broadcast(
      onListen: () {
        for (var i = 0; i < chunks.length; i++) {
          final index = i;
          final subscription = _db
              .collection(_collection)
              .where('uid', whereIn: chunks[index])
              .snapshots()
              .listen(
            (snapshot) {
              final list = snapshot.docs
                  .map((doc) => ArtworkModel.fromJson(doc.data()))
                  .toList();
              latestData[index] = list;
              emitCombined();
            },
            onError: (error) {
              if (!controller.isClosed) {
                controller.addError(error);
              }
            },
          );
          subscriptions.add(subscription);
        }
      },
      onCancel: () {
        for (final sub in subscriptions) {
          sub.cancel();
        }
        subscriptions.clear();
      },
    );

    return controller.stream;
  }

  /// Menghapus atau me-unlink karya dari Firestore dan Storage berdasarkan aturan peran Guru/Murid.
  Future<void> deleteArtwork(ArtworkModel artwork, {required bool isGuru}) async {
    try {
      // Proteksi Kelas Terarsip: Jangan izinkan modifikasi atau penghapusan karya jika kelas terkait sudah diarsipkan
      if (artwork.kelasId != null) {
        final classSnap = await _db.collection('kelas').doc(artwork.kelasId).get();
        if (classSnap.exists && classSnap.data()?['status'] == 'arsip') {
          throw Exception('Kelas Terarsip: Karya ini terkunci dan tidak dapat dihapus.');
        }
      }

      if (isGuru) {
        // Logika GURU:
        if (artwork.deletedByMurid) {
          // Aturan d: Jika guru menghapus karya yang berlabel "dihapus murid", hapus permanen (Firestore + Storage)
          await _db.collection(_collection).doc(artwork.idKarya).delete();
          if (artwork.imageUrl.isNotEmpty) {
            try {
              await _storage.deleteFile(artwork.imageUrl);
            } catch (e) {
              debugPrint('File di storage gagal dihapus: $e');
            }
          }
          debugPrint('🗑️ Karya ${artwork.idKarya} berlabel dihapus murid telah dihapus permanen oleh Guru');
        } else {
          // Aturan a: Guru menghapus karya di kelas -> Hanya UNLINK (kelasId = null), bukan dihapus beneran
          await _db.collection(_collection).doc(artwork.idKarya).update({
            'kelasId': null,
          });
          debugPrint('✅ Karya ${artwork.idKarya} dilepas tautannya (unlinked) dari kelas oleh Guru');
        }
      } else {
        // Logika MURID:
        if (artwork.kelasId == null) {
          // Aturan b: Murid menghapus karya yang tidak terlink ke kelas -> Langsung hapus permanen (Firestore + Storage)
          await _db.collection(_collection).doc(artwork.idKarya).delete();
          if (artwork.imageUrl.isNotEmpty) {
            try {
              await _storage.deleteFile(artwork.imageUrl);
            } catch (e) {
              debugPrint('File di storage gagal dihapus: $e');
            }
          }
          debugPrint('🗑️ Karya pribadi ${artwork.idKarya} dihapus permanen oleh Murid');
        } else {
          // Aturan c: Murid menghapus karya yang terlink ke kelas -> Hanya hapus logis/di sisi murid (deletedByMurid = true)
          await _db.collection(_collection).doc(artwork.idKarya).update({
            'deletedByMurid': true,
          });
          debugPrint('✅ Karya ${artwork.idKarya} ter-label dihapus murid (tetap tersimpan di kelas Guru)');
        }
      }
    } catch (e) {
      throw Exception('Gagal menghapus karya: $e');
    }
  }

  /// Menghapus link kelas pada karya gambar murid tertentu (mengubah kelasId menjadi null).
  Future<void> removeKelasLinkFromMuridArtworks(String kelasId, String muridUid) async {
    try {
      final snapshot = await _db
          .collection(_collection)
          .where('kelasId', isEqualTo: kelasId)
          .where('uid', isEqualTo: muridUid)
          .get();

      final batch = _db.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'kelasId': null});
      }
      await batch.commit();
      debugPrint('✅ Membersihkan kelasId untuk ${snapshot.docs.length} karya milik murid $muridUid');
    } catch (e) {
      throw Exception('Gagal menghapus link karya dari kelas: $e');
    }
  }

  /// Stream real-time karya milik kelas tertentu berdasarkan kelasId.
  Stream<List<ArtworkModel>> watchArtworksByKelas(String kelasId) {
    return _db
        .collection(_collection)
        .where('kelasId', isEqualTo: kelasId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => ArtworkModel.fromJson(doc.data())).toList();
      // Urutkan secara menurun berdasarkan tanggal buat (createdAt) secara lokal
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    }).asBroadcastStream();
  }

  /// Stream real-time karya milik beberapa kelas sekaligus.
  Stream<List<ArtworkModel>> watchArtworksByKelasList(List<String> kelasIds) {
    if (kelasIds.isEmpty) {
      return Stream.value(<ArtworkModel>[]).asBroadcastStream();
    }
    
    // Batasi ke 30 item pertama (batasan whereIn Firestore)
    final chunk = kelasIds.take(30).toList();
    return _db
        .collection(_collection)
        .where('kelasId', whereIn: chunk)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => ArtworkModel.fromJson(doc.data())).toList();
      // Urutkan secara menurun berdasarkan tanggal buat (createdAt) secara lokal
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    }).asBroadcastStream();
  }

  /// Memperbarui karya yang berstatus 'pending' setelah AI selesai memberikan skor.
  Future<void> updateArtworkScore({
    required String idKarya,
    required int skorAI,
    required String grade,
    required int poinDapat,
    required String feedback,
    required Map<String, dynamic> detailPenilaian,
    required String modelAI,
  }) async {
    try {
      await _db.collection(_collection).doc(idKarya).update({
        'skorAI': skorAI,
        'grade': grade,
        'poinDapat': poinDapat,
        'feedback': feedback,
        'detailPenilaian': detailPenilaian,
        'modelAI': modelAI,
        'status': 'dinilai',
      });
      debugPrint('✅ Skor karya $idKarya berhasil diperbarui');
    } catch (e) {
      throw Exception('Gagal memperbarui skor karya: $e');
    }
  }
}
