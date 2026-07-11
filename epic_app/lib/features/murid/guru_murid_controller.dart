import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:epic_app/data/models/kelas_model.dart';
import 'package:epic_app/data/models/artwork_model.dart';
import 'package:epic_app/data/repositories/kelas_repository.dart';
import 'package:epic_app/data/repositories/artwork_repository.dart';
import 'package:epic_app/shared/controllers/session_controller.dart';

class StudentViewModel {
  final String uid;
  final String nama;
  final String username;
  final String avatarUrl;
  final int totalPoin;
  final String kelasId;
  final String namaKelas;
  final String namaSekolah;
  final int totalKarya;
  final double avgNilai;
  final DateTime? lastActiveAt;

  StudentViewModel({
    required this.uid,
    required this.nama,
    required this.username,
    required this.avatarUrl,
    required this.totalPoin,
    required this.kelasId,
    required this.namaKelas,
    required this.namaSekolah,
    required this.totalKarya,
    required this.avgNilai,
    this.lastActiveAt,
  });
}

class GuruMuridController extends GetxController {
  final KelasRepository _kelasRepo = KelasRepository();
  final ArtworkRepository _artworkRepo = ArtworkRepository();
  final SessionController _sessionCtrl = Get.find<SessionController>();

  // Rx observables
  final RxString selectedClassFilter = 'Semua'.obs;
  final RxString searchQuery = ''.obs;
  final RxString sortBy = 'nama'.obs; // 'nama' | 'nilai' | 'aktif'
  final RxBool isLoading = true.obs;

  final RxList<KelasModel> classes = <KelasModel>[].obs;
  final RxList<Map<String, dynamic>> allMembers = <Map<String, dynamic>>[].obs;
  final RxList<ArtworkModel> artworks = <ArtworkModel>[].obs;

  // Stream Subscriptions
  StreamSubscription? _kelasSub;
  final List<StreamSubscription> _classSubs = [];
  StreamSubscription? _artworksSub;

  final Map<String, List<Map<String, dynamic>>> _classMembersMap = {};

  @override
  void onInit() {
    super.onInit();
    final guruUid = _sessionCtrl.user?.uid;
    if (guruUid != null) {
      isLoading.value = true;
      _kelasSub = _kelasRepo.watchKelasByGuru(guruUid).listen((classList) {
        classes.assignAll(classList.where((k) => k.isActive).toList());
        _listenToData();
      }, onError: (e) {
        debugPrint('Error loading classes: $e');
        isLoading.value = false;
      });

      // Listen to filter change
      ever(selectedClassFilter, (_) => _listenToData());
    } else {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    _kelasSub?.cancel();
    _cancelClassSubs();
    _artworksSub?.cancel();
    super.onClose();
  }

  void _cancelClassSubs() {
    for (var sub in _classSubs) {
      sub.cancel();
    }
    _classSubs.clear();
  }

  void _listenToData() {
    _cancelClassSubs();
    _classMembersMap.clear();

    final filter = selectedClassFilter.value;
    final activeClasses = classes;

    if (activeClasses.isEmpty) {
      allMembers.clear();
      artworks.clear();
      isLoading.value = false;
      return;
    }

    if (filter == 'Semua') {
      isLoading.value = true;
      int completedStreams = 0;
      for (var kelas in activeClasses) {
        final sub = _kelasRepo.watchLeaderboardKelas(kelas.kelasId).listen((members) {
          final validMembers = members.where((m) => kelas.muridIds.contains(m['uid'])).toList();
          _classMembersMap[kelas.kelasId] = validMembers;
          _mergeAndEmitAllMembers();

          completedStreams++;
          if (completedStreams >= activeClasses.length) {
            isLoading.value = false;
          }
        }, onError: (e) {
          debugPrint('Error in class leaderboard stream: $e');
        });
        _classSubs.add(sub);
      }
    } else {
      // Listen to single class
      final kelas = activeClasses.firstWhereOrNull((k) => k.kelasId == filter);
      if (kelas == null) {
        allMembers.clear();
        artworks.clear();
        isLoading.value = false;
        return;
      }

      isLoading.value = true;
      final sub = _kelasRepo.watchLeaderboardKelas(filter).listen((members) {
        final validMembers = members.where((m) => kelas.muridIds.contains(m['uid'])).map((m) {
          return {
            ...m,
            'kelasId': filter,
            'namaKelas': kelas.namaKelas,
          };
        }).toList();

        allMembers.assignAll(validMembers);
        _listenToArtworks(validMembers.map((m) => m['uid'] as String).toList());
        isLoading.value = false;
      }, onError: (e) {
        debugPrint('Error in single class leaderboard stream: $e');
        isLoading.value = false;
      });
      _classSubs.add(sub);
    }
  }

  void _mergeAndEmitAllMembers() {
    final Map<String, Map<String, dynamic>> uniqueMembers = {};
    _classMembersMap.forEach((kelasId, members) {
      for (var m in members) {
        final uid = m['uid'];
        if (uid != null) {
          final kelas = classes.firstWhereOrNull((k) => k.kelasId == kelasId);
          uniqueMembers[uid] = {
            ...m,
            'kelasId': kelasId,
            'namaKelas': kelas?.namaKelas ?? '',
          };
        }
      }
    });

    allMembers.assignAll(uniqueMembers.values.toList());
    _listenToArtworks(uniqueMembers.keys.toList());
  }

  void _listenToArtworks(List<String> muridIds) {
    _artworksSub?.cancel();
    if (muridIds.isEmpty) {
      artworks.clear();
      return;
    }

    _artworksSub = _artworkRepo.watchArtworksByMurids(muridIds).listen((artList) {
      artworks.assignAll(artList);
    }, onError: (e) {
      debugPrint('Error in artworks stream: $e');
    });
  }

  /// Computed property for list of students sorted and filtered
  List<StudentViewModel> get filteredStudents {
    final query = searchQuery.value.trim().toLowerCase();
    final sortType = sortBy.value;

    // 1. Map allMembers to view models
    final List<StudentViewModel> list = allMembers.map((m) {
      final uid = m['uid'] ?? '';
      final nama = m['namaPanggilan']?.toString().isNotEmpty == true
          ? m['namaPanggilan'].toString()
          : m['namaLengkap']?.toString() ?? '';
      final username = m['username'] ?? '';
      final avatarUrl = m['avatarUrl'] ?? '';
      final totalPoin = (m['poin'] as num?)?.toInt() ?? 0;
      final kelasId = m['kelasId'] ?? '';
      final namaKelas = m['namaKelas'] ?? '';
      final namaSekolah = m['namaSekolah'] ?? '';

      // Find artworks
      final studentArt = artworks.where((a) => a.uid == uid).toList();
      final totalKarya = studentArt.length;
      final avgNilai = totalKarya > 0
          ? studentArt.fold<int>(0, (acc, a) => acc + (a.skorAI ?? 0)) / totalKarya
          : 0.0;

      // Extract lastActiveAt
      DateTime? lastActive;
      final rawActive = m['lastActiveAt'];
      if (rawActive is Timestamp) {
        lastActive = rawActive.toDate();
      } else if (rawActive is DateTime) {
        lastActive = rawActive;
      }

      return StudentViewModel(
        uid: uid,
        nama: nama,
        username: username,
        avatarUrl: avatarUrl,
        totalPoin: totalPoin,
        kelasId: kelasId,
        namaKelas: namaKelas,
        namaSekolah: namaSekolah,
        totalKarya: totalKarya,
        avgNilai: avgNilai,
        lastActiveAt: lastActive,
      );
    }).toList();

    // 2. Filter by search query
    final filtered = list.where((m) {
      if (query.isEmpty) return true;
      return m.nama.toLowerCase().contains(query) ||
          m.username.toLowerCase().contains(query);
    }).toList();

    // 3. Sort dynamically
    if (sortType == 'nama') {
      filtered.sort((a, b) => a.nama.toLowerCase().compareTo(b.nama.toLowerCase()));
    } else if (sortType == 'nilai') {
      filtered.sort((a, b) => b.avgNilai.compareTo(a.avgNilai));
    } else if (sortType == 'aktif') {
      filtered.sort((a, b) {
        if (a.lastActiveAt == null && b.lastActiveAt == null) return 0;
        if (a.lastActiveAt == null) return 1; // Put nulls at the end
        if (b.lastActiveAt == null) return -1;
        return b.lastActiveAt!.compareTo(a.lastActiveAt!);
      });
    }

    return filtered;
  }
}
