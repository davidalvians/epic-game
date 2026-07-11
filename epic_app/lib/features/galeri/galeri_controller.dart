import 'dart:async';
import 'package:get/get.dart';
import 'package:epic_app/data/models/artwork_model.dart';
import 'package:epic_app/data/repositories/artwork_repository.dart';
import 'package:epic_app/shared/controllers/session_controller.dart';
import 'package:http/http.dart' as http;
import 'package:epic_app/core/services/ai_scoring_service.dart';
import 'package:epic_app/data/repositories/user_repository.dart';
import 'package:flutter/foundation.dart';

class GaleriController extends GetxController {
  final _artworkRepo = Get.put(ArtworkRepository());
  final _session = Get.find<SessionController>();

  var artworks = <ArtworkModel>[].obs;
  var isLoading = true.obs;
  var errorMessage = ''.obs;
  var selectedFilter = 'Semua'.obs;

  @override
  void onInit() {
    super.onInit();
    loadArtworks();
  }

  Future<void> loadArtworks() async {
    final user = _session.currentUser.value;
    if (user == null) {
      errorMessage.value = 'Sesi tidak ditemukan.';
      isLoading.value = false;
      return;
    }

    try {
      isLoading.value = true;
      errorMessage.value = '';
      
      final result = await _artworkRepo.getUserArtworks(user.uid);
      artworks.value = result;
      
      _checkAndProcessPendingArtworks();
      
    } catch (e) {
      errorMessage.value = 'Gagal memuat galeri.';
    } finally {
      isLoading.value = false;
    }
  }

  List<ArtworkModel> get filteredArtworks {
    if (selectedFilter.value == 'Semua') {
      return artworks;
    }
    return artworks.where((art) => art.kategori.toLowerCase() == selectedFilter.value.toLowerCase()).toList();
  }

  void setFilter(String filter) {
    selectedFilter.value = filter;
  }

  Future<void> _checkAndProcessPendingArtworks() async {
    final pendingArtworks = artworks.where((a) => a.status == 'pending').toList();
    if (pendingArtworks.isEmpty) return;

    final aiService = Get.find<AIScoringService>();
    final userRepo = UserRepository();
    final user = _session.currentUser.value;
    if (user == null) return;

    int successCount = 0;
    int failureCount = 0;

    for (final artwork in pendingArtworks) {
      try {
        // Validasi imageUrl sebelum parsing
        if (artwork.imageUrl.isEmpty) {
          debugPrint('⚠️ Artwork ${artwork.idKarya} punya imageUrl kosong');
          failureCount++;
          continue;
        }

        // Fetch image dengan timeout 30 detik
        final response = await http.get(Uri.parse(artwork.imageUrl))
            .timeout(const Duration(seconds: 30), onTimeout: () {
          throw TimeoutException('Pengambilan gambar timeout');
        });
        if (response.statusCode != 200) {
          debugPrint('⚠️ Fetch gambar failed (HTTP ${response.statusCode})');
          failureCount++;
          continue;
        }
        
        final result = await aiService.evaluateArtwork(
          imageBytes: response.bodyBytes,
          kategori: artwork.kategori,
          level: artwork.level,
          waktuPengerjaan: artwork.waktuPengerjaan,
        );
        
        final multiplier = _getMultiplier(artwork.level);
        final poinDapat = (result.skor * multiplier).round();
        
        await _artworkRepo.updateArtworkScore(
          idKarya: artwork.idKarya,
          skorAI: result.skor,
          grade: result.grade,
          poinDapat: poinDapat,
          feedback: result.feedback,
          detailPenilaian: {
            'modelUsed': result.modelUsed,
          },
          modelAI: result.modelUsed,
        );

        await userRepo.simpanProgress(
          uid: user.uid,
          kategori: artwork.kategori,
          level: artwork.level,
          skorBaru: result.skor,
          poinBaru: poinDapat,
        );

        // Update local list
        final index = artworks.indexWhere((a) => a.idKarya == artwork.idKarya);
        if (index != -1) {
          final updated = artwork.copyWith(
             skorAI: result.skor,
             poinDapat: poinDapat,
             status: 'dinilai',
             detailPenilaian: {
                ...artwork.detailPenilaian,
                'feedback': result.feedback,
                'grade': result.grade,
                'modelUsed': result.modelUsed,
             }
          );
          artworks[index] = updated;
        }
        successCount++;

      } on QuotaExhaustedException {
        debugPrint('Auto-scoring stopped: Kuota AI habis');
        break; // Stop processing other pending artworks
      } catch (e) {
        debugPrint('⚠️ Error auto-scoring artwork ${artwork.idKarya}: $e');
        failureCount++;
      }
    }
    
    // Log hasil
    if (successCount > 0 || failureCount > 0) {
      debugPrint('✅ Auto-retry result: $successCount berhasil, $failureCount gagal');
    }
    
    await _session.refreshUser();
  }

  double _getMultiplier(int level) {
    switch (level) {
      case 1: return 1.0;
      case 2: return 1.5;
      case 3: return 2.0;
      case 4: return 3.0;
      default: return 1.0;
    }
  }
}
