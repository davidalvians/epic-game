import 'package:epic_admin/core/theme/admin_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:epic_admin/core/utils/file_download_helper.dart';
import 'package:epic_admin/core/utils/kelas_pdf_generator.dart';

String _getProxiedImageUrl(String url) {
  if (url.isEmpty) return '';
  if (url.contains('firebasestorage.googleapis.com') || url.contains('googleusercontent.com')) {
    return 'https://images.weserv.nl/?url=${Uri.encodeComponent(url)}';
  }
  return url;
}

class KelasDetailScreen extends StatefulWidget {
  final String id;
  const KelasDetailScreen({super.key, required this.id});

  @override
  State<KelasDetailScreen> createState() => _KelasDetailScreenState();
}

class _KelasDetailScreenState extends State<KelasDetailScreen> {
  String _selectedCategory = 'Semua';
  String _studentSearchQuery = '';
  final TextEditingController _studentSearchController = TextEditingController();

  @override
  void dispose() {
    _studentSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWide = screenWidth >= 1100;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('kelas').doc(widget.id).snapshots(),
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

                // Filter students who are members of this class
                final classStudents = allStudents.where((doc) {
                  return muridIds.contains(doc.id);
                }).toList();

                final int studentCount = classStudents.length;

                // Stream artworks specifically created for this class (kelasId == widget.id)
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('artworks')
                      .where('kelasId', isEqualTo: widget.id)
                      .snapshots(),
                  builder: (context, artworksSnapshot) {
                    final classArtworksDocs = (artworksSnapshot.data?.docs ?? [])
                        .cast<QueryDocumentSnapshot<Map<String, dynamic>>>();

                    // Sort artworks descending by createdAt
                    classArtworksDocs.sort((a, b) {
                      final aData = a.data();
                      final bData = b.data();
                      final Timestamp aTime = aData['createdAt'] is Timestamp ? aData['createdAt'] : Timestamp.now();
                      final Timestamp bTime = bData['createdAt'] is Timestamp ? bData['createdAt'] : Timestamp.now();
                      return bTime.compareTo(aTime);
                    });

                    // 1. Calculate class-specific points for each student (sum of poinDapat in this class)
                    final Map<String, int> studentClassPoints = {};
                    for (var aDoc in classArtworksDocs) {
                      final aData = aDoc.data();
                      final String studentUid = aData['uid'] ?? '';
                      final int pts = aData['poinDapat'] is int
                          ? aData['poinDapat'] as int
                          : (int.tryParse(aData['poinDapat']?.toString() ?? '') ?? 0);
                      studentClassPoints[studentUid] = (studentClassPoints[studentUid] ?? 0) + pts;
                    }

                    // 2. Total points of the class
                    final int totalPoints = studentClassPoints.values.fold<int>(0, (sum, p) => sum + p);

                    // 3. Calculate average AI score of artworks in this class
                    double totalArtworkScore = 0;
                    int artworkCount = classArtworksDocs.length;
                    for (var aDoc in classArtworksDocs) {
                      final aData = aDoc.data();
                      final int score = aData['skorAI'] is int
                          ? aData['skorAI'] as int
                          : (int.tryParse(aData['skorAI']?.toString() ?? '') ?? 0);
                      totalArtworkScore += score;
                    }

                    final double avgScore = artworkCount > 0
                        ? (totalArtworkScore / artworkCount)
                        : 0.0;

                    // 4. Count students with zero artworks in this class
                    final int zeroWorksCount = classStudents.where((sDoc) {
                      return !classArtworksDocs.any((aDoc) => aDoc.data()['uid'] == sDoc.id);
                    }).length;

                    // 5. Build Class Leaderboard items
                    final List<Map<String, dynamic>> leaderboardItems = classStudents.map((doc) {
                      final sData = doc.data();
                      return {
                        'uid': doc.id,
                        'name': sData['namaLengkap'] ?? sData['nama'] ?? 'Tanpa Nama',
                        'points': studentClassPoints[doc.id] ?? 0,
                      };
                    }).toList();

                    // Sort leaderboard descending by class-specific points
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

                    // Build student ranks map based on leaderboard (points descending)
                    final Map<String, int> studentRanks = {};
                    for (int i = 0; i < leaderboardItems.length; i++) {
                      final String uid = leaderboardItems[i]['uid'] as String;
                      studentRanks[uid] = i + 1;
                    }

                    // 6. Map to students table rows (scoped strictly to this class)
                    final List<Map<String, dynamic>> studentRows = classStudents.map((doc) {
                      final sData = doc.data();
                      final String studentUid = doc.id;

                      // Artworks submitted by this student in this class
                      final studentArtworks = classArtworksDocs.where((a) {
                        return a.data()['uid'] == studentUid;
                      }).toList();

                      // Compute top grade in this class
                      Map<String, int> grades = {};
                      for (var art in studentArtworks) {
                        final aData = art.data();
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
                        'rank': studentRanks[studentUid] ?? (leaderboardItems.length + 1),
                        'name': sData['namaLengkap'] ?? sData['nama'] ?? 'Tanpa Nama',
                        'namaPanggilan': sData['namaPanggilan'] ?? '-',
                        'username': sData['username'] ?? '-',
                        'points': studentClassPoints[studentUid] ?? 0,
                        'artworks': studentArtworks.length,
                        'grade': topGrade,
                        'active': lastActStr,
                      };
                    }).toList();

                    // Sort student rows alphabetically (A - Z) by student name
                    studentRows.sort((a, b) => (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase()));

                    // Filter students by search query
                    final filteredStudentRows = studentRows.where((s) {
                      final query = _studentSearchQuery.trim().toLowerCase();
                      if (query.isEmpty) return true;
                      final name = (s['name'] as String).toLowerCase();
                      final nickname = (s['namaPanggilan'] as String).toLowerCase();
                      final username = (s['username'] as String).toLowerCase();
                      return name.contains(query) || nickname.contains(query) || username.contains(query);
                    }).toList();

                    // 7. Filter class artworks by selected category for the Gallery Preview
                    final filteredArtworksDocs = classArtworksDocs.where((doc) {
                      if (_selectedCategory == 'Semua') return true;
                      final cat = (doc.data()['kategori'] ?? '').toString().toLowerCase();
                      return cat == _selectedCategory.toLowerCase();
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
                                        _buildClassHeaderCard(
                                          context: context,
                                          className: className,
                                          school: school,
                                          classCode: classCode,
                                          teacherName: teacherName,
                                          createdDate: createdDate,
                                          studentCount: studentCount,
                                          avgScore: avgScore,
                                          isClassActive: isClassActive,
                                          studentRows: studentRows,
                                          classArtworksDocs: classArtworksDocs,
                                        ),
                                        const SizedBox(height: 24),

                                        // Quick Metrics Summary Row
                                        _buildQuickMetricsRow(
                                          studentCount: studentCount,
                                          artworkCount: artworkCount,
                                          avgScore: avgScore,
                                          totalPoints: totalPoints,
                                          zeroWorksCount: zeroWorksCount,
                                        ),
                                        const SizedBox(height: 32),

                                        // Leaderboard & Gallery Preview Sections
                                        if (isWide)
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Leaderboard on the left
                                              SizedBox(
                                                width: 360,
                                                child: _buildLeaderboardCard(context, leaderboardWithRanks),
                                              ),
                                              const SizedBox(width: 24),
                                              // Gallery & Artwork Preview on the right
                                              Expanded(
                                                child: _buildClassArtworksGalleryCard(
                                                  context: context,
                                                  artworks: filteredArtworksDocs,
                                                  allArtworksCount: classArtworksDocs.length,
                                                  allStudents: allStudents,
                                                ),
                                              ),
                                            ],
                                          )
                                        else
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.stretch,
                                            children: [
                                              _buildLeaderboardCard(context, leaderboardWithRanks),
                                              const SizedBox(height: 24),
                                              _buildClassArtworksGalleryCard(
                                                context: context,
                                                artworks: filteredArtworksDocs,
                                                allArtworksCount: classArtworksDocs.length,
                                                allStudents: allStudents,
                                              ),
                                            ],
                                          ),
                                        const SizedBox(height: 32),

                                        // Students List Card
                                        _buildStudentsCard(
                                          context: context,
                                          classId: widget.id,
                                          list: filteredStudentRows,
                                          studentCount: studentCount.toString(),
                                        ),
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

  // ==========================================
  // 1. CLASS HEADER CARD WIDGET
  // ==========================================
  Widget _buildClassHeaderCard({
    required BuildContext context,
    required String className,
    required String school,
    required String classCode,
    required String teacherName,
    required String createdDate,
    required int studentCount,
    required double avgScore,
    required bool isClassActive,
    required List<Map<String, dynamic>> studentRows,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> classArtworksDocs,
  }) {
    return Container(
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
                              color: Colors.white.withOpacity(0.85),
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
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  _buildHeaderBadge(Icons.person_rounded, 'Wali Kelas: $teacherName'),
                  _buildHeaderBadge(Icons.calendar_today_rounded, 'Dibuat: $createdDate'),
                  _buildHeaderBadge(Icons.groups_rounded, '$studentCount Murid Terdaftar'),
                  _buildHeaderBadge(Icons.analytics_rounded, 'Rata-rata Skor: ${avgScore.toStringAsFixed(1)}'),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () => _toggleArchiveClass(context, widget.id, isClassActive, className),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isClassActive ? const Color(0xFFD1FAE5) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: (isClassActive ? const Color(0xFF10B981) : const Color(0xFF64748B)).withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(isClassActive ? Icons.check_circle_rounded : Icons.archive_rounded, size: 13, color: isClassActive ? const Color(0xFF065F46) : const Color(0xFF475569)),
                              const SizedBox(width: 6),
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
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withOpacity(0.25)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.download_rounded, size: 13, color: Colors.white),
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
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.04, end: 0, curve: Curves.easeOutQuad);
  }

  // ==========================================
  // 2. QUICK METRICS ROW WIDGET
  // ==========================================
  Widget _buildQuickMetricsRow({
    required int studentCount,
    required int artworkCount,
    required double avgScore,
    required int totalPoints,
    required int zeroWorksCount,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isSmall = constraints.maxWidth < 800;
        final bool isExtraSmall = constraints.maxWidth < 500;
        return GridView.count(
          crossAxisCount: isSmall ? 2 : 4,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: isExtraSmall ? 1.35 : (isSmall ? 2.0 : 2.5),
          children: [
            _buildMetricItemCard(
              title: 'TOTAL KARYA KELAS',
              value: '$artworkCount Karya',
              icon: Icons.palette_rounded,
              color: const Color(0xFF2563EB),
              bgColor: const Color(0xFFEFF6FF),
              subtitle: zeroWorksCount > 0 ? '$zeroWorksCount siswa belum berkarya' : 'Semua siswa telah berkarya',
            ),
            _buildMetricItemCard(
              title: 'TOTAL POIN KELAS',
              value: '$totalPoints Pts',
              icon: Icons.star_rounded,
              color: const Color(0xFFD97706),
              bgColor: const Color(0xFFFFFBEB),
              subtitle: 'Akumulasi poin karya kelas',
            ),
            _buildMetricItemCard(
              title: 'RATA-RATA SKOR AI',
              value: avgScore.toStringAsFixed(1),
              icon: Icons.auto_awesome_rounded,
              color: const Color(0xFF10B981),
              bgColor: const Color(0xFFECFDF5),
              subtitle: 'Skor penilaian AI Gemini',
            ),
            _buildMetricItemCard(
              title: 'SISWA AKTIF',
              value: '$studentCount Murid',
              icon: Icons.groups_rounded,
              color: const Color(0xFF8B5CF6),
              bgColor: const Color(0xFFF5F3FF),
              subtitle: 'Terdaftar di kelas ini',
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricItemCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 3. CLASS ARTWORKS GALLERY & PREVIEW CARD
  // ==========================================
  Widget _buildClassArtworksGalleryCard({
    required BuildContext context,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> artworks,
    required int allArtworksCount,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> allStudents,
  }) {
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
          // Header Row with Title and Category Filter Chips
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.palette_rounded, color: Color(0xFF2563EB), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Galeri & Pratinjau Karya Kelas',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              fontSize: 17,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Text(
                              '$allArtworksCount Karya',
                              style: const TextStyle(
                                color: Color(0xFF1E40AF),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Karya yang dikerjakan khusus untuk kelas ini',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Category Filter Pills
              Wrap(
                spacing: 8,
                children: ['Semua', 'Batik', 'Keris', 'Anyaman'].map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    selectedColor: const Color(0xFF1E3A8A),
                    backgroundColor: const Color(0xFFF1F5F9),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFF475569),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      fontSize: 12,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    side: BorderSide(
                      color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFFE2E8F0),
                    ),
                    onSelected: (val) {
                      if (val) {
                        setState(() => _selectedCategory = cat);
                      }
                    },
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Artwork Grid / Empty State
          if (artworks.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 48),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.brush_outlined, size: 36, color: Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _selectedCategory == 'Semua'
                        ? 'Belum ada karya yang dibuat di kelas ini.'
                        : 'Belum ada karya untuk kategori $_selectedCategory di kelas ini.',
                    style: const TextStyle(
                      color: Color(0xFF475569),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Karya murid yang dibuat saat memilih kelas ini akan otomatis tampil di sini.',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final double width = constraints.maxWidth;
                int crossAxisCount = 3;
                if (width < 600) crossAxisCount = 1;
                else if (width < 950) crossAxisCount = 2;

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: artworks.length,
                  itemBuilder: (context, index) {
                    final artDoc = artworks[index];
                    final aData = artDoc.data();
                    final String uid = aData['uid'] ?? '';

                    // Find student creator name
                    String studentName = 'Siswa';
                    String studentNickname = '';
                    final sDoc = allStudents.where((s) => s.id == uid).firstOrNull;
                    if (sDoc != null) {
                      final sData = sDoc.data();
                      studentName = sData['namaLengkap'] ?? sData['nama'] ?? 'Siswa';
                      studentNickname = sData['namaPanggilan'] ?? '';
                    }

                    return _HoverableClassArtworkCard(
                      artworkData: aData,
                      studentName: studentName,
                      studentNickname: studentNickname,
                      onTap: () => _showArtworkDetailDialog(context, aData, studentName),
                    );
                  },
                );
              },
            ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 250.ms).slideY(begin: 0.04, end: 0, curve: Curves.easeOutQuad);
  }

  // ==========================================
  // 4. LEADERBOARD CARD WIDGET
  // ==========================================
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
          const SizedBox(height: 6),
          const Text(
            'Berdasarkan poin karya di kelas ini',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 20),
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
            ...items.take(10).map((item) {
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
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: itemBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol, width: 1.2),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              rankIcon,
              style: TextStyle(
                fontSize: rank <= 3 ? 18 : 13,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            backgroundColor: rank == 1
                ? const Color(0xFFFCD34D)
                : (rank == 2 ? const Color(0xFFCBD5E1) : (rank == 3 ? const Color(0xFFFDBA74) : const Color(0xFFEFF6FF))),
            radius: 16,
            child: Text(
              name.isNotEmpty ? name.substring(0, 1) : 'S',
              style: TextStyle(
                color: rank <= 3 ? const Color(0xFF1E293B) : const Color(0xFF2563EB),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
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
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 5. STUDENTS CARD & SEARCH TABLE
  // ==========================================
  Widget _buildStudentsCard({
    required BuildContext context,
    required String classId,
    required List<Map<String, dynamic>> list,
    required String studentCount,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 18 : 24),
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
          if (isMobile) ...[
            Row(
              children: [
                const Icon(Icons.people_alt_rounded, color: Color(0xFF2563EB), size: 20),
                const SizedBox(width: 8),
                Text(
                  'Daftar Murid ($studentCount)',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    fontSize: 16,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _studentSearchController,
              onChanged: (val) => setState(() => _studentSearchQuery = val),
              decoration: InputDecoration(
                hintText: 'Cari murid di kelas ini...',
                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                suffixIcon: _studentSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () {
                          _studentSearchController.clear();
                          setState(() => _studentSearchQuery = '');
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF2563EB)),
                ),
              ),
            ),
          ] else ...[
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
                // Search student input
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _studentSearchController,
                    onChanged: (val) => setState(() => _studentSearchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Cari murid di kelas ini...',
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                      suffixIcon: _studentSearchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16),
                              onPressed: () {
                                _studentSearchController.clear();
                                setState(() => _studentSearchQuery = '');
                              },
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF2563EB)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                children: const [
                  SizedBox(
                    width: 64,
                    child: Text(
                      'RANK',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD97706), fontSize: 11, letterSpacing: 0.5),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(
                      'NAMA MURID (A-Z)',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 11, letterSpacing: 0.5),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'POIN KELAS',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 11, letterSpacing: 0.5),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'KARYA KELAS',
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
                  SizedBox(
                    width: 100,
                    child: Center(
                      child: Text(
                        'AKSI',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 11, letterSpacing: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFFE2E8F0), height: 1),
          ],
          const SizedBox(height: 12),

          list.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'Tidak ada data murid yang sesuai.',
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
                      rank: (student['rank'] is int) ? student['rank'] as int : (index + 1),
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

  // ==========================================
  // 6. ARTWORK DETAIL MODAL DIALOG
  // ==========================================
  void _showArtworkDetailDialog(BuildContext context, Map<String, dynamic> artwork, String studentName) {
    final String kategori = (artwork['kategori'] ?? 'Karya').toString();
    final String judulKarya = (artwork['judulKarya'] ?? '').toString().trim();
    final String displayTitle = judulKarya.isNotEmpty ? judulKarya : kategori.toUpperCase();
    final int skor = artwork['skorAI'] is int
        ? artwork['skorAI'] as int
        : (int.tryParse(artwork['skorAI']?.toString() ?? '') ?? 0);
    final String grade = artwork['grade'] ?? 'C';
    final int poinDapat = artwork['poinDapat'] is int
        ? artwork['poinDapat'] as int
        : (int.tryParse(artwork['poinDapat']?.toString() ?? '') ?? 0);
    final int level = artwork['level'] is int ? artwork['level'] as int : 1;
    final int waktuPengerjaan = artwork['waktuPengerjaan'] is int ? artwork['waktuPengerjaan'] as int : 0;
    final String modelAI = artwork['modelAI'] ?? 'gemini-2.5-flash-lite';
    final String rawFeedback = (artwork['feedback'] as String?)?.trim() ?? '';
    final String rawFeedbackAI = (artwork['feedbackAI'] as String?)?.trim() ?? '';
    final String feedback = rawFeedback.isNotEmpty
        ? rawFeedback
        : (rawFeedbackAI.isNotEmpty ? rawFeedbackAI : 'Tidak ada catatan feedback AI.');
    final String imageUrl = artwork['imageUrl'] ?? '';
    final Map<String, dynamic> detailPenilaian = artwork['detailPenilaian'] is Map
        ? Map<String, dynamic>.from(artwork['detailPenilaian'])
        : {};

    final dynamic createdVal = artwork['createdAt'];
    String dateStr = '-';
    if (createdVal is Timestamp) {
      final dt = createdVal.toDate();
      dateStr = '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }

    Color gradeColor = const Color(0xFFEF4444);
    if (grade == 'S') gradeColor = const Color(0xFFD946EF);
    if (grade == 'A') gradeColor = const Color(0xFF10B981);
    if (grade == 'B') gradeColor = const Color(0xFF3B82F6);
    if (grade == 'C') gradeColor = const Color(0xFFF59E0B);

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          clipBehavior: Clip.antiAlias,
          backgroundColor: const Color(0xFFF8FAFC),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.75,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.88,
              maxWidth: 960,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Modal Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
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
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.palette_rounded, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayTitle,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Karya oleh $studentName • Diserahkan: $dateStr',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.85),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                        hoverColor: Colors.white.withOpacity(0.1),
                      ),
                    ],
                  ),
                ),

                // Modal Content Body
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(28),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left: Artwork Preview Image
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                height: 380,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.06),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: imageUrl.isNotEmpty
                                          ? Image.network(
                                              _getProxiedImageUrl(imageUrl),
                                              fit: BoxFit.contain,
                                              errorBuilder: (context, error, stackTrace) => CustomPaint(
                                                painter: GenerativeArtPainter(grade: grade),
                                              ),
                                            )
                                          : CustomPaint(
                                              painter: GenerativeArtPainter(grade: grade),
                                            ),
                                    ),
                                    Positioned(
                                      top: 14,
                                      right: 14,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.65),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: gradeColor.withOpacity(0.5)),
                                        ),
                                        child: Text(
                                          'Grade $grade',
                                          style: TextStyle(
                                            color: gradeColor,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),

                        // Right: Scoring & AI Breakdown
                        Expanded(
                          flex: 6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Score Metrics Banner
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildArtworkModalMetric('SKOR AI', '$skor/100', Icons.auto_awesome_rounded, gradeColor),
                                    Container(width: 1, height: 36, color: const Color(0xFFE2E8F0)),
                                    _buildArtworkModalMetric('POIN KELAS', '+$poinDapat Pts', Icons.star_rounded, const Color(0xFFD97706)),
                                    Container(width: 1, height: 36, color: const Color(0xFFE2E8F0)),
                                    _buildArtworkModalMetric('LEVEL', 'Level $level', Icons.trending_up_rounded, const Color(0xFF2563EB)),
                                    Container(width: 1, height: 36, color: const Color(0xFFE2E8F0)),
                                    _buildArtworkModalMetric('WAKTU', '${waktuPengerjaan}s', Icons.timer_rounded, const Color(0xFF64748B)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              // AI Criteria Breakdown (if any)
                              if (detailPenilaian.isNotEmpty) ...[
                                const Text(
                                  'Rincian Penilaian AI',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Column(
                                    children: detailPenilaian.entries.map((entry) {
                                      final rawVal = entry.value;
                                      final int scoreVal = rawVal is num ? rawVal.toInt() : (int.tryParse(rawVal.toString()) ?? 0);
                                      final double progress = (scoreVal / 100.0).clamp(0.0, 1.0);
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  entry.key,
                                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                                                ),
                                                Text(
                                                  '$scoreVal%',
                                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(4),
                                              child: LinearProgressIndicator(
                                                value: progress,
                                                minHeight: 6,
                                                backgroundColor: const Color(0xFFF1F5F9),
                                                valueColor: AlwaysStoppedAnimation<Color>(
                                                  progress >= 0.8 ? const Color(0xFF10B981) : (progress >= 0.6 ? const Color(0xFF3B82F6) : const Color(0xFFF59E0B)),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],

                              // Feedback & Evaluasi AI
                              const Text(
                                'Evaluasi & Masukan AI',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.psychology_rounded, size: 18, color: Color(0xFF2563EB)),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Feedback Otomatis ($modelAI)',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                            color: Color(0xFF2563EB),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      feedback,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF334155),
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Modal Footer
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                  color: Colors.white,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildArtworkModalMetric(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 9, color: Color(0xFF94A3B8)),
        ),
      ],
    );
  }

  // ==========================================
  // 7. TOGGLE ARCHIVE CLASS
  // ==========================================
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

  // ==========================================
  // 8. DOWNLOAD CSV & PDF REPORTS
  // ==========================================
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
      buffer.writeln('"No","Peringkat","Nama Lengkap","Nama Panggilan","Username","Total Poin (Kelas)","Total Karya (Kelas)","Level Maks (Keris)","Level Maks (Batik)","Level Maks (Anyaman)","Rata-rata Skor AI","Grade Terbanyak","Aktif Terakhir"');

      for (int i = 0; i < studentRows.length; i++) {
        final student = studentRows[i];
        final uid = student['uid'] ?? '';
        final rank = student['rank'] ?? (i + 1);
        final name = student['name'] ?? '';
        final nickname = student['namaPanggilan'] ?? '-';
        final username = student['username'] ?? '-';
        final points = student['points'] ?? 0;
        final artworksCount = student['artworks'] ?? 0;
        final topGrade = student['grade'] ?? '-';
        final lastActive = student['active'] ?? '-';

        // Filter artworks by this student strictly for this class
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

        buffer.writeln('"${i + 1}","#$rank","${name.replaceAll('"', '""')}","${nickname.replaceAll('"', '""')}","${username.replaceAll('"', '""')}","$points","$artworksCount","$maxKeris","$maxBatik","$maxAnyaman","${avgAI.toStringAsFixed(1)}","$topGrade","$lastActive"');
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
    final int totalPoin = studentRows.fold<int>(0, (acc, s) => acc + (s['points'] as int));
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
                // Gradient Header
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
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                        hoverColor: Colors.white.withOpacity(0.1),
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
                                color: Colors.black.withOpacity(0.015),
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
                              'Daftar Rincian Nilai Murid (A-Z)',
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
                                    DataColumn(label: Text('Rank', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFFD97706)))),
                                    DataColumn(label: Text('Nama Lengkap', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFF475569)))),
                                    DataColumn(label: Text('Nama Panggil', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFF475569)))),
                                    DataColumn(label: Text('Username', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFF475569)))),
                                    DataColumn(label: Text('Poin Kelas', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFF475569)))),
                                    DataColumn(label: Text('Karya Kelas', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFF475569)))),
                                    DataColumn(label: Text('Grade', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFF475569)))),
                                  ],
                                  rows: List.generate(studentRows.length, (idx) {
                                    final s = studentRows[idx];
                                    final isEven = idx % 2 == 0;
                                    return DataRow(
                                      color: WidgetStateProperty.all(isEven ? Colors.white : const Color(0xFFF8FAFC)),
                                      cells: [
                                        DataCell(Text((idx + 1).toString(), style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)))),
                                        DataCell(
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFFBEB),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: const Color(0xFFFDE68A)),
                                            ),
                                            child: Text('#${s['rank'] ?? (idx + 1)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFB45309))),
                                          ),
                                        ),
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

                // Footer Action buttons
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
}

// ==========================================
// 9. HOVERABLE CLASS ARTWORK CARD WIDGET
// ==========================================
class _HoverableClassArtworkCard extends StatefulWidget {
  final Map<String, dynamic> artworkData;
  final String studentName;
  final String studentNickname;
  final VoidCallback onTap;

  const _HoverableClassArtworkCard({
    required this.artworkData,
    required this.studentName,
    required this.studentNickname,
    required this.onTap,
  });

  @override
  State<_HoverableClassArtworkCard> createState() => _HoverableClassArtworkCardState();
}

class _HoverableClassArtworkCardState extends State<_HoverableClassArtworkCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.artworkData;
    final String kategori = (a['kategori'] ?? 'Karya').toString();
    final String judulKarya = (a['judulKarya'] ?? '').toString().trim();
    final String displayTitle = judulKarya.isNotEmpty ? judulKarya : kategori.toUpperCase();
    final String imageUrl = a['imageUrl'] ?? '';
    final String grade = a['grade'] ?? 'C';
    final int skorAI = a['skorAI'] is int ? a['skorAI'] as int : (int.tryParse(a['skorAI']?.toString() ?? '') ?? 0);
    final int poinDapat = a['poinDapat'] is int ? a['poinDapat'] as int : (int.tryParse(a['poinDapat']?.toString() ?? '') ?? 0);
    final int level = a['level'] is int ? a['level'] as int : 1;

    Color gradeColor = const Color(0xFFEF4444);
    if (grade == 'S') gradeColor = const Color(0xFFD946EF);
    if (grade == 'A') gradeColor = const Color(0xFF10B981);
    if (grade == 'B') gradeColor = const Color(0xFF3B82F6);
    if (grade == 'C') gradeColor = const Color(0xFFF59E0B);

    Color catColor = const Color(0xFF2563EB);
    if (kategori.toLowerCase() == 'batik') catColor = const Color(0xFFF97316);
    if (kategori.toLowerCase() == 'keris') catColor = const Color(0xFF8B5CF6);
    if (kategori.toLowerCase() == 'anyaman') catColor = const Color(0xFF059669);

    final dynamic createdVal = a['createdAt'];
    String dateStr = '-';
    if (createdVal is Timestamp) {
      final dt = createdVal.toDate();
      dateStr = '${dt.day}/${dt.month}/${dt.year}';
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isHovered ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isHovered ? gradeColor.withOpacity(0.5) : const Color(0xFFE2E8F0),
                width: _isHovered ? 1.5 : 1.2,
              ),
              boxShadow: [
                _isHovered
                    ? BoxShadow(
                        color: gradeColor.withOpacity(0.12),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      )
                    : BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Artwork Thumbnail Image
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: imageUrl.isNotEmpty
                            ? Image.network(
                                _getProxiedImageUrl(imageUrl),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => CustomPaint(
                                  painter: GenerativeArtPainter(grade: grade),
                                ),
                              )
                            : CustomPaint(
                                painter: GenerativeArtPainter(grade: grade),
                              ),
                      ),
                      // Gradient Overlay for readability
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.black.withOpacity(0.4),
                                Colors.transparent,
                                Colors.black.withOpacity(0.6),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ),
                      // Category Tag (Top Left)
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: catColor,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4),
                            ],
                          ),
                          child: Text(
                            kategori.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 9,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                      // Grade Tag (Top Right)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.92),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4),
                            ],
                          ),
                          child: Text(
                            'Grade $grade',
                            style: TextStyle(
                              color: gradeColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                      // Level Badge (Bottom Left)
                      Positioned(
                        bottom: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.layers_rounded, color: Colors.white70, size: 11),
                              const SizedBox(width: 4),
                              Text(
                                'Lvl $level',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Hover Detail Overlay
                      if (_isHovered)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black.withOpacity(0.25),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.visibility_rounded, size: 14, color: gradeColor),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Pratinjau',
                                      style: TextStyle(
                                        color: gradeColor,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ).animate().fadeIn(duration: 150.ms),
                        ),
                    ],
                  ),
                ),

                // Card Info Footer
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.person_outline_rounded, size: 13, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              widget.studentName,
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (dateStr != '-')
                            Text(
                              dateStr,
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Divider(color: Color(0xFFF1F5F9), height: 1),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.smart_toy_rounded, size: 13, color: Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Text(
                                '$skorAI',
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: Text(
                              '+$poinDapat pts',
                              style: const TextStyle(
                                color: Color(0xFFB45309),
                                fontWeight: FontWeight.w800,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 10. HOVERABLE STUDENT ROW WIDGET
// ==========================================
class _HoverableStudentRow extends StatefulWidget {
  final int rank;
  final String name;
  final int points;
  final int artworks;
  final String topGrade;
  final String lastActive;
  final String studentId;
  final String classId;

  const _HoverableStudentRow({
    required this.rank,
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

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 24, vertical: isMobile ? 12 : 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(isMobile ? 14 : 18),
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
        child: isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Text(
                          '#${widget.rank}',
                          style: const TextStyle(
                            color: Color(0xFFB45309),
                            fontWeight: FontWeight.w800,
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: const Color(0xFFEFF6FF),
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color: Color(0xFF2563EB),
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.visibility_rounded, size: 18),
                        color: const Color(0xFF2563EB),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => context.go('/users/murid/${widget.studentId}'),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.person_remove_rounded, size: 18),
                        color: const Color(0xFFEF4444),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _removeStudentFromClass(context, widget.classId, widget.studentId, widget.name),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, size: 13, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 3),
                          Text(
                            '${widget.points} Pts',
                            style: const TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.bold, fontSize: 11.5),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.palette_rounded, size: 13, color: Color(0xFF64748B)),
                          const SizedBox(width: 3),
                          Text(
                            '${widget.artworks} Karya',
                            style: const TextStyle(color: Color(0xFF475569), fontSize: 11.5),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: gradeColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: gradeColor.withOpacity(0.2)),
                        ),
                        child: Text(
                          widget.topGrade,
                          style: TextStyle(color: gradeColor, fontWeight: FontWeight.bold, fontSize: 10),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.access_time_rounded, size: 11, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 3),
                          Text(
                            widget.lastActive,
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              )
            : Row(
                children: [
                  // Rank Badge
                  SizedBox(
                    width: 64,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Text(
                          '#${widget.rank}',
                          style: const TextStyle(
                            color: Color(0xFFB45309),
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ),

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

                  // Class Points
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 6),
                        Text(
                          '${widget.points} Pts',
                          style: const TextStyle(
                            color: Color(0xFF334155),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Class Artworks Count
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
                          tooltip: 'Lihat Profil Murid',
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

// ==========================================
// 11. GENERATIVE FALLBACK ART PAINTER
// ==========================================
class GenerativeArtPainter extends CustomPainter {
  final String grade;
  const GenerativeArtPainter({required this.grade});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    final center = Offset(size.width * 0.5, size.height * 0.5);
    final radius = size.width * 0.28;

    late List<Color> orbColors;
    late Color orbitColor;
    if (grade == 'S') {
      orbColors = [const Color(0xFFD946EF), const Color(0xFF8B5CF6), const Color(0xFF3B82F6).withOpacity(0)];
      orbitColor = const Color(0xFFF472B6);
    } else if (grade == 'A') {
      orbColors = [const Color(0xFF10B981), const Color(0xFF06B6D4), const Color(0xFF3B82F6).withOpacity(0)];
      orbitColor = const Color(0xFF34D399);
    } else if (grade == 'B') {
      orbColors = [const Color(0xFF3B82F6), const Color(0xFF60A5FA), const Color(0xFF93C5FD).withOpacity(0)];
      orbitColor = const Color(0xFF60A5FA);
    } else {
      orbColors = [const Color(0xFFF59E0B), const Color(0xFFFB923C), const Color(0xFFFDE047).withOpacity(0)];
      orbitColor = const Color(0xFFFBBF24);
    }

    final glowPaint = Paint()
      ..shader = RadialGradient(colors: orbColors).createShader(Rect.fromCircle(center: center, radius: radius * 1.5));
    canvas.drawCircle(center, radius * 1.3, glowPaint);

    final orbitPaint = Paint()
      ..color = orbitColor.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawOval(Rect.fromCenter(center: center, width: size.width * 0.7, height: size.height * 0.4), orbitPaint);
  }

  @override
  bool shouldRepaint(covariant GenerativeArtPainter oldDelegate) => oldDelegate.grade != grade;
}
