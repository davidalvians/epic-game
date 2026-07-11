import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart' as ex;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_file_plus/open_file_plus.dart';
import 'package:epic_app/core/constants/app_colors.dart';
import 'package:epic_app/core/constants/app_fonts.dart';
import 'package:epic_app/core/utils/epic_snackbar.dart';
import 'package:epic_app/data/models/kelas_model.dart';
import 'package:epic_app/data/models/artwork_model.dart';
import 'package:epic_app/features/kelas/kelas_controller.dart';
import 'package:epic_app/data/repositories/kelas_repository.dart';
import 'package:epic_app/data/repositories/artwork_repository.dart';
import 'package:epic_app/features/galeri/artwork_detail_screen.dart';
import 'package:epic_app/features/murid/profil_murid_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class KelasDetailGuruScreen extends StatefulWidget {
  final KelasModel kelas;

  const KelasDetailGuruScreen({super.key, required this.kelas});

  @override
  State<KelasDetailGuruScreen> createState() => _KelasDetailGuruScreenState();
}

class _KelasDetailGuruScreenState extends State<KelasDetailGuruScreen> {
  final _kelasRepo = KelasRepository();
  final _artworkRepo = ArtworkRepository();
  final _searchCtrl = TextEditingController();

  String _searchQuery = '';
  String _selectedKaryaFilter = 'Semua';
  Color _getKategoriColor(String kat) {
    switch (kat.toLowerCase()) {
      case 'batik':
        return const Color(0xFF8B5CF6);
      case 'anyaman':
        return const Color(0xFF10B981);
      default:
        return AppColors.primary;
    }
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  // Menyelaraskan murid yang keluar sendiri (belum tercatat di exitedMurids) di latar belakang secara aman
  Future<void> _syncMissingExitedMurids(KelasModel kelas, List<ArtworkModel> artworks) async {
    if (kelas.status == 'arsip') return; // Jangan ubah apa pun jika kelas sudah diarsipkan (read-only)
    
    // 1. Cari unique uids dari artworks
    final uniqueUids = artworks.map((a) => a.uid).toSet().toList();
    
    final db = FirebaseFirestore.instance;
    
    try {
      final kelasRef = db.collection('kelas').doc(kelas.kelasId);
      final kelasSnap = await kelasRef.get();
      if (!kelasSnap.exists || kelasSnap.data() == null) return;
      
      final activeMuridIds = List<String>.from(kelasSnap.data()!['muridIds'] ?? []);
      final currentExited = List<dynamic>.from(kelasSnap.data()!['exitedMurids'] ?? []);
      final updatedExited = List<Map<String, dynamic>>.from(
        currentExited.map((e) => Map<String, dynamic>.from(e as Map))
      );
      
      bool hasUpdates = false;
      
      // A. Bersihkan murid aktif (yang baru gabung kembali) dari exitedMurids
      final originalLength = updatedExited.length;
      updatedExited.removeWhere((e) => activeMuridIds.contains(e['uid']));
      if (updatedExited.length != originalLength) {
        hasUpdates = true;
        debugPrint('🧹 Mendeteksi murid aktif yang bergabung kembali. Menghapus entri dari riwayat keluar/alumni...');
      }
      
      // B. Cari missing exited uids (murid yang memiliki karya tetapi tidak ada di activeMuridIds dan tidak ada di exitedMurids)
      final loggedExitedUids = updatedExited.map((m) => m['uid']?.toString() ?? '').toSet();
      final missingUids = uniqueUids.where((uid) => !activeMuridIds.contains(uid) && !loggedExitedUids.contains(uid)).toList();
      
      if (missingUids.isNotEmpty) {
        debugPrint('🔍 Menemukan ${missingUids.length} murid keluar mandiri yang belum tercatat. Melakukan sinkronisasi oleh Guru...');
        
        for (final uid in missingUids) {
          final userSnap = await db.collection('users').doc(uid).get();
          if (userSnap.exists && userSnap.data() != null) {
            final data = userSnap.data()!;
            final namaLengkap = data['namaLengkap']?.toString() ?? '';
            final namaPanggilan = data['namaPanggilan']?.toString() ?? '';
            
            final exitLog = {
              'uid': uid,
              'namaLengkap': namaLengkap.isNotEmpty ? namaLengkap : namaPanggilan,
              'namaPanggilan': namaPanggilan,
              'tanggalKeluar': DateTime.now().toIso8601String(),
              'alasan': 'keluar_sendiri',
            };
            
            // Singkirkan duplikat sebelum menambahkan yang baru
            updatedExited.removeWhere((e) => e['uid'] == uid);
            updatedExited.add(exitLog);
            hasUpdates = true;
          }
        }
      }
      
      if (hasUpdates) {
        await kelasRef.update({
          'exitedMurids': updatedExited,
        });
        debugPrint('✅ Berhasil menyinkronkan keanggotaan dan riwayat keluar tanpa duplikat');
      }
    } catch (e) {
      debugPrint('⚠️ Gagal menyinkronkan keanggotaan dan riwayat keluar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<KelasController>();

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF9F0),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
            onPressed: () => Get.back(),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.kelas.namaKelas,
                style: AppFonts.heading3(color: AppColors.textPrimary),
              ),
              Text(
                widget.kelas.namaSekolah,
                style: AppFonts.caption(color: AppColors.textSecondary),
              ),
            ],
          ),
          bottom: const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.inactive,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelStyle: TextStyle(fontFamily: 'FredokaOne', fontSize: 13),
            tabs: [
              Tab(text: 'Murid'),
              Tab(text: 'Karya'),
              Tab(text: 'Ranking'),
              Tab(text: 'Info'),
            ],
          ),
        ),
        body: Builder(
          builder: (rootContext) {
            return StreamBuilder<KelasModel?>(
              stream: _kelasRepo.watchKelasDetail(widget.kelas.kelasId),
              initialData: widget.kelas,
              builder: (context, snapshot) {
                if (snapshot.hasError || snapshot.data == null) {
                  return const Scaffold(
                    body: Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  );
                }

                final currentKelas = snapshot.data ?? widget.kelas;

                return StreamBuilder<List<ArtworkModel>>(
                  stream: _artworkRepo.watchArtworksByKelas(currentKelas.kelasId),
                  builder: (context, artSnap) {
                    if (artSnap.hasError) {
                      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                    }
                    final artworks = artSnap.data ?? [];
                    final isLoadingArt = artSnap.connectionState == ConnectionState.waiting;

                    if (artworks.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _syncMissingExitedMurids(currentKelas, artworks);
                      });
                    }

                    return TabBarView(
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _buildMuridTab(currentKelas, controller, artworks),
                        _buildKaryaTab(currentKelas, artworks, isLoading: isLoadingArt),
                        _buildRankingTab(currentKelas),
                        _buildInfoTab(currentKelas, controller, rootContext, artworks),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  // ─── TAB 1: MURID ─────────────────────────────────────────────────────────

  Widget _buildMuridTab(KelasModel kelas, KelasController controller, List<ArtworkModel> artworks) {
    return Column(
      children: [
        // --- Statistik Kelas Ringkas ---
        _buildStatistikGrid(kelas, artworks),

        // --- Search Bar ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: TextFormField(
            controller: _searchCtrl,
            style: AppFonts.bodyText(),
            onChanged: (val) {
              setState(() => _searchQuery = val.trim().toLowerCase());
            },
            decoration: InputDecoration(
              hintText: 'Cari nama murid...',
              hintStyle: AppFonts.bodySmall(color: const Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, color: Colors.grey),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
        ),

        // --- Daftar Murid ---
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _kelasRepo.watchLeaderboardKelas(kelas.kelasId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }

              final allMembers = snapshot.data ?? [];

              // HANYA tampilkan murid yang UID-nya ada di daftar kelas.muridIds aktual!
              final classMembers = allMembers.where((m) => kelas.muridIds.contains(m['uid'] ?? '')).toList();

              // Filter berdasarkan pencarian
              final members = classMembers.where((m) {
                final nama = (m['namaPanggilan'] ?? m['namaLengkap'] ?? '').toString().toLowerCase();
                final username = (m['username'] ?? '').toString().toLowerCase();
                return nama.contains(_searchQuery) || username.contains(_searchQuery);
              }).toList();

              if (members.isEmpty) {
                return _buildTabEmptyState(
                  icon: Icons.people_outline_rounded,
                  title: 'Murid Tidak Ditemukan',
                  subtitle: _searchQuery.isEmpty
                      ? 'Bagikan kode kelas agar murid dapat bergabung!'
                      : 'Coba kata kunci pencarian yang lain.',
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                physics: const BouncingScrollPhysics(),
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final member = members[index];
                  final uid = member['uid'] ?? '';
                  final nama = member['namaPanggilan']?.toString().isNotEmpty == true
                      ? member['namaPanggilan']
                      : member['namaLengkap'];
                  final username = member['username'] ?? '';
                  final avatarUrl = member['avatarUrl'] ?? '';

                  // Hitung data karya & avg murid lokal
                  final studentArt = artworks.where((a) => a.uid == uid).toList();
                  final totalKarya = studentArt.length;
                  final avgNilai = totalKarya > 0
                      ? studentArt.fold<int>(0, (acc, a) => acc + (a.skorAI ?? 0)) / totalKarya
                      : 0.0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: const Color(0xFFFFF7ED),
                          backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                          child: avatarUrl.isEmpty
                              ? Text(
                                  nama.isNotEmpty ? nama[0].toUpperCase() : '?',
                                  style: const TextStyle(
                                    fontFamily: 'FredokaOne',
                                    color: AppColors.primary,
                                    fontSize: 18,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nama,
                                style: AppFonts.bodyText(weight: FontWeight.bold),
                              ),
                              Text(
                                '@$username',
                                style: AppFonts.caption(color: Colors.grey.shade500),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  _buildSmallStatChip(
                                    Icons.palette_outlined,
                                    '$totalKarya karya',
                                    const Color(0xFF3B82F6),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildSmallStatChip(
                                    Icons.star_rounded,
                                    'Avg: ${avgNilai.toStringAsFixed(1)}',
                                    Colors.amber.shade700,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          children: [
                            TextButton(
                              onPressed: () {
                                Get.to(() => ProfilMuridScreen(
                                      muridUid: uid,
                                      kelasId: widget.kelas.kelasId,
                                      kelasName: widget.kelas.namaKelas,
                                      sekolah: widget.kelas.namaSekolah,
                                    ));
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Lihat Detail',
                                style: TextStyle(fontFamily: 'FredokaOne', fontSize: 11),
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (kelas.status != 'arsip')
                              IconButton(
                                icon: const Icon(Icons.person_remove_rounded, color: Color(0xFFEF4444), size: 18),
                                onPressed: () => _confirmRemoveMurid(context, controller, uid, nama),
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(6),
                                tooltip: 'Keluarkan Murid',
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),

        // --- Riwayat Siswa Keluar / Alumni ---
        if (kelas.exitedMurids.isNotEmpty) ...[
          const Divider(height: 16, thickness: 1, color: Color(0xFFE2E8F0)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.history_edu_rounded, color: Colors.grey, size: 18),
                const SizedBox(width: 8),
                Text(
                  '📋 RIWAYAT SISWA KELUAR / ALUMNI',
                  style: TextStyle(
                    fontFamily: 'FredokaOne',
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              physics: const BouncingScrollPhysics(),
              itemCount: kelas.exitedMurids.length,
              itemBuilder: (context, index) {
                final m = kelas.exitedMurids[index];
                final uid = m['uid'] ?? '';
                final nama = m['namaLengkap'] ?? m['namaPanggilan'] ?? 'Murid';
                final tanggalStr = m['tanggalKeluar'] != null 
                    ? _formatDate(DateTime.tryParse(m['tanggalKeluar'].toString()) ?? DateTime.now())
                    : '-';
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.grey.shade200,
                        child: Text(
                          nama.isNotEmpty ? nama[0].toUpperCase() : '?',
                          style: TextStyle(fontFamily: 'FredokaOne', color: Colors.grey.shade500, fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nama,
                              style: AppFonts.bodySmall(color: Colors.grey.shade800, weight: FontWeight.bold),
                            ),
                            Text(
                              'Keluar pada $tanggalStr',
                              style: AppFonts.caption(color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                      if (kelas.status != 'arsip') ...[
                        IconButton(
                          icon: const Icon(Icons.delete_sweep_rounded, color: Colors.amber, size: 18),
                          onPressed: () => _confirmRemoveArtworkLink(context, controller, kelas.kelasId, uid, nama),
                          tooltip: 'Hapus Karya dari Kelas',
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(4),
                        ),
                        IconButton(
                          icon: const Icon(Icons.clear_rounded, color: Colors.grey, size: 16),
                          onPressed: () => _confirmClearExitedHistory(context, controller, kelas.kelasId, uid, nama),
                          tooltip: 'Bersihkan Riwayat',
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(4),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSmallStatChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatistikGrid(KelasModel kelas, List<ArtworkModel> artworks) {
    final activeCount = kelas.muridIds.length;
    // Hitung rata-rata nilai kelas yang sesungguhnya
    final totalScores = artworks.fold<int>(0, (acc, a) => acc + (a.skorAI ?? 0));
    final avgNilaiReal = artworks.isNotEmpty ? totalScores / artworks.length : kelas.avgNilai;
    final totalKaryaReal = artworks.isNotEmpty ? artworks.length : kelas.totalKarya;

    // Menghitung murid belum main (poin 0 / belum submit karya)
    final zeroWorksCount = kelas.muridIds.where((uid) => !artworks.any((a) => a.uid == uid)).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📊 STATISTIK KELAS',
            style: TextStyle(
              fontFamily: 'FredokaOne',
              fontSize: 12,
              color: AppColors.textPrimary,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _buildStatCard('Avg Nilai', avgNilaiReal.toStringAsFixed(1), const Color(0xFFF59E0B)),
              _buildStatCard('Total Karya', '$totalKaryaReal', const Color(0xFF3B82F6)),
              _buildStatCard('Murid Aktif', '$activeCount', const Color(0xFF10B981)),
              _buildStatCard('Belum Main', '$zeroWorksCount orang', const Color(0xFF64748B)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: 'FredokaOne',
              fontSize: 18,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppFonts.caption(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  // ─── TAB 2: KARYA ──────────────────────────────────────────────────────────

  Widget _buildKaryaTab(KelasModel kelas, List<ArtworkModel> artworks, {bool isLoading = false}) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    final filteredArtworks = _selectedKaryaFilter == 'Semua'
        ? artworks
        : artworks.where((a) => a.kategori.toLowerCase() == _selectedKaryaFilter.toLowerCase()).toList();

    return Column(
      children: [
        // --- Filter Sub-kategori ---
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: ['Semua', 'Keris', 'Batik', 'Anyaman'].map((cat) {
              final isSel = _selectedKaryaFilter == cat;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedKaryaFilter = cat);
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSel ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSel ? AppColors.primary : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    cat,
                    style: TextStyle(
                      fontFamily: 'FredokaOne',
                      fontSize: 12,
                      color: isSel ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // --- Grid Karya ---
        Expanded(
          child: filteredArtworks.isEmpty
              ? _buildTabEmptyState(
                  icon: Icons.palette_outlined,
                  title: 'Belum Ada Karya',
                  subtitle: _selectedKaryaFilter == 'Semua'
                      ? 'Murid-murid belum mensubmit karya gambar mereka.'
                      : 'Belum ada karya dengan kategori ini.',
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: filteredArtworks.length,
                  itemBuilder: (context, index) {
                    final art = filteredArtworks[index];
                    return _buildKaryaGridCard(context, kelas, art);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildKaryaGridCard(BuildContext context, KelasModel kelas, ArtworkModel art) {
    final isExited = kelas.exitedMurids.any((m) => m['uid'] == art.uid);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: art.imageUrl.isNotEmpty
                      ? Image.network(
                          art.imageUrl,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: const Color(0xFFF1F5F9),
                          child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        art.judulKarya.isNotEmpty ? art.judulKarya : 'Karya Seni',
                        style: const TextStyle(
                          fontFamily: 'FredokaOne',
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      FutureBuilder<KelasModel?>(
                        future: _kelasRepo.getKelasDetail(widget.kelas.kelasId),
                        builder: (context, snapshot) {
                          // Tampilkan nama pembuat (murid)
                          return StreamBuilder<List<Map<String, dynamic>>>(
                            stream: _kelasRepo.watchLeaderboardKelas(widget.kelas.kelasId),
                            builder: (context, listSnap) {
                              final members = listSnap.data ?? [];
                              final creator = members.firstWhereOrNull((m) => m['uid'] == art.uid);
                              String name = 'Murid';
                              if (creator != null) {
                                name = creator['namaPanggilan'] ?? creator['namaLengkap'] ?? 'Murid';
                              } else {
                                // Cari di exitedMurids
                                final ex = kelas.exitedMurids.firstWhereOrNull((m) => m['uid'] == art.uid);
                                if (ex != null) {
                                  name = ex['namaPanggilan']?.toString().isNotEmpty == true
                                      ? ex['namaPanggilan']
                                      : ex['namaLengkap'] ?? 'Murid';
                                }
                              }
                              return Text(
                                name,
                                style: AppFonts.caption(color: AppColors.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Grade Badge Top Right
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _getKategoriColor(art.kategori),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 4, offset: const Offset(0, 2))],
                ),
                child: Center(
                  child: Text(
                    art.actualGrade,
                    style: const TextStyle(
                      fontFamily: 'FredokaOne',
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),

            // Alumni Overlay Badge
            if (isExited)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316), // Orange
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.directions_run_rounded, color: Colors.white, size: 10),
                      SizedBox(width: 4),
                      Text(
                        'Alumni / Keluar',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Nunito',
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Deleted by Student Overlay Banner
            if (art.deletedByMurid == true)
              Positioned(
                bottom: 48,
                left: 0,
                right: 0,
                child: Container(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.9), // Semi-transparent red
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: const Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 12),
                        SizedBox(width: 4),
                        Text(
                          'Dihapus oleh Murid',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Nunito',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Inkwell Click overlay
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Get.to(() => ArtworkDetailScreen(artwork: art)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── TAB 3: RANKING ────────────────────────────────────────────────────────

  Widget _buildRankingTab(KelasModel kelas) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _kelasRepo.watchLeaderboardKelas(kelas.kelasId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        final allMembers = snapshot.data ?? [];

        // HANYA tampilkan murid yang UID-nya ada di daftar kelas.muridIds aktual!
        final members = allMembers.where((m) => kelas.muridIds.contains(m['uid'] ?? '')).toList();

        if (members.isEmpty) {
          return _buildTabEmptyState(
            icon: Icons.emoji_events_outlined,
            title: 'Belum Ada Ranking',
            subtitle: 'Murid belum mendapatkan poin dari game gambar.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          physics: const BouncingScrollPhysics(),
          itemCount: members.length,
          itemBuilder: (context, index) {
            final member = members[index];
            final nama = member['namaPanggilan']?.toString().isNotEmpty == true
                ? member['namaPanggilan']
                : member['namaLengkap'];
            final poin = member['poin'] ?? 0;
            final avatarUrl = member['avatarUrl'] ?? '';
            final rank = index + 1;

            final isTop3 = rank <= 3;
            Color rankColor;
            if (rank == 1) {
              rankColor = const Color(0xFFFFD700); // Gold
            } else if (rank == 2) {
              rankColor = const Color(0xFFC0C0C0); // Silver
            } else if (rank == 3) {
              rankColor = const Color(0xFFCD7F32); // Bronze
            } else {
              rankColor = const Color(0xFF94A3B8);
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isTop3 ? rankColor.withValues(alpha: 0.3) : const Color(0xFFF1F5F9),
                  width: isTop3 ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isTop3 ? rankColor.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.01),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Row(
                children: [
                  // Rank Medal / Number
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isTop3 ? rankColor : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        fontFamily: 'FredokaOne',
                        fontSize: 16,
                        color: isTop3 ? Colors.white : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFFF1F5F9),
                    backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl.isEmpty
                        ? Text(
                            nama.isNotEmpty ? nama[0].toUpperCase() : '?',
                            style: const TextStyle(fontFamily: 'FredokaOne', color: Color(0xFF94A3B8)),
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      nama,
                      style: AppFonts.bodyText(weight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: rankColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.stars_rounded, size: 14, color: isTop3 ? rankColor : AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          '$poin',
                          style: TextStyle(
                            fontFamily: 'FredokaOne',
                            fontSize: 13,
                            color: isTop3 ? rankColor : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ─── TAB 4: INFO & SETTINGS (ZONA BERBAHAYA) ──────────────────────────────────

  Widget _buildInfoTab(KelasModel kelas, KelasController controller, BuildContext rootContext, List<ArtworkModel> artworks) {
    final isAktif = kelas.status == 'aktif';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card 1: DETAIL KELAS
          Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text(
                        '📋 DETAIL KELAS',
                        style: TextStyle(
                          fontFamily: 'FredokaOne',
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _buildInfoRow('Nama Kelas', kelas.namaKelas),
                  _buildInfoRow('Tingkat Kelas', kelas.tingkat),
                  _buildInfoRow('Nama Sekolah', kelas.namaSekolah),
                  _buildInfoRow('Tahun Ajaran', kelas.tahunAjaran),
                  _buildInfoRow('Mata Pelajaran', kelas.mataPelajaran.isNotEmpty ? kelas.mataPelajaran : 'Seni Budaya'),
                  _buildInfoRow('Tanggal Dibuat', _formatDate(kelas.createdAt)),
                  _buildInfoRow(
                    'Status',
                    isAktif ? '🟢 Aktif' : '⚫ Nonaktif',
                    isBoldValue: true,
                    valueColor: isAktif ? const Color(0xFF22C55E) : Colors.grey,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Card 2: KODE & QR KELAS
          Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.qr_code_2_rounded, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text(
                        '🔑 KODE & QR KELAS',
                        style: TextStyle(
                          fontFamily: 'FredokaOne',
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFFEDD5)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              kelas.kodeKelas,
                              style: const TextStyle(
                                fontFamily: 'FredokaOne',
                                fontSize: 24,
                                color: Color(0xFFEA580C),
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, color: Color(0xFFEA580C)),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: kelas.kodeKelas));
                                EpicSnackbar.success('Tersalin', 'Kode kelas disalin ke clipboard');
                              },
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => _showQRCodeDialog(rootContext, kelas),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEA580C),
                            side: const BorderSide(color: Color(0xFFEA580C)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.qr_code_rounded, size: 18),
                          label: const Text(
                            'Tampilkan QR Code',
                            style: TextStyle(fontFamily: 'FredokaOne', fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Card 2.5: EKSPOR LAPORAN KELAS
          Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.assessment_outlined, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text(
                        '📋 EKSPOR LAPORAN KELAS',
                        style: TextStyle(
                          fontFamily: 'FredokaOne',
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Text(
                    'Dapatkan laporan nilai lengkap seluruh murid dalam format CSV yang siap disalin ke Microsoft Excel atau Google Sheets.',
                    style: AppFonts.bodySmall(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () => _showExportDialog(context, kelas, artworks),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.download_rounded),
                      label: const Text(
                        'Ekspor Laporan Kelas (.csv)',
                        style: TextStyle(fontFamily: 'FredokaOne', fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Card 3: PENGELOLAAN ARSIP KELAS
          Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.archive_outlined, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text(
                        '📁 PENGELOLAAN ARSIP KELAS',
                        style: TextStyle(
                          fontFamily: 'FredokaOne',
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  if (kelas.status == 'arsip') ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4), // light green 50
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFDCFCE7)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Kelas ini telah diarsipkan dan berstatus Read-Only. Seluruh data nilai terlindungi secara aman.',
                              style: AppFonts.bodySmall(color: const Color(0xFF15803D), weight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () => _showDeleteKelasSecureConfirmation(context, controller, kelas),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.delete_forever_rounded),
                        label: const Text(
                          'Hapus Kelas Permanen',
                          style: TextStyle(fontFamily: 'FredokaOne', fontSize: 13),
                        ),
                      ),
                    ),
                  ] else ...[
                    Text(
                      'Arsip kelas membekukan seluruh data (Read-Only) dan otomatis menyembunyikannya dari menu siswa agar data tahun ajaran tidak terganggu.',
                      style: AppFonts.bodySmall(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: () => _showArchiveConfirmation(context, controller, kelas),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.archive_rounded),
                              label: const Text(
                                'Arsipkan Kelas',
                                style: TextStyle(fontFamily: 'FredokaOne', fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: () => _showToggleStatusConfirmation(context, controller, kelas),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: isAktif ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                side: BorderSide(color: isAktif ? const Color(0xFFFCA5A5) : const Color(0xFFA7F3D0)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: Icon(isAktif ? Icons.power_settings_new_rounded : Icons.play_arrow_rounded),
                              label: Text(
                                isAktif ? 'Nonaktifkan' : 'Aktifkan Kembali',
                                style: const TextStyle(fontFamily: 'FredokaOne', fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBoldValue = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppFonts.bodySmall(color: AppColors.textSecondary)),
          Text(
            value,
            style: AppFonts.bodySmall(
              color: valueColor ?? AppColors.textPrimary,
              weight: isBoldValue ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ─── DIALOGS & SHEET HELPERS ──────────────────────────────────────────────────

  Widget _buildTabEmptyState({required IconData icon, required String title, required String subtitle}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: AppColors.inactive),
            const SizedBox(height: 16),
            Text(
              title,
              style: AppFonts.heading3(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppFonts.bodySmall(color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  void _showToggleStatusConfirmation(BuildContext context, KelasController controller, KelasModel kelas) {
    final isAktif = kelas.status == 'aktif';

    if (!isAktif) {
      // Aktifkan kembali secara instan / dialog simpel
      Get.dialog(
        AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Aktifkan Kelas Kembali?', style: TextStyle(fontFamily: 'FredokaOne')),
          content: Text('Kelas "${kelas.namaKelas}" akan kembali aktif. Murid dapat bergabung dan belajar kembali.'),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                Get.back();
                controller.toggleStatusKelas(kelas.kelasId, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Aktifkan'),
            ),
          ],
        ),
      );
      return;
    }

    // Dialog Deaktivasi Komprehensif (Bagian 10)
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Nonaktifkan Kelas?',
          style: AppFonts.heading3(color: const Color(0xFFEF4444)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kelas "${kelas.namaKelas}" akan dinonaktifkan.',
              style: AppFonts.bodyText(weight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Text(
              'Yang terjadi setelah dinonaktifkan:',
              style: AppFonts.bodySmall(color: AppColors.textPrimary, weight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            _buildConsequenceRow(true, 'Data murid tetap tersimpan'),
            _buildConsequenceRow(true, 'Karya & nilai tetap ada'),
            _buildConsequenceRow(true, 'Bisa diaktifkan kembali'),
            const SizedBox(height: 6),
            _buildConsequenceRow(false, 'Murid tidak bisa join lagi'),
            _buildConsequenceRow(false, 'Kode kelas tidak berlaku'),
            _buildConsequenceRow(false, 'Tidak muncul di daftar aktif'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'Batal',
              style: TextStyle(fontFamily: 'FredokaOne', color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              controller.toggleStatusKelas(kelas.kelasId, false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              'Nonaktifkan',
              style: TextStyle(fontFamily: 'FredokaOne'),
            ),
          ),
        ],
      ),
    );
  }

  void _showArchiveConfirmation(BuildContext context, KelasController controller, KelasModel kelas) {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: const Color(0xFFFFF9F0),
        title: Row(
          children: [
            const Icon(Icons.archive_rounded, color: AppColors.primary, size: 28),
            const SizedBox(width: 8),
            Text(
              'Arsipkan Kelas?',
              style: AppFonts.heading3(color: AppColors.textPrimary),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Apakah Anda yakin ingin mengarsipkan kelas "${kelas.namaKelas}"?',
              style: AppFonts.bodyText(weight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Text(
              'Tindakan ini akan:',
              style: AppFonts.bodySmall(color: AppColors.textPrimary, weight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            _buildConsequenceRow(true, 'Membekukan semua data (Read-Only)'),
            _buildConsequenceRow(true, 'Data nilai & karya tersimpan rapi'),
            _buildConsequenceRow(false, 'Siswa tidak dapat mengakses kelas ini'),
            _buildConsequenceRow(false, 'Kelas disembunyikan dari dashboard utama'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'Batal',
              style: TextStyle(fontFamily: 'FredokaOne', color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              controller.archiveKelas(kelas.kelasId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              'Ya, Arsipkan',
              style: TextStyle(fontFamily: 'FredokaOne'),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteKelasSecureConfirmation(BuildContext context, KelasController controller, KelasModel kelas) {
    final textController = TextEditingController();
    final RxBool isNameMatched = false.obs;

    textController.addListener(() {
      isNameMatched.value = textController.text.trim().toLowerCase() == kelas.namaKelas.trim().toLowerCase();
    });

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: const Color(0xFFFFF9F0),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Hapus Kelas Permanen?',
                style: AppFonts.heading3(color: const Color(0xFFEF4444)),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tindakan ini tidak bisa dibatalkan! Seluruh data kelas, keanggotaan siswa, dan statistik kelas "${kelas.namaKelas}" akan dihapus permanen dari sistem.',
              style: AppFonts.bodySmall(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16),
            Text(
              'Karya yang sudah terkirim oleh siswa tidak akan terhapus dari akun siswa masing-masing, namun tautan kelas akan diputus.',
              style: AppFonts.bodySmall(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Text(
              'Ketik "${kelas.namaKelas}" untuk mengonfirmasi:',
              style: AppFonts.bodySmall(color: AppColors.textPrimary, weight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: textController,
              decoration: InputDecoration(
                hintText: 'Nama kelas',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                ),
              ),
              style: AppFonts.bodySmall(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              textController.dispose();
              Navigator.of(context).pop(); // Tutup dialog secara native!
            },
            child: Text(
              'Batal',
              style: TextStyle(fontFamily: 'FredokaOne', color: Colors.grey.shade600),
            ),
          ),
          Obx(() {
            return ElevatedButton(
              onPressed: isNameMatched.value
                  ? () {
                      textController.dispose();
                      Navigator.of(context).pop(); // Tutup dialog secara native!
                      Get.back(); // Keluar dari detail screen
                      Future.delayed(const Duration(milliseconds: 400), () {
                        controller.deleteKelasPermanen(kelas.kelasId); // Hapus permanen setelah pop selesai
                      });
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                disabledForegroundColor: Colors.grey.shade500,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'Hapus Permanen',
                style: TextStyle(fontFamily: 'FredokaOne'),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildConsequenceRow(bool isPositive, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            isPositive ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: isPositive ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppFonts.caption(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmRemoveMurid(BuildContext context, KelasController controller, String muridUid, String nama) {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Keluarkan Murid?', style: TextStyle(fontFamily: 'FredokaOne')),
        content: Text('Apakah Anda yakin ingin mengeluarkan "$nama" dari kelas ini?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Batal', style: TextStyle(fontFamily: 'FredokaOne', color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              controller.removeMurid(widget.kelas.kelasId, muridUid);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Keluarkan', style: TextStyle(fontFamily: 'FredokaOne')),
          ),
        ],
      ),
    );
  }

  void _confirmRemoveArtworkLink(BuildContext context, KelasController controller, String kelasId, String muridUid, String nama) {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Hapus Karya dari Kelas?', style: TextStyle(fontFamily: 'FredokaOne', color: Colors.amber)),
        content: Text('Apakah Anda yakin ingin memutuskan keterkaitan karya "$nama" dengan kelas ini? Nilai dan karya tidak akan dihitung dalam statistik kelas ini lagi.'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Batal', style: TextStyle(fontFamily: 'FredokaOne', color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              controller.removeMuridArtworkLink(kelasId, muridUid, nama);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Ya, Hapus Karya', style: TextStyle(fontFamily: 'FredokaOne')),
          ),
        ],
      ),
    );
  }

  void _confirmClearExitedHistory(BuildContext context, KelasController controller, String kelasId, String muridUid, String nama) {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Bersihkan Riwayat?', style: TextStyle(fontFamily: 'FredokaOne')),
        content: Text('Apakah Anda yakin ingin menghapus riwayat keluar "$nama" sepenuhnya dari kelas ini?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Batal', style: TextStyle(fontFamily: 'FredokaOne', color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              controller.clearExitedMuridHistory(kelasId, muridUid);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Ya, Bersihkan', style: TextStyle(fontFamily: 'FredokaOne')),
          ),
        ],
      ),
    );
  }

  void _showQRCodeDialog(BuildContext context, KelasModel kelas) {
    final qrData = kelas.qrData.isNotEmpty
        ? kelas.qrData
        : jsonEncode({
            'type': 'epic_kelas',
            'code': kelas.kodeKelas,
          });

    final GlobalKey dialogQrKey = GlobalKey();
    bool isSavingDialog = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> saveQRDialog() async {
              if (isSavingDialog) return;

              // Check storage access permission
              final hasAccess = await Gal.hasAccess(toAlbum: true);
              if (!hasAccess) {
                final granted = await Gal.requestAccess(toAlbum: true);
                if (!granted) {
                  EpicSnackbar.error(
                    'Izin Diperlukan',
                    'Izin penyimpanan diperlukan untuk menyimpan QR Code.',
                  );
                  return;
                }
              }

              setDialogState(() => isSavingDialog = true);

              try {
                // Wait short time to ensure frame is painted
                await Future.delayed(const Duration(milliseconds: 150));

                final boundary = dialogQrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
                if (boundary == null) throw Exception('Gagal memproses QR Code card');

                final image = await boundary.toImage(pixelRatio: 3.0);
                final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
                if (byteData == null) throw Exception('Gagal mengonversi QR Code ke data bytes');

                final pngBytes = byteData.buffer.asUint8List();

                await Gal.putImageBytes(
                  pngBytes,
                  album: 'EPIC App',
                  name: 'EPIC_QR_${kelas.kodeKelas}',
                );

                EpicSnackbar.success(
                  'Berhasil Disimpan 📸',
                  'QR Code berhasil disimpan ke galeri foto Anda.',
                );
              } catch (e) {
                debugPrint('Error saving dialog QR: $e');
                EpicSnackbar.error(
                  'Gagal Menyimpan',
                  'Terjadi kesalahan saat menyimpan gambar ke galeri.',
                );
              } finally {
                setDialogState(() => isSavingDialog = false);
              }
            }

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
              backgroundColor: const Color(0xFFFFF9F0),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Scan QR Kelas',
                        style: AppFonts.heading3(color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 16),
                      RepaintBoundary(
                        key: dialogQrKey,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              QrImageView(
                                data: qrData,
                                version: QrVersions.auto,
                                size: 180.0,
                                backgroundColor: Colors.white,
                                eyeStyle: const QrEyeStyle(
                                  eyeShape: QrEyeShape.square,
                                  color: AppColors.dark,
                                ),
                                dataModuleStyle: const QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.square,
                                  color: AppColors.dark,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'KODE MANUAL',
                                style: AppFonts.caption(color: Colors.grey.shade400).copyWith(letterSpacing: 1),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                kelas.kodeKelas,
                                style: const TextStyle(
                                  fontFamily: 'FredokaOne',
                                  fontSize: 22,
                                  color: Color(0xFFEA580C),
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          OutlinedButton.icon(
                            onPressed: isSavingDialog ? null : saveQRDialog,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFEA580C),
                              side: const BorderSide(color: Color(0xFFEA580C)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            icon: isSavingDialog
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFEA580C)),
                                  )
                                : const Icon(Icons.download_rounded, size: 16),
                            label: Text(
                              isSavingDialog ? 'Menyimpan...' : 'Galeri',
                              style: const TextStyle(fontFamily: 'FredokaOne', fontSize: 12),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            ),
                            child: const Text('Tutup', style: TextStyle(fontFamily: 'FredokaOne', fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<String> _saveReportFile(String filename, List<int> bytes) async {
    String targetPath = '';
    if (Platform.isAndroid) {
      try {
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (await downloadDir.exists()) {
          targetPath = '${downloadDir.path}/$filename';
          final file = File(targetPath);
          if (await file.exists()) {
            final dotIndex = filename.lastIndexOf('.');
            final namePart = dotIndex != -1 ? filename.substring(0, dotIndex) : filename;
            final extPart = dotIndex != -1 ? filename.substring(dotIndex) : '';
            targetPath = '${downloadDir.path}/${namePart}_${DateTime.now().millisecondsSinceEpoch}$extPart';
          }
          final fileToWrite = File(targetPath);
          await fileToWrite.writeAsBytes(bytes);
          return targetPath;
        }
      } catch (e) {
        debugPrint('Failed to save to Android public Download folder: $e');
      }
    }

    // Fallback to app documents directory
    final docDir = await getApplicationDocumentsDirectory();
    targetPath = '${docDir.path}/$filename';
    final file = File(targetPath);
    if (await file.exists()) {
      final dotIndex = filename.lastIndexOf('.');
      final namePart = dotIndex != -1 ? filename.substring(0, dotIndex) : filename;
      final extPart = dotIndex != -1 ? filename.substring(dotIndex) : '';
      targetPath = '${docDir.path}/${namePart}_${DateTime.now().millisecondsSinceEpoch}$extPart';
    }
    final fileToWrite = File(targetPath);
    await fileToWrite.writeAsBytes(bytes);
    return targetPath;
  }

  void _showExportDialog(BuildContext context, KelasModel kelas, List<ArtworkModel> artworks) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: _kelasRepo.watchLeaderboardKelas(kelas.kelasId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppColors.primary));
            }

            final allMembers = snapshot.data ?? [];
            
            // Dapatkan murid aktif
            final activeMembers = allMembers.where((m) => kelas.muridIds.contains(m['uid'] ?? '')).toList();
            
            // Dapatkan murid alumni/keluar yang tautan karyanya belum diputus
            final exitedMembers = <Map<String, dynamic>>[];
            for (final ex in kelas.exitedMurids) {
              final uid = ex['uid'] ?? '';
              final hasArt = artworks.any((a) => a.uid == uid);
              if (hasArt) {
                final profile = allMembers.firstWhereOrNull((m) => m['uid'] == uid);
                final tglEx = ex['tanggalKeluar'] != null 
                    ? ex['tanggalKeluar'].toString().split('T')[0] 
                    : '';
                exitedMembers.add({
                  'uid': uid,
                  'namaLengkap': ex['namaLengkap']?.toString().isNotEmpty == true
                      ? ex['namaLengkap']
                      : (profile?['namaLengkap'] ?? 'Alumni'),
                  'namaPanggilan': ex['namaPanggilan']?.toString().isNotEmpty == true
                      ? ex['namaPanggilan']
                      : (profile?['namaPanggilan'] ?? ''),
                  'username': profile?['username'] ?? '',
                  'poin': profile?['poin'] ?? 0,
                  'statusLabel': tglEx.isNotEmpty ? 'Keluar ($tglEx)' : 'Keluar',
                });
              }
            }

            // Gabungkan menjadi satu list
            final combinedList = <Map<String, dynamic>>[];
            for (final m in activeMembers) {
              combinedList.add({
                ...m,
                'statusLabel': 'Aktif',
              });
            }
            for (final m in exitedMembers) {
              combinedList.add({
                ...m,
              });
            }

            if (combinedList.isEmpty) {
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                title: const Text('Ekspor Laporan', style: TextStyle(fontFamily: 'FredokaOne')),
                content: const Text('Belum ada murid di kelas ini untuk diekspor.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Tutup'),
                  ),
                ],
              );
            }

            // Generate CSV
            final buffer = StringBuffer();
            buffer.writeln('"No","Nama Lengkap","Nama Panggilan","Username","Total Poin","Total Karya","Level Maks (Keris)","Level Maks (Batik)","Level Maks (Anyaman)","Rata-rata Skor AI","Grade Terfavorit","Status"');
            
            // Build student data list for table display
            final tableRows = <Map<String, dynamic>>[];

            for (int i = 0; i < combinedList.length; i++) {
              final member = combinedList[i];
              final uid = member['uid'] ?? '';
              final String namaLengkap = member['namaLengkap']?.toString().isNotEmpty == true
                  ? member['namaLengkap']
                  : (member['namaPanggilan']?.toString() ?? '');
              final String namaPanggilan = member['namaPanggilan']?.toString() ?? '';
              final username = member['username'] ?? '';
              final poin = member['poin'] ?? 0;
              final status = member['statusLabel'] ?? 'Aktif';
              
              final studentArt = artworks.where((a) => a.uid == uid).toList();
              final totalKarya = studentArt.length;
              
              final kerisArts = studentArt.where((a) => a.kategori.toLowerCase() == 'keris').toList();
              final maxKeris = kerisArts.isEmpty ? '-' : kerisArts.map((a) => a.level).reduce((a, b) => a > b ? a : b).toString();
              
              final batikArts = studentArt.where((a) => a.kategori.toLowerCase() == 'batik').toList();
              final maxBatik = batikArts.isEmpty ? '-' : batikArts.map((a) => a.level).reduce((a, b) => a > b ? a : b).toString();
              
              final anyamanArts = studentArt.where((a) => a.kategori.toLowerCase() == 'anyaman').toList();
              final maxAnyaman = anyamanArts.isEmpty ? '-' : anyamanArts.map((a) => a.level).reduce((a, b) => a > b ? a : b).toString();
              
              final avgAI = studentArt.isEmpty 
                  ? 0.0 
                  : studentArt.fold<int>(0, (acc, a) => acc + (a.skorAI ?? 0)) / studentArt.length;
              
              String favoriteGrade = '-';
              if (studentArt.isNotEmpty) {
                final gradeCounts = <String, int>{};
                for (final a in studentArt) {
                  gradeCounts[a.actualGrade] = (gradeCounts[a.actualGrade] ?? 0) + 1;
                }
                favoriteGrade = gradeCounts.entries
                    .reduce((a, b) => a.value >= b.value ? a : b)
                    .key;
              }
              
              buffer.writeln('"${i + 1}","${namaLengkap.replaceAll('"', '""')}","${namaPanggilan.replaceAll('"', '""')}","${username.replaceAll('"', '""')}","$poin","$totalKarya","$maxKeris","$maxBatik","$maxAnyaman","${avgAI.toStringAsFixed(1)}","$favoriteGrade","$status"');

              tableRows.add({
                'no': i + 1,
                'namaLengkap': namaLengkap,
                'namaPanggilan': namaPanggilan,
                'username': username,
                'poin': poin,
                'totalKarya': totalKarya,
                'maxKeris': maxKeris,
                'maxBatik': maxBatik,
                'maxAnyaman': maxAnyaman,
                'avgAI': avgAI.toStringAsFixed(1),
                'gradeFav': favoriteGrade,
                'statusLabel': status,
              });
            }

            final csvString = buffer.toString();

            Future<void> exportToExcel(List<Map<String, dynamic>> rows) async {
              try {
                // Show loading spinner
                Get.dialog(
                  const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  barrierDismissible: false,
                );

                var excel = ex.Excel.createExcel();
                var sheet = excel['Laporan Kelas'];
                excel.delete('Sheet1'); // Remove default empty sheet

                // Append title headers
                sheet.appendRow([ex.TextCellValue('LAPORAN DATA NILAI KELAS - EPIC APP')]);
                sheet.appendRow([ex.TextCellValue('Kelas: ${kelas.namaKelas}')]);
                sheet.appendRow([ex.TextCellValue('Guru Kelas: ${kelas.guruNama}')]);
                sheet.appendRow([ex.TextCellValue('Sekolah: ${kelas.namaSekolah}')]);
                sheet.appendRow([ex.TextCellValue('Tahun Ajaran: ${kelas.tahunAjaran}')]);
                sheet.appendRow([ex.TextCellValue('Tanggal Cetak: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}')]);
                sheet.appendRow([]); // empty row

                // Table headers
                sheet.appendRow([
                  ex.TextCellValue('No'), 
                  ex.TextCellValue('Nama Lengkap'), 
                  ex.TextCellValue('Nama Panggilan'), 
                  ex.TextCellValue('Username'), 
                  ex.TextCellValue('Total Poin'), 
                  ex.TextCellValue('Total Karya'), 
                  ex.TextCellValue('Level Maks (Keris)'), 
                  ex.TextCellValue('Level Maks (Batik)'), 
                  ex.TextCellValue('Level Maks (Anyaman)'), 
                  ex.TextCellValue('Rata-rata Skor AI'), 
                  ex.TextCellValue('Grade Terfavorit'),
                  ex.TextCellValue('Status')
                ]);

                // Append student data
                for (final r in rows) {
                  final int? maxKerisNum = int.tryParse(r['maxKeris'].toString());
                  final int? maxBatikNum = int.tryParse(r['maxBatik'].toString());
                  final int? maxAnyamanNum = int.tryParse(r['maxAnyaman'].toString());

                  sheet.appendRow([
                    ex.IntCellValue(r['no'] as int),
                    ex.TextCellValue(r['namaLengkap'] as String),
                    ex.TextCellValue(r['namaPanggilan'] as String),
                    ex.TextCellValue(r['username'].toString().isNotEmpty ? '@${r['username']}' : ''),
                    ex.IntCellValue(r['poin'] as int),
                    ex.IntCellValue(r['totalKarya'] as int),
                    maxKerisNum != null ? ex.IntCellValue(maxKerisNum) : ex.TextCellValue(r['maxKeris'].toString()),
                    maxBatikNum != null ? ex.IntCellValue(maxBatikNum) : ex.TextCellValue(r['maxBatik'].toString()),
                    maxAnyamanNum != null ? ex.IntCellValue(maxAnyamanNum) : ex.TextCellValue(r['maxAnyaman'].toString()),
                    ex.DoubleCellValue(double.tryParse(r['avgAI'].toString()) ?? 0.0),
                    ex.TextCellValue(r['gradeFav'] as String),
                    ex.TextCellValue(r['statusLabel'] as String)
                  ]);
                }

                // Save Excel file to storage using our robust helper
                final fileBytes = excel.save();
                final cleanName = kelas.namaKelas.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
                final savedPath = await _saveReportFile('Laporan_Kelas_$cleanName.xlsx', fileBytes!);

                Get.back(); // Dismiss loading spinner
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop(); // Dismiss export dialog

                EpicSnackbar.success(
                  'Unduh Excel Berhasil 📊',
                  savedPath.contains('/Download')
                      ? 'File disimpan di folder Download Anda:\n$savedPath'
                      : 'File disimpan di dokumen perangkat Anda:\n$savedPath',
                );

                await OpenFile.open(savedPath);
              } catch (e) {
                Get.back(); // Dismiss loading spinner
                EpicSnackbar.error('Gagal Mengunduh', 'Gagal memproses Excel: $e');
              }
            }

            Future<void> exportToPdf(List<Map<String, dynamic>> rows) async {
              try {
                // Show loading spinner
                Get.dialog(
                  const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  barrierDismissible: false,
                );

                final pdf = pw.Document();

                pdf.addPage(
                  pw.Page(
                    pageFormat: PdfPageFormat.a4.landscape, // Landscape orientation fits wide tables perfectly!
                    margin: const pw.EdgeInsets.all(24),
                    build: (pw.Context context) {
                      return pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          // Header Section
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    'LAPORAN NILAI KELAS LENGKAP',
                                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.orange800),
                                  ),
                                  pw.SizedBox(height: 2),
                                  pw.Text('EPIC - Ecocultural Pattern Innovation Creator', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                                ],
                              ),
                              pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.end,
                                children: [
                                  pw.Text('Tanggal Unduh: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}', style: const pw.TextStyle(fontSize: 8)),
                                  pw.Text('Waktu Cetak: ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}', style: const pw.TextStyle(fontSize: 8)),
                                ],
                              ),
                            ],
                          ),
                          pw.SizedBox(height: 8),
                          pw.Divider(thickness: 1.5, color: PdfColors.orange),
                          pw.SizedBox(height: 8),

                          // Class details metadata
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text('Nama Kelas: ${kelas.namaKelas}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                                  pw.Text('Guru Kelas: ${kelas.guruNama}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.orange900)),
                                  pw.Text('Mata Pelajaran: ${kelas.mataPelajaran.isNotEmpty ? kelas.mataPelajaran : 'Seni Rupa & Budaya'}', style: const pw.TextStyle(fontSize: 9)),
                                ],
                              ),
                              pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.end,
                                children: [
                                  pw.Text('Sekolah: ${kelas.namaSekolah}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                                  pw.Text('Tahun Ajaran: ${kelas.tahunAjaran}', style: const pw.TextStyle(fontSize: 9)),
                                ],
                              ),
                            ],
                          ),
                          pw.SizedBox(height: 12),

                          // The Data Table
                          pw.TableHelper.fromTextArray(
                            headers: ['No', 'Nama Lengkap', 'Nama Panggilan', 'Username', 'Total Poin', 'Karya', 'Lvl Keris', 'Lvl Batik', 'Lvl Anyaman', 'Avg AI', 'Grade Fav', 'Status'],
                            data: rows.map((r) => [
                              r['no'].toString(),
                              r['namaLengkap'].toString(),
                              r['namaPanggilan'].toString(),
                              r['username'].toString().isNotEmpty ? '@${r['username']}' : '',
                              r['poin'].toString(),
                              r['totalKarya'].toString(),
                              r['maxKeris'].toString(),
                              r['maxBatik'].toString(),
                              r['maxAnyaman'].toString(),
                              r['avgAI'].toString(),
                              r['gradeFav'].toString(),
                              r['statusLabel'].toString(),
                            ]).toList(),
                            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8),
                            headerDecoration: const pw.BoxDecoration(color: PdfColors.orange900),
                            cellAlignment: pw.Alignment.center,
                            cellStyle: const pw.TextStyle(fontSize: 8),
                            headerAlignments: {
                              1: pw.Alignment.centerLeft, // Align student full name to the left
                              2: pw.Alignment.centerLeft, // Align nickname to the left
                            },
                            columnWidths: const {
                              0: pw.FixedColumnWidth(20),  // No
                              1: pw.FlexColumnWidth(2.0), // Nama Lengkap
                              2: pw.FlexColumnWidth(1.5), // Nama Panggilan
                              3: pw.FlexColumnWidth(1.2), // Username
                              4: pw.FixedColumnWidth(30),  // Poin
                              5: pw.FixedColumnWidth(30),  // Total Karya
                              6: pw.FixedColumnWidth(40),  // Lvl Keris
                              7: pw.FixedColumnWidth(40),  // Lvl Batik
                              8: pw.FixedColumnWidth(40),  // Lvl Anyaman
                              9: pw.FixedColumnWidth(30),  // Avg AI
                              10: pw.FixedColumnWidth(30), // Grade Fav
                              11: pw.FlexColumnWidth(1.8), // Status
                            },
                          ),

                          pw.Spacer(),
                          pw.Divider(thickness: 0.5, color: PdfColors.grey400),
                          pw.SizedBox(height: 2),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('Laporan Resmi diunduh via EPIC App - Akun Guru Terverifikasi', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
                              pw.Text('Halaman 1 dari 1', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                );

                // Save PDF to storage using our robust helper
                final cleanName = kelas.namaKelas.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
                final savedPath = await _saveReportFile('Laporan_Kelas_$cleanName.pdf', await pdf.save());

                Get.back(); // Dismiss loading spinner
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop(); // Dismiss export dialog

                EpicSnackbar.success(
                  'Unduh PDF Berhasil 📄',
                  savedPath.contains('/Download')
                      ? 'File disimpan di folder Download Anda:\n$savedPath'
                      : 'File disimpan di dokumen perangkat Anda:\n$savedPath',
                );

                await OpenFile.open(savedPath);
              } catch (e) {
                Get.back(); // Dismiss loading spinner
                EpicSnackbar.error('Gagal Mengunduh', 'Gagal memproses PDF: $e');
              }
            }

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
              backgroundColor: const Color(0xFFFFF9F0),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.assessment_outlined, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Laporan Nilai Kelas',
                              style: AppFonts.heading3(color: AppColors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Berikut adalah preview data laporan nilai kelas "${kelas.namaKelas}". Anda dapat mengunduh file Excel/PDF atau menyalin data CSV di bawah.',
                        style: AppFonts.bodySmall(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      // Interactive Preview Table Scrollable
                      Container(
                        height: 250,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            physics: const BouncingScrollPhysics(),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                                columns: const [
                                  DataColumn(label: Text('No', style: TextStyle(fontFamily: 'FredokaOne', fontSize: 12))),
                                  DataColumn(label: Text('Nama Lengkap', style: TextStyle(fontFamily: 'FredokaOne', fontSize: 12))),
                                  DataColumn(label: Text('Nama Panggilan', style: TextStyle(fontFamily: 'FredokaOne', fontSize: 12))),
                                  DataColumn(label: Text('Username', style: TextStyle(fontFamily: 'FredokaOne', fontSize: 12))),
                                  DataColumn(label: Text('Poin', style: TextStyle(fontFamily: 'FredokaOne', fontSize: 12))),
                                  DataColumn(label: Text('Total Karya', style: TextStyle(fontFamily: 'FredokaOne', fontSize: 12))),
                                  DataColumn(label: Text('Keris (Max)', style: TextStyle(fontFamily: 'FredokaOne', fontSize: 12))),
                                  DataColumn(label: Text('Batik (Max)', style: TextStyle(fontFamily: 'FredokaOne', fontSize: 12))),
                                  DataColumn(label: Text('Anyaman (Max)', style: TextStyle(fontFamily: 'FredokaOne', fontSize: 12))),
                                  DataColumn(label: Text('Avg AI', style: TextStyle(fontFamily: 'FredokaOne', fontSize: 12))),
                                  DataColumn(label: Text('Grade Fav', style: TextStyle(fontFamily: 'FredokaOne', fontSize: 12))),
                                  DataColumn(label: Text('Status', style: TextStyle(fontFamily: 'FredokaOne', fontSize: 12))),
                                ],
                                rows: tableRows.map((row) {
                                  return DataRow(
                                    cells: [
                                      DataCell(Text('${row['no']}', style: const TextStyle(fontFamily: 'Nunito', fontSize: 12))),
                                      DataCell(Text('${row['namaLengkap']}', style: const TextStyle(fontFamily: 'Nunito', fontSize: 12, fontWeight: FontWeight.bold))),
                                      DataCell(Text('${row['namaPanggilan']}', style: const TextStyle(fontFamily: 'Nunito', fontSize: 12))),
                                      DataCell(Text(row['username'].toString().isNotEmpty ? '@${row['username']}' : '', style: const TextStyle(fontFamily: 'Nunito', fontSize: 12, color: Colors.grey))),
                                      DataCell(Text('${row['poin']}', style: const TextStyle(fontFamily: 'Nunito', fontSize: 12))),
                                      DataCell(Text('${row['totalKarya']}', style: const TextStyle(fontFamily: 'Nunito', fontSize: 12))),
                                      DataCell(Text('${row['maxKeris']}', style: const TextStyle(fontFamily: 'Nunito', fontSize: 12))),
                                      DataCell(Text('${row['maxBatik']}', style: const TextStyle(fontFamily: 'Nunito', fontSize: 12))),
                                      DataCell(Text('${row['maxAnyaman']}', style: const TextStyle(fontFamily: 'Nunito', fontSize: 12))),
                                      DataCell(Text('${row['avgAI']}', style: const TextStyle(fontFamily: 'Nunito', fontSize: 12))),
                                      DataCell(Text('${row['gradeFav']}', style: const TextStyle(fontFamily: 'Nunito', fontSize: 12, fontWeight: FontWeight.bold))),
                                      DataCell(Text('${row['statusLabel']}', style: const TextStyle(fontFamily: 'Nunito', fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600))),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            child: const Text('Batal', style: TextStyle(fontFamily: 'FredokaOne', fontSize: 11)),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: csvString));
                              EpicSnackbar.success(
                                'Salin Laporan 📋',
                                'Laporan lengkap kelas disalin ke clipboard! Siap ditempel di Excel.',
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            icon: const Icon(Icons.copy_rounded, size: 14),
                            label: const Text('Salin CSV', style: TextStyle(fontFamily: 'FredokaOne', fontSize: 11)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => exportToExcel(tableRows),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981), // Emerald Green
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              icon: const Icon(Icons.grid_on_rounded, size: 16),
                              label: const Text('Unduh Excel', style: TextStyle(fontFamily: 'FredokaOne', fontSize: 12)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => exportToPdf(tableRows),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEF4444), // PDF Red
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                              label: const Text('Unduh PDF', style: TextStyle(fontFamily: 'FredokaOne', fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
