import 'package:epic_admin/core/theme/admin_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:epic_admin/core/utils/file_download_helper.dart';
import 'package:epic_admin/core/utils/kelas_pdf_generator.dart';

class KelasDetailScreen extends StatelessWidget {
  final String id;
  const KelasDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWide = screenWidth >= 1100;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('kelas').doc(id).snapshots(),
      builder: (context, classSnapshot) {
        if (classSnapshot.hasError) {
          return Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            body: Center(child: Text('Terjadi kesalahan memuat kelas: ${classSnapshot.error}')),
          );
        }

        if (classSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AdminColors.primary),
              ),
            ),
          );
        }

        if (!classSnapshot.hasData || !classSnapshot.data!.exists) {
          return Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Kelas tidak ditemukan.', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.pop(),
                    child: const Text('Kembali'),
                  ),
                ],
              ),
            ),
          );
        }

        final classData = classSnapshot.data!.data() as Map<String, dynamic>;
        final String className = classData['namaKelas'] ?? 'Kelas Tanpa Nama';
        final String classCode = classData['kodeKelas'] ?? '-';
        final String teacherName = classData['guruNama'] ?? 'Tanpa Guru';
        final String guruId = classData['guruUid'] ?? classData['guruId'] ?? '';
        final List<dynamic> muridIds = classData['muridIds'] is List ? classData['muridIds'] : [];
        final String status = classData['status'] ?? 'aktif';
        final bool isClassActive = status == 'aktif';

        final dynamic createdVal = classData['createdAt'];
        String createdDate = '-';
        if (createdVal is Timestamp) {
          final dt = createdVal.toDate();
          createdDate = '${dt.day}/${dt.month}/${dt.year}';
        }

        return StreamBuilder<DocumentSnapshot>(
          stream: guruId.isNotEmpty 
              ? FirebaseFirestore.instance.collection('users').doc(guruId).snapshots()
              : const Stream.empty(),
          builder: (context, guruProfileSnapshot) {
            String school = 'Sekolah tidak ditentukan';
            if (guruProfileSnapshot.hasData && guruProfileSnapshot.data!.exists) {
              final gData = guruProfileSnapshot.data!.data() as Map<String, dynamic>;
              school = gData['sekolah'] ?? 'Sekolah tidak ditentukan';
            }

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'murid').snapshots(),
              builder: (context, allStudentsSnapshot) {
                final allStudents = (allStudentsSnapshot.data?.docs ?? []).cast<QueryDocumentSnapshot<Map<String, dynamic>>>();
                
                // Filter students who are in this class (either in muridIds or having kelas == className)
                final classStudents = allStudents.where((doc) {
                  return muridIds.contains(doc.id);
                }).toList();

                final int studentCount = classStudents.length;

                // Calculate average points/scores and build leaderboard
                double totalPoints = 0;
                for (var sDoc in classStudents) {
                  final sData = sDoc.data() as Map<String, dynamic>;
                  final int pts = sData['poin'] is int ? sData['poin'] : 0;
                  totalPoints += pts;
                }

                // Map to leaderboard items
                final List<Map<String, dynamic>> leaderboardItems = classStudents.map((doc) {
                  final sData = doc.data() as Map<String, dynamic>;
                  return {
                    'uid': doc.id,
                    'name': sData['namaLengkap'] ?? sData['nama'] ?? 'Tanpa Nama',
                    'points': sData['poin'] is int ? sData['poin'] : 0,
                  };
                }).toList();

                // Sort descending by points
                leaderboardItems.sort((a, b) => (b['points'] as int).compareTo(a['points'] as int));

                // Add ranks
                final List<Map<String, dynamic>> leaderboardWithRanks = [];
                for (int i = 0; i < leaderboardItems.length; i++) {
                  final item = leaderboardItems[i];
                  String emoji = (i + 1).toString();
                  if (i == 0) emoji = '🥇';
                  if (i == 1) emoji = '🥈';
                  if (i == 2) emoji = '🥉';
                  
                  leaderboardWithRanks.add({
                    'rank': i + 1,
                    'name': item['name'],
                    'points': item['points'],
                    'emoji': emoji,
                  });
                }

                // Get artworks matching student IDs
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('artworks').snapshots(),
                  builder: (context, artworksSnapshot) {
                    final allArtworks = (artworksSnapshot.data?.docs ?? []).cast<QueryDocumentSnapshot<Map<String, dynamic>>>();
                    final classArtworksDocs = allArtworks.where((doc) {
                      final aData = doc.data();
                      final String studentUid = aData['uid'] ?? '';
                      return muridIds.contains(studentUid);
                    }).toList();

                    // Calculate average score of artworks
                    double totalArtworkScore = 0;
                    int artworkCount = classArtworksDocs.length;
                    for (var aDoc in classArtworksDocs) {
                      final aData = aDoc.data() as Map<String, dynamic>;
                      final int score = aData['skorAI'] is int ? aData['skorAI'] : 0;
                      totalArtworkScore += score;
                    }

                    final double avgScore = artworkCount > 0 
                        ? (totalArtworkScore / artworkCount)
                        : 0.0;

                    // Sort artworks by createdAt descending
                    classArtworksDocs.sort((a, b) {
                      final aData = a.data() as Map<String, dynamic>;
                      final bData = b.data() as Map<String, dynamic>;
                      final Timestamp aTime = aData['createdAt'] ?? Timestamp.now();
                      final Timestamp bTime = bData['createdAt'] ?? Timestamp.now();
                      return bTime.compareTo(aTime);
                    });

                    // Map to recent artworks items
                    final List<Map<String, dynamic>> recentArtworks = classArtworksDocs.take(5).map((doc) {
                      final aData = doc.data() as Map<String, dynamic>;
                      final String studentUid = aData['uid'] ?? '';
                      
                      // Find student name
                      String sName = 'Siswa';
                      final sDoc = classStudents.firstWhere((s) => s.id == studentUid, orElse: () => allStudents.first);
                      final sData = sDoc.data() as Map<String, dynamic>?;
                      if (sData != null) {
                        sName = sData['namaLengkap'] ?? sData['nama'] ?? 'Siswa';
                      }

                      final String grade = aData['grade'] ?? 'C';
                      Color gradeColor = const Color(0xFFEF4444);
                      if (grade == 'S') gradeColor = const Color(0xFFD946EF);
                      if (grade == 'A') gradeColor = const Color(0xFF10B981);
                      if (grade == 'B') gradeColor = const Color(0xFF3B82F6);

                      return {
                        'title': (aData['kategori'] ?? 'Karya').toString().toUpperCase(),
                        'student': sName,
                        'grade': grade,
                        'color': gradeColor,
                      };
                    }).toList();

                    // Map to students list
                    final List<Map<String, dynamic>> studentRows = classStudents.map((doc) {
                      final sData = doc.data() as Map<String, dynamic>;
                      final String studentUid = doc.id;

                      // Count artworks for this student
                      final studentArtworks = classArtworksDocs.where((a) {
                        final aData = a.data() as Map<String, dynamic>;
                        return aData['uid'] == studentUid;
                      }).toList();

                      // Compute top grade
                      Map<String, int> grades = {};
                      for (var art in studentArtworks) {
                        final aData = art.data() as Map<String, dynamic>;
                        final String gr = aData['grade'] ?? 'C';
                        grades[gr] = (grades[gr] ?? 0) + 1;
                      }
                      String topGrade = '-';
                      if (grades.isNotEmpty) {
                        topGrade = 'Grade ' + grades.entries.reduce((a, b) => a.value > b.value ? a : b).key;
                      }

                      final dynamic lastAct = sData['lastActiveAt'] ?? sData['nyawaLastReset'];
                      String lastActStr = 'Baru saja';
                      if (lastAct is Timestamp) {
                        final dt = lastAct.toDate();
                        lastActStr = '${dt.day}/${dt.month}/${dt.year}';
                      }

                      return {
                        'uid': studentUid,
                        'name': sData['namaLengkap'] ?? sData['nama'] ?? 'Tanpa Nama',
                        'namaPanggilan': sData['namaPanggilan'] ?? '-',
                        'username': sData['username'] ?? '-',
                        'points': sData['poin'] is int ? sData['poin'] : 0,
                        'artworks': studentArtworks.length,
                        'grade': topGrade,
                        'active': lastActStr,
                      };
                    }).toList();

                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Background Glows
                        Positioned(
                          top: -120,
                          right: -80,
                          child: Container(
                            width: 380,
                            height: 380,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  const Color(0xFF2563EB).withOpacity(0.04),
                                  const Color(0xFF2563EB).withOpacity(0),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: -150,
                          left: -120,
                          child: Container(
                            width: 480,
                            height: 480,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  const Color(0xFF8B5CF6).withOpacity(0.04),
                                  const Color(0xFF8B5CF6).withOpacity(0),
                                ],
                              ),
                            ),
                          ),
                        ),

                        Positioned.fill(
                          child: SizedBox.expand(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header Breadcrumbs
                                Row(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.03),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: IconButton(
                                        icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 20),
                                        onPressed: () => context.pop(),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text('Dashboard', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: const Color(0xFF64748B))),
                                            const Icon(Icons.chevron_right, size: 14, color: Color(0xFF64748B)),
                                            Text('Manajemen Kelas', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: const Color(0xFF64748B))),
                                            const Icon(Icons.chevron_right, size: 14, color: Color(0xFF64748B)),
                                            Text('Detail Kelas', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AdminColors.primary, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Detail Informasi Kelas',
                                          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                                fontWeight: FontWeight.w800,
                                                color: const Color(0xFF0F172A),
                                                letterSpacing: -0.5,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.04, end: 0, curve: Curves.easeOutQuad),
                                const SizedBox(height: 28),

                                // Scrollable Content
                                Expanded(
                                  child: SingleChildScrollView(
                                    physics: const BouncingScrollPhysics(),
                                    padding: const EdgeInsets.only(bottom: 32),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Header Card
                                        Container(
                                          padding: const EdgeInsets.all(28),
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius: BorderRadius.circular(24),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF2563EB).withOpacity(0.15),
                                                blurRadius: 20,
                                                offset: const Offset(0, 8),
                                              ),
                                            ],
                                          ),
                                          child: Stack(
                                            clipBehavior: Clip.none,
                                            children: [
                                              Positioned(
                                                right: -40,
                                                top: -40,
                                                child: Opacity(
                                                  opacity: 0.1,
                                                  child: Container(
                                                    width: 180,
                                                    height: 180,
                                                    decoration: const BoxDecoration(
                                                      color: Colors.white,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Positioned(
                                                left: 200,
                                                bottom: -60,
                                                child: Opacity(
                                                  opacity: 0.08,
                                                  child: Container(
                                                    width: 140,
                                                    height: 140,
                                                    decoration: const BoxDecoration(
                                                      color: Colors.white,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Container(
                                                            padding: const EdgeInsets.all(12),
                                                            decoration: BoxDecoration(
                                                              color: Colors.white.withOpacity(0.15),
                                                              borderRadius: BorderRadius.circular(16),
                                                            ),
                                                            child: const Icon(Icons.school_rounded, color: Colors.white, size: 28),
                                                          ),
                                                          const SizedBox(width: 16),
                                                          Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              Text(
                                                                className,
                                                                style: const TextStyle(
                                                                  color: Colors.white,
                                                                  fontWeight: FontWeight.w800,
                                                                  fontSize: 26,
                                                                  letterSpacing: -0.5,
                                                                ),
                                                              ),
                                                              const SizedBox(height: 2),
                                                              Text(
                                                                school,
                                                                style: TextStyle(
                                                                  color: Colors.white.withOpacity(0.8),
                                                                  fontWeight: FontWeight.w500,
                                                                  fontSize: 13,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                        decoration: BoxDecoration(
                                                          color: Colors.white.withOpacity(0.15),
                                                          borderRadius: BorderRadius.circular(14),
                                                          border: Border.all(color: Colors.white.withOpacity(0.25)),
                                                        ),
                                                        child: Row(
                                                          children: [
                                                            Text(
                                                              'KODE: $classCode',
                                                              style: const TextStyle(
                                                                color: Colors.white,
                                                                fontWeight: FontWeight.bold,
                                                                letterSpacing: 1.0,
                                                                fontFamily: 'monospace',
                                                                fontSize: 13,
                                                              ),
                                                            ),
                                                            const SizedBox(width: 8),
                                                            MouseRegion(
                                                              cursor: SystemMouseCursors.click,
                                                              child: GestureDetector(
                                                                onTap: () {
                                                                  Clipboard.setData(ClipboardData(text: classCode));
                                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                                    SnackBar(
                                                                      content: Row(
                                                                        children: [
                                                                          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                                                          const SizedBox(width: 10),
                                                                          Expanded(
                                                                            child: Text(
                                                                              'Kode kelas $classCode berhasil disalin!',
                                                                              style: const TextStyle(fontWeight: FontWeight.w500),
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                      backgroundColor: const Color(0xFF059669),
                                                                      behavior: SnackBarBehavior.floating,
                                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                                      width: 360,
                                                                    ),
                                                                  );
                                                                },
                                                                child: const Icon(
                                                                  Icons.copy_rounded,
                                                                  color: Colors.white,
                                                                  size: 16,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 24),
                                                  const Divider(color: Colors.white24, height: 1),
                                                  const SizedBox(height: 20),
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      _buildHeaderBadge(Icons.person_rounded, 'Wali Kelas: $teacherName'),
                                                      _buildHeaderBadge(Icons.calendar_today_rounded, 'Dibuat: $createdDate'),
                                                      _buildHeaderBadge(Icons.groups_rounded, '$studentCount Murid Aktif'),
                                                      _buildHeaderBadge(Icons.analytics_rounded, 'Rata-rata Kelas: ${avgScore.toStringAsFixed(1)}'),
                                                      Row(
                                                        children: [
                                                          InkWell(
                                                            onTap: () => _toggleArchiveClass(context, id, isClassActive, className),
                                                            borderRadius: BorderRadius.circular(10),
                                                            child: Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                              decoration: BoxDecoration(
                                                                color: isClassActive ? const Color(0xFFD1FAE5) : const Color(0xFFF1F5F9),
                                                                borderRadius: BorderRadius.circular(10),
                                                                border: Border.all(color: (isClassActive ? const Color(0xFF10B981) : const Color(0xFF64748B)).withOpacity(0.3)),
                                                              ),
                                                              child: Row(
                                                                children: [
                                                                  Icon(isClassActive ? Icons.check_circle_rounded : Icons.archive_rounded, size: 12, color: isClassActive ? const Color(0xFF065F46) : const Color(0xFF475569)),
                                                                  const SizedBox(width: 4),
                                                                  Text(
                                                                    isClassActive ? 'Status: Aktif (Arsipkan)' : 'Status: Arsip (Aktifkan)',
                                                                    style: TextStyle(color: isClassActive ? const Color(0xFF065F46) : const Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 11),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(width: 12),
                                                          InkWell(
                                                            onTap: () => _showReportPreviewDialog(
                                                              context,
                                                              className,
                                                              classCode,
                                                              teacherName,
                                                              school,
                                                              createdDate,
                                                              studentRows,
                                                              classArtworksDocs,
                                                            ),
                                                            borderRadius: BorderRadius.circular(10),
                                                            child: Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                              decoration: BoxDecoration(
                                                                color: Colors.white.withOpacity(0.12),
                                                                borderRadius: BorderRadius.circular(10),
                                                                border: Border.all(color: Colors.white.withOpacity(0.25)),
                                                              ),
                                                              child: Row(
                                                                children: const [
                                                                  Icon(Icons.download_rounded, size: 12, color: Colors.white),
                                                                  SizedBox(width: 6),
                                                                  Text(
                                                                    'Unduh Laporan',
                                                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.04, end: 0, curve: Curves.easeOutQuad),
                                        const SizedBox(height: 32),

                                        // Leaderboard & Recent Artworks
                                        if (isWide)
                                          IntrinsicHeight(
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.stretch,
                                              children: [
                                                Expanded(child: _buildLeaderboardCard(context, leaderboardWithRanks)),
                                                const SizedBox(width: 32),
                                                Expanded(child: _buildArtworksCard(context, recentArtworks)),
                                              ],
                                            ),
                                          )
                                        else
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.stretch,
                                            children: [
                                              _buildLeaderboardCard(context, leaderboardWithRanks),
                                              const SizedBox(height: 24),
                                              _buildArtworksCard(context, recentArtworks),
                                            ],
                                          ),
                                        const SizedBox(height: 32),

                                        // Students List Card
                                        _buildStudentsCard(context, id, studentRows, studentCount.toString()),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  void _toggleArchiveClass(BuildContext context, String classId, bool isCurrentlyActive, String name) {
    final action = isCurrentlyActive ? 'mengarsipkan' : 'mengaktifkan kembali';
    final statusVal = isCurrentlyActive ? 'nonaktif' : 'aktif';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(isCurrentlyActive ? 'Arsipkan Kelas' : 'Aktifkan Kelas'),
          content: Text('Apakah Anda yakin ingin $action kelas "$name"?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Batal'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isCurrentlyActive ? Colors.orange : AdminColors.primary,
              ),
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await FirebaseFirestore.instance.collection('kelas').doc(classId).update({
                    'status': statusVal,
                  });

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Kelas "$name" berhasil ${isCurrentlyActive ? "diarsipkan" : "diaktifkan kembali"}.'),
                        backgroundColor: AdminColors.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Gagal mengubah status kelas: $e'), backgroundColor: AdminColors.danger),
                    );
                  }
                }
              },
              child: Text(isCurrentlyActive ? 'Arsipkan' : 'Aktifkan', style: const TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _downloadClassReport(
    BuildContext context,
    String className,
    String classCode,
    String teacherName,
    String school,
    String createdDate,
    List<Map<String, dynamic>> studentRows,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> classArtworksDocs,
  ) {
    if (studentRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Belum ada murid di kelas ini untuk diekspor.'),
          backgroundColor: AdminColors.danger,
        ),
      );
      return;
    }

    try {
      final buffer = StringBuffer();
      // Add CSV Headers / Metadata
      buffer.writeln('"LAPORAN DATA NILAI KELAS - EPIC APP"');
      buffer.writeln('"Kelas:","${className.replaceAll('"', '""')}"');
      buffer.writeln('"Kode Kelas:","$classCode"');
      buffer.writeln('"Guru/Wali Kelas:","${teacherName.replaceAll('"', '""')}"');
      buffer.writeln('"Sekolah:","${school.replaceAll('"', '""')}"');
      buffer.writeln('"Tanggal Dibuat:","$createdDate"');
      buffer.writeln('"Tanggal Cetak:","${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}"');
      buffer.writeln('');

      // Add Table Headers
      buffer.writeln('"No","Nama Lengkap","Nama Panggil","Username","Total Poin","Total Karya","Level Maks (Keris)","Level Maks (Batik)","Level Maks (Anyaman)","Rata-rata Skor AI","Grade Terbanyak","Aktif Terakhir"');

      for (int i = 0; i < studentRows.length; i++) {
        final student = studentRows[i];
        final uid = student['uid'] ?? '';
        final name = student['name'] ?? '';
        final nickname = student['namaPanggilan'] ?? '-';
        final username = student['username'] ?? '-';
        final points = student['points'] ?? 0;
        final artworksCount = student['artworks'] ?? 0;
        final topGrade = student['grade'] ?? '-';
        final lastActive = student['active'] ?? '-';

        // Filter artworks by this student
        final studentArt = classArtworksDocs.where((doc) {
          final data = doc.data();
          return data['uid'] == uid;
        }).toList();

        final kerisArts = studentArt.where((a) => (a.data()['kategori'] ?? '').toString().toLowerCase() == 'keris').toList();
        final maxKeris = kerisArts.isEmpty ? '-' : kerisArts.map((a) => a.data()['level'] is int ? a.data()['level'] as int : 0).reduce((a, b) => a > b ? a : b).toString();

        final batikArts = studentArt.where((a) => (a.data()['kategori'] ?? '').toString().toLowerCase() == 'batik').toList();
        final maxBatik = batikArts.isEmpty ? '-' : batikArts.map((a) => a.data()['level'] is int ? a.data()['level'] as int : 0).reduce((a, b) => a > b ? a : b).toString();

        final anyamanArts = studentArt.where((a) => (a.data()['kategori'] ?? '').toString().toLowerCase() == 'anyaman').toList();
        final maxAnyaman = anyamanArts.isEmpty ? '-' : anyamanArts.map((a) => a.data()['level'] is int ? a.data()['level'] as int : 0).reduce((a, b) => a > b ? a : b).toString();

        final double avgAI = studentArt.isEmpty
            ? 0.0
            : studentArt.fold<int>(0, (acc, a) => acc + (a.data()['skorAI'] is int ? a.data()['skorAI'] as int : 0)) / studentArt.length;

        buffer.writeln('"${i + 1}","${name.replaceAll('"', '""')}","${nickname.replaceAll('"', '""')}","${username.replaceAll('"', '""')}","$points","$artworksCount","$maxKeris","$maxBatik","$maxAnyaman","${avgAI.toStringAsFixed(1)}","$topGrade","$lastActive"');
      }

      final csvString = buffer.toString();
      final cleanName = className.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final fileName = 'Laporan_Kelas_$cleanName.csv';

      FileDownloadHelper.downloadFile(csvString, fileName);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Laporan kelas "$className" berhasil diunduh!'),
          backgroundColor: AdminColors.success,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengunduh laporan: $e'),
          backgroundColor: AdminColors.danger,
        ),
      );
    }
  }

  void _showReportPreviewDialog(
    BuildContext context,
    String className,
    String classCode,
    String teacherName,
    String school,
    String createdDate,
    List<Map<String, dynamic>> studentRows,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> classArtworksDocs,
  ) {
    final int totalPoin = studentRows.fold<int>(0, (sum, s) => sum + (s['points'] as int));
    final int totalKarya = classArtworksDocs.length;
    final int totalMurid = studentRows.length;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          clipBehavior: Clip.antiAlias,
          backgroundColor: const Color(0xFFF8FAFC),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.75,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Gorgeous Gradient Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PRATINJAU LAPORAN DATA KELAS',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'EPIC (Ecocultural Pattern Innovation Creator) — Lisensi Pendidikan Resmi',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                        hoverColor: Colors.white.withValues(alpha: 0.1),
                      ),
                    ],
                  ),
                ),

                // Main Dialog Body
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Metadata Summary Panel
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.015),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildPreviewMetadataRow('Nama Kelas', className, isBold: true),
                                    const SizedBox(height: 8),
                                    _buildPreviewMetadataRow('Kode Kelas', classCode),
                                    const SizedBox(height: 8),
                                    _buildPreviewMetadataRow('Guru Pengajar', teacherName),
                                  ],
                                ),
                              ),
                              Container(width: 1.2, height: 80, color: const Color(0xFFE2E8F0), margin: const EdgeInsets.symmetric(horizontal: 24)),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildPreviewMetadataRow('Sekolah', school),
                                    const SizedBox(height: 8),
                                    _buildPreviewMetadataRow('Tanggal Dibuat', createdDate),
                                    const SizedBox(height: 8),
                                    _buildPreviewMetadataRow('Tanggal Cetak', '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Metric Cards Summary Row
                        Row(
                          children: [
                            Expanded(child: _buildPreviewMetricCard('Siswa Terdaftar', totalMurid.toString(), Icons.groups_rounded, const Color(0xFFEFF6FF), const Color(0xFF2563EB))),
                            const SizedBox(width: 16),
                            Expanded(child: _buildPreviewMetricCard('Total Poin Kelas', totalPoin.toString(), Icons.star_rounded, const Color(0xFFFEF3C7), const Color(0xFFD97706))),
                            const SizedBox(width: 16),
                            Expanded(child: _buildPreviewMetricCard('Artwork Diserahkan', totalKarya.toString(), Icons.palette_rounded, const Color(0xFFF5F3FF), const Color(0xFF7C3AED))),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // Section Title
                        Row(
                          children: const [
                            Icon(Icons.format_list_bulleted_rounded, color: Color(0xFF475569), size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Daftar Rincian Nilai Murid',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Student DataTable
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Theme(
                                data: Theme.of(context).copyWith(
                                  dividerColor: const Color(0xFFE2E8F0),
                                ),
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                                  dataRowMaxHeight: 52,
                                  dataRowMinHeight: 40,
                                  columns: const [
                                    DataColumn(label: Text('No', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFF475569)))),
                                    DataColumn(label: Text('Nama Lengkap', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFF475569)))),
                                    DataColumn(label: Text('Nama Panggil', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFF475569)))),
                                    DataColumn(label: Text('Username', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFF475569)))),
                                    DataColumn(label: Text('Poin', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFF475569)))),
                                    DataColumn(label: Text('Karya', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFF475569)))),
                                    DataColumn(label: Text('Grade', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFF475569)))),
                                  ],
                                  rows: List.generate(studentRows.length, (idx) {
                                    final s = studentRows[idx];
                                    final isEven = idx % 2 == 0;
                                    return DataRow(
                                      color: WidgetStateProperty.all(isEven ? Colors.white : const Color(0xFFF8FAFC)),
                                      cells: [
                                        DataCell(Text((idx + 1).toString(), style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)))),
                                        DataCell(Text(s['name'] ?? '-', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
                                        DataCell(Text(s['namaPanggilan'] ?? '-', style: const TextStyle(fontSize: 13, color: Color(0xFF334155)))),
                                        DataCell(Text(s['username'] ?? '-', style: const TextStyle(fontSize: 13, color: Color(0xFF475569)))),
                                        DataCell(
                                          Row(
                                            children: [
                                              const Icon(Icons.star_rounded, size: 14, color: Color(0xFFD97706)),
                                              const SizedBox(width: 4),
                                              Text(s['points']?.toString() ?? '0', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                            ],
                                          ),
                                        ),
                                        DataCell(Text('${s['artworks'] ?? 0} karya', style: const TextStyle(fontSize: 13, color: Color(0xFF475569)))),
                                        DataCell(
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: const Color(0xFFCBD5E1)),
                                            ),
                                            child: Text(s['grade'] ?? '-', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                                          ),
                                        ),
                                      ],
                                    );
                                  }),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Licensing note inside preview
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFCBD5E1), width: 0.5),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Icon(Icons.info_outline_rounded, color: Color(0xFF475569), size: 18),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Lisensi & Ketentuan: Seluruh laporan data kelas dilisensikan di bawah lisensi resmi EPIC (Ecocultural Pattern Innovation Creator) © 2026. Data ini konfidensial dan hak cipta dilindungi undang-undang.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF475569),
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Premium Footer Action buttons
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                  color: Colors.white,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          _downloadClassReport(
                            context,
                            className,
                            classCode,
                            teacherName,
                            school,
                            createdDate,
                            studentRows,
                            classArtworksDocs,
                          );
                        },
                        icon: const Icon(Icons.grid_on_rounded, size: 16),
                        label: const Text('Unduh Excel (CSV)', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2563EB), Color(0xFF1E3A8A)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2563EB).withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          ),
                          onPressed: () async {
                            Navigator.of(context).pop();
                            try {
                              final pdfBytes = await KelasPdfGenerator.generateReport(
                                className: className,
                                classCode: classCode,
                                teacherName: teacherName,
                                school: school,
                                createdDate: createdDate,
                                studentRows: studentRows,
                                classArtworksDocs: classArtworksDocs,
                              );
                              final cleanName = className.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
                              FileDownloadHelper.downloadBytes(
                                pdfBytes,
                                'Laporan_Kelas_$cleanName.pdf',
                                'application/pdf',
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Laporan PDF kelas "$className" berhasil diunduh!'),
                                    backgroundColor: AdminColors.success,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Gagal mengunduh laporan PDF: $e'),
                                    backgroundColor: AdminColors.danger,
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                          label: const Text('Unduh Laporan PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPreviewMetadataRow(String label, String value, {bool isBold = false}) {
    return RichText(
      text: TextSpan(
        text: '$label:  ',
        style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
        children: [
          TextSpan(
            text: value,
            style: TextStyle(
              fontSize: 13,
              color: const Color(0xFF1E293B),
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewMetricCard(String label, String value, IconData icon, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: textColor.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.6),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: textColor, size: 20),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: textColor.withOpacity(0.75), letterSpacing: 0.5),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardCard(BuildContext context, List<Map<String, dynamic>> items) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.emoji_events_rounded, color: Color(0xFFF59E0B), size: 22),
              SizedBox(width: 10),
              Text(
                'Leaderboard Kelas',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  fontSize: 16,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'Belum ada data leaderboard',
                  style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                ),
              ),
            )
          else
            ...items.map((item) {
              return _buildLeaderboardItem(
                context,
                item['rank'] as int,
                item['name'] as String,
                item['points'] as int,
                item['emoji'] as String,
              );
            }).toList(),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideY(begin: 0.04, end: 0, curve: Curves.easeOutQuad);
  }

  Widget _buildLeaderboardItem(BuildContext context, int rank, String name, int points, String rankIcon) {
    Color itemBgColor = Colors.transparent;
    Color borderCol = const Color(0xFFE2E8F0);
    
    if (rank == 1) {
      itemBgColor = const Color(0xFFFFFBEB);
      borderCol = const Color(0xFFFDE68A);
    } else if (rank == 2) {
      itemBgColor = const Color(0xFFF8FAFC);
      borderCol = const Color(0xFFE2E8F0);
    } else if (rank == 3) {
      itemBgColor = const Color(0xFFFFF7ED);
      borderCol = const Color(0xFFFFEDD5);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: itemBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol, width: 1.2),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              rankIcon,
              style: TextStyle(
                fontSize: rank <= 3 ? 20 : 14, 
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 14),
          CircleAvatar(
            backgroundColor: rank == 1 
                ? const Color(0xFFFCD34D) 
                : (rank == 2 ? const Color(0xFFCBD5E1) : (rank == 3 ? const Color(0xFFFDBA74) : const Color(0xFFEFF6FF))),
            radius: 18,
            child: Text(
              name.isNotEmpty ? name.substring(0, 1) : 'S',
              style: TextStyle(
                color: rank <= 3 ? const Color(0xFF1E293B) : const Color(0xFF2563EB), 
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name, 
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
                fontSize: 14,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: rank == 1 ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: rank == 1 ? const Color(0xFFFCD34D).withOpacity(0.3) : const Color(0xFFE2E8F0)),
            ),
            child: Text(
              '$points pts',
              style: TextStyle(
                fontWeight: FontWeight.bold, 
                color: rank == 1 ? const Color(0xFFB45309) : const Color(0xFF475569),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtworksCard(BuildContext context, List<Map<String, dynamic>> items) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.palette_rounded, color: Color(0xFF4F46E5), size: 22),
              SizedBox(width: 10),
              Text(
                'Karya Terbaru',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  fontSize: 16,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'Belum ada karya terbaru',
                  style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                ),
              ),
            )
          else
            ...items.map((item) {
              return _buildRecentArtwork(
                context,
                item['title'] as String,
                item['student'] as String,
                item['grade'] as String,
                item['color'] as Color,
              );
            }).toList(),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 250.ms).slideY(begin: 0.04, end: 0, curve: Curves.easeOutQuad);
  }

  Widget _buildRecentArtwork(BuildContext context, String title, String student, String grade, Color gradeColor) {
    Gradient artGradient;
    if (title.contains('BATIK')) {
      artGradient = const LinearGradient(
        colors: [Color(0xFFFDBA74), Color(0xFFF97316)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (title.contains('KERIS')) {
      artGradient = const LinearGradient(
        colors: [Color(0xFFC084FC), Color(0xFF8B5CF6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else {
      artGradient = const LinearGradient(
        colors: [Color(0xFF6EE7B7), Color(0xFF059669)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: artGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.art_track_rounded, color: Colors.white, size: 24),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title, 
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Oleh: $student', 
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: gradeColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: gradeColor.withOpacity(0.2)),
            ),
            child: Text(
              'Grade $grade',
              style: TextStyle(
                color: gradeColor, 
                fontWeight: FontWeight.w800, 
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentsCard(BuildContext context, String classId, List<Map<String, dynamic>> list, String studentCount) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.people_alt_rounded, color: Color(0xFF2563EB), size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'Daftar Murid ($studentCount)',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      fontSize: 18,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              children: const [
                Expanded(
                  flex: 4,
                  child: Text(
                    'NAMA MURID',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 11, letterSpacing: 0.5),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'TOTAL POIN',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 11, letterSpacing: 0.5),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'ARTWORK SUBMIT',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 11, letterSpacing: 0.5),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'GRADE TERBANYAK',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 11, letterSpacing: 0.5),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'AKTIF TERAKHIR',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 11, letterSpacing: 0.5),
                  ),
                ),
                SizedBox(width: 100, child: Center(
                  child: Text(
                    'AKSI',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 11, letterSpacing: 0.5),
                  ),
                )),
              ],
            ),
          ),
          const Divider(color: Color(0xFFE2E8F0), height: 1),
          const SizedBox(height: 12),

          list.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'Belum ada data murid',
                      style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final student = list[index];
                    return _HoverableStudentRow(
                      name: student['name'] as String,
                      points: student['points'] as int,
                      artworks: student['artworks'] as int,
                      topGrade: student['grade'] as String,
                      lastActive: student['active'] as String,
                      studentId: student['uid'] as String,
                      classId: classId,
                    );
                  },
                ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 300.ms).slideY(begin: 0.04, end: 0, curve: Curves.easeOutQuad);
  }
}

class _HoverableStudentRow extends StatefulWidget {
  final String name;
  final int points;
  final int artworks;
  final String topGrade;
  final String lastActive;
  final String studentId;
  final String classId;

  const _HoverableStudentRow({
    required this.name,
    required this.points,
    required this.artworks,
    required this.topGrade,
    required this.lastActive,
    required this.studentId,
    required this.classId,
  });

  @override
  State<_HoverableStudentRow> createState() => _HoverableStudentRowState();
}

class _HoverableStudentRowState extends State<_HoverableStudentRow> {
  bool _isHovered = false;

  void _removeStudentFromClass(BuildContext context, String classId, String studentId, String name) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Keluarkan Murid'),
          content: Text('Apakah Anda yakin ingin mengeluarkan murid "$name" dari kelas ini?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Batal'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AdminColors.danger),
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  final batch = FirebaseFirestore.instance.batch();

                  // 1. Remove from class list in kelas doc
                  final classRef = FirebaseFirestore.instance.collection('kelas').doc(classId);
                  batch.update(classRef, {
                    'muridIds': FieldValue.arrayRemove([studentId]),
                  });

                  // 2. Remove classId from student's kelasIds array
                  final userRef = FirebaseFirestore.instance.collection('users').doc(studentId);
                  batch.update(userRef, {
                    'kelasIds': FieldValue.arrayRemove([classId]),
                  });

                  await batch.commit();

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Murid "$name" berhasil dikeluarkan dari kelas.'), backgroundColor: AdminColors.success),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Gagal mengeluarkan murid: $e'), backgroundColor: AdminColors.danger),
                    );
                  }
                }
              },
              child: const Text('Keluarkan', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String initials = 'S';
    if (widget.name.isNotEmpty) {
      final parts = widget.name.trim().split(' ');
      initials = parts.take(2).map((e) => e.isNotEmpty ? e[0] : '').join().toUpperCase();
    }
    if (initials.isEmpty) initials = 'S';

    Color gradeColor = const Color(0xFF64748B);
    if (widget.topGrade.contains('S')) {
      gradeColor = const Color(0xFF8B5CF6);
    } else if (widget.topGrade.contains('A')) {
      gradeColor = const Color(0xFF10B981);
    } else if (widget.topGrade.contains('B')) {
      gradeColor = const Color(0xFF3B82F6);
    } else if (widget.topGrade.contains('C') || widget.topGrade.contains('D')) {
      gradeColor = const Color(0xFFF59E0B);
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _isHovered 
                ? AdminColors.primary.withOpacity(0.4) 
                : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: [
            _isHovered
                ? BoxShadow(
                    color: AdminColors.primary.withOpacity(0.06),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  )
                : BoxShadow(
                    color: Colors.black.withOpacity(0.01),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
          ],
        ),
        transform: Matrix4.translationValues(0, _isHovered ? -2 : 0, 0),
        child: Row(
          children: [
            // Student Profile
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFFEFF6FF),
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      widget.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            
            // Points
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 6),
                  Text(
                    '${widget.points} Poin',
                    style: const TextStyle(
                      color: Color(0xFF334155),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            
            // Artworks Count
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  const Icon(Icons.palette_rounded, size: 16, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Text(
                    '${widget.artworks} Karya',
                    style: const TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            
            // Top Grade Capsule
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: gradeColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: gradeColor.withOpacity(0.2)),
                    ),
                    child: Text(
                      widget.topGrade,
                      style: TextStyle(
                        color: gradeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Last Active
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 6),
                  Text(
                    widget.lastActive,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            
            // Actions
            SizedBox(
              width: 100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.visibility_rounded, size: 20),
                    color: const Color(0xFF2563EB),
                    hoverColor: const Color(0xFF2563EB).withOpacity(0.08),
                    onPressed: () => context.go('/users/murid/${widget.studentId}'),
                    tooltip: 'Lihat Detail',
                  ),
                  IconButton(
                    icon: const Icon(Icons.person_remove_rounded, size: 20),
                    color: const Color(0xFFEF4444),
                    hoverColor: const Color(0xFFEF4444).withOpacity(0.08),
                    onPressed: () => _removeStudentFromClass(context, widget.classId, widget.studentId, widget.name),
                    tooltip: 'Keluarkan dari Kelas',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
