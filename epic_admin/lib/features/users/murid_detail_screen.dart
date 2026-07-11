import 'package:epic_admin/core/theme/admin_colors.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

String _getProxiedImageUrl(String url) {
  if (url.isEmpty) return '';
  if (url.contains('firebasestorage.googleapis.com') || url.contains('googleusercontent.com')) {
    return 'https://images.weserv.nl/?url=${Uri.encodeComponent(url)}';
  }
  return url;
}

class MuridDetailScreen extends StatelessWidget {
  final String id;
  const MuridDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(id).snapshots(),
      builder: (context, userSnapshot) {
        if (userSnapshot.hasError) {
          return Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            body: Center(child: Text('Terjadi kesalahan: ${userSnapshot.error}')),
          );
        }

        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AdminColors.primary),
              ),
            ),
          );
        }

        if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
          return Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Data murid tidak ditemukan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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

        final userData = userSnapshot.data!.data() as Map<String, dynamic>;
        final String studentName = userData['namaLengkap'] ?? userData['nama'] ?? 'Tanpa Nama';
        final String email = userData['email'] ?? '-';
        final String school = userData['sekolah'] ?? 'Belum diisi';
        final String className = userData['kelas'] ?? 'Belum ada kelas';
        final String schoolInfo = school.isNotEmpty ? '$className ($school)' : className;
        final String? avatarUrl = userData['avatarUrl'] as String?;
        
        final dynamic joinedAtVal = userData['createdAt'] ?? userData['nyawaLastReset'];
        final dynamic lastActiveVal = userData['lastActiveAt'] ?? userData['nyawaLastReset'];
        final String userStatus = userData['status'] ?? 'active';
        final bool isSuspended = userStatus == 'suspended';

        String joinDate = 'Bergabung: -';
        if (joinedAtVal is Timestamp) {
          final dt = joinedAtVal.toDate();
          joinDate = 'Bergabung: ${dt.day}/${dt.month}/${dt.year}';
        }

        String activeTime = 'Aktif: -';
        if (lastActiveVal is Timestamp) {
          final dt = lastActiveVal.toDate();
          activeTime = 'Aktif: ${dt.day}/${dt.month}/${dt.year}';
        }

        final int points = userData['poin'] is int ? userData['poin'] : 0;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
              onPressed: () => context.pop(),
            ),
            title: Text(
              'Detail Murid',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
            ),
            shape: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.2)),
          ),
          body: Stack(
            children: [
              // Background Glow Effects (Luxury Glow Backdrop)
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
                        const Color(0xFF2563EB).withOpacity(0.06),
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
                        const Color(0xFF8B5CF6).withOpacity(0.05),
                        const Color(0xFF8B5CF6).withOpacity(0),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Main Scrollable Content
              SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(32),
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('kelas').where('muridIds', arrayContains: id).snapshots(),
                  builder: (context, classSnapshot) {
                    final classDocs = (classSnapshot.data?.docs ?? []).cast<QueryDocumentSnapshot<Map<String, dynamic>>>();
                    final String classCount = '${classDocs.length} Kelas';

                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('artworks').where('uid', isEqualTo: id).snapshots(),
                      builder: (context, artworksSnapshot) {
                        final artworkDocs = (artworksSnapshot.data?.docs ?? []).cast<QueryDocumentSnapshot<Map<String, dynamic>>>();
                        
                        // Compute averages and distributions
                        double totalScore = 0;
                        int artworkCount = artworkDocs.length;
                        Map<String, int> gradeCounts = {};
                        for (var aDoc in artworkDocs) {
                          final aData = aDoc.data() as Map<String, dynamic>;
                          final int score = aData['skorAI'] is int ? aData['skorAI'] : 0;
                          totalScore += score;

                          final String gr = aData['grade'] ?? 'C';
                          gradeCounts[gr] = (gradeCounts[gr] ?? 0) + 1;
                        }

                        final String averageScore = artworkCount > 0 
                            ? (totalScore / artworkCount).toStringAsFixed(1)
                            : '0';

                        // Get most common grade
                        String mainGrade = '-';
                        if (gradeCounts.isNotEmpty) {
                          mainGrade = gradeCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Profile Card
                            Container(
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.02),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: DotGridBackgroundPainter(
                                        dotColor: const Color(0xFFE2E8F0).withOpacity(0.4),
                                      ),
                                    ),
                                  ),
                                  
                                  Padding(
                                    padding: const EdgeInsets.all(28),
                                    child: Row(
                                      children: [
                                        Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            Container(
                                              width: 84,
                                              height: 84,
                                              decoration: BoxDecoration(
                                                gradient: const LinearGradient(
                                                  colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                                borderRadius: BorderRadius.circular(22),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: const Color(0xFF2563EB).withOpacity(0.2),
                                                    blurRadius: 12,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                ],
                                              ),
                                              child: avatarUrl != null && avatarUrl.isNotEmpty
                                                  ? ClipRRect(
                                                      borderRadius: BorderRadius.circular(22),
                                                      child: Image.network(
                                                        _getProxiedImageUrl(avatarUrl),
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (context, error, stackTrace) => const Center(
                                                          child: Icon(
                                                            Icons.person_rounded,
                                                            size: 44,
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                        loadingBuilder: (context, child, loadingProgress) {
                                                          if (loadingProgress == null) return child;
                                                          return const Center(
                                                            child: CircularProgressIndicator(
                                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                                                            ),
                                                          );
                                                        },
                                                      ),
                                                    )
                                                  : const Center(
                                                      child: Icon(
                                                        Icons.person_rounded,
                                                        size: 44,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                            ),
                                            Positioned(
                                              bottom: -2,
                                              right: -2,
                                              child: Container(
                                                width: 18,
                                                height: 18,
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  shape: BoxShape.circle,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black.withOpacity(0.1),
                                                      blurRadius: 4,
                                                    ),
                                                  ],
                                                ),
                                                padding: const EdgeInsets.all(2.5),
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color: isSuspended ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(width: 24),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                studentName,
                                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                                      fontWeight: FontWeight.w800,
                                                      color: const Color(0xFF0F172A),
                                                      fontSize: 24,
                                                      letterSpacing: -0.5,
                                                    ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                email,
                                                style: const TextStyle(
                                                  color: Color(0xFF64748B),
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  const Icon(Icons.school_rounded, size: 16, color: Color(0xFF64748B)),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    schoolInfo,
                                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                          color: const Color(0xFF334155),
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 14),
                                              Wrap(
                                                spacing: 12,
                                                runSpacing: 8,
                                                children: [
                                                  _buildInfoChip(context, Icons.calendar_today_rounded, joinDate),
                                                  _buildInfoChip(context, Icons.access_time_rounded, activeTime),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        
                                        OutlinedButton.icon(
                                          onPressed: () => _toggleSuspend(context, id, isSuspended, studentName),
                                          icon: Icon(isSuspended ? Icons.play_arrow_rounded : Icons.block_flipped, size: 16),
                                          label: Text(isSuspended ? 'Aktifkan Akun' : 'Suspend Akun', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: isSuspended ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                            side: BorderSide(color: isSuspended ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2), width: 1.5),
                                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                            backgroundColor: isSuspended ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.04, end: 0, curve: Curves.easeOutQuad),
                            const SizedBox(height: 28),

                            // Stats Cards Row
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStatCard(
                                    context,
                                    'Total Poin',
                                    points.toString(),
                                    Icons.stars_rounded,
                                    AdminColors.primary,
                                    trendText: 'Aktif',
                                    trendPositive: true,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildStatCard(
                                    context,
                                    'Rata-rata Nilai',
                                    averageScore,
                                    Icons.analytics_rounded,
                                    const Color(0xFF10B981),
                                    trendText: '$artworkCount karya',
                                    trendPositive: true,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildStatCard(
                                    context,
                                    'Grade Terbanyak',
                                    mainGrade,
                                    Icons.military_tech_rounded,
                                    const Color(0xFF38BDF8),
                                    trendText: 'Dominan',
                                    trendPositive: true,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildStatCard(
                                    context,
                                    'Kelas Diikuti',
                                    classCount,
                                    Icons.school_rounded,
                                    const Color(0xFFF59E0B),
                                    trendText: 'Terdaftar',
                                    trendPositive: true,
                                  ),
                                ),
                              ],
                            ).animate().fadeIn(delay: 100.ms, duration: 400.ms).slideY(begin: 0.04, end: 0, curve: Curves.easeOutQuad),
                            const SizedBox(height: 40),

                            // Gallery Section Title
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Karya Murid ($artworkCount)',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF0F172A),
                                        letterSpacing: -0.5,
                                      ),
                                ),
                              ],
                            ).animate().fadeIn(delay: 200.ms, duration: 400.ms).slideY(begin: 0.04, end: 0, curve: Curves.easeOutQuad),
                            const SizedBox(height: 20),
                            
                            artworkDocs.isEmpty
                                ? Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 40),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'Belum ada karya seni yang dibuat',
                                        style: TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ).animate().fadeIn(delay: 300.ms, duration: 400.ms).slideY(begin: 0.04, end: 0, curve: Curves.easeOutQuad)
                                : GridView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: 220,
                                      mainAxisSpacing: 16,
                                      crossAxisSpacing: 16,
                                      childAspectRatio: 0.8,
                                    ),
                                    itemCount: artworkDocs.length,
                                    itemBuilder: (context, index) {
                                       final aDoc = artworkDocs[index];
                                       final aData = aDoc.data() as Map<String, dynamic>;
                                       final String kategori = aData['kategori'] ?? 'Karya';
                                       final String grade = aData['grade'] ?? 'C';
                                       final int score = aData['skorAI'] is int ? aData['skorAI'] : 0;
                                       final String imageUrl = aData['imageUrl'] ?? '';

                                       Color gradeColor = const Color(0xFFEF4444);
                                       if (grade == 'S') gradeColor = const Color(0xFFD946EF);
                                       if (grade == 'A') gradeColor = const Color(0xFF10B981);
                                       if (grade == 'B') gradeColor = const Color(0xFF3B82F6);

                                       return InkWell(
                                         onTap: () => _showArtworkPreview(context, aData),
                                         child: _HoverableArtworkCard(
                                           title: kategori.toUpperCase(),
                                           grade: grade,
                                           gradeColor: gradeColor,
                                           score: score,
                                           imageUrl: imageUrl,
                                         ),
                                       );
                                    },
                                  ).animate().fadeIn(delay: 300.ms, duration: 400.ms).slideY(begin: 0.04, end: 0, curve: Curves.easeOutQuad),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showArtworkPreview(BuildContext context, Map<String, dynamic> artwork) {
    showDialog(
      context: context,
      builder: (context) {
        final String kategori = artwork['kategori'] ?? 'Karya';
        final int skor = artwork['skorAI'] is int ? artwork['skorAI'] : 0;
        final String grade = artwork['grade'] ?? '-';
        final String rawFeedback = (artwork['feedback'] as String?)?.trim() ?? '';
        final String rawFeedbackAI = (artwork['feedbackAI'] as String?)?.trim() ?? '';
        final String feedback = rawFeedback.isNotEmpty
            ? rawFeedback
            : (rawFeedbackAI.isNotEmpty ? rawFeedbackAI : 'Tidak ada feedback AI.');
        final String imageUrl = artwork['imageUrl'] ?? '';
        final dynamic createdVal = artwork['createdAt'];
        String dateStr = '-';
        if (createdVal is Timestamp) {
          final dt = createdVal.toDate();
          dateStr = '${dt.day}/${dt.month}/${dt.year}';
        }

        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 500,
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFF334155), width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 250,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                    color: Color(0xFF0F172A),
                  ),
                  child: imageUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                          child: Image.network(
                            _getProxiedImageUrl(imageUrl),
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => const Center(
                              child: Icon(Icons.broken_image_rounded, size: 50, color: Colors.white24),
                            ),
                          ),
                        )
                      : Center(
                          child: CustomPaint(
                            size: const Size(200, 200),
                            painter: GenerativeArtPainter(grade: grade),
                          ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            kategori.toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AdminColors.primary.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AdminColors.primary.withOpacity(0.3)),
                            ),
                            child: Text(
                              'Grade $grade',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'Skor AI: $skor',
                            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const Spacer(),
                          Text(
                            dateStr,
                            style: const TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Analisis & Feedback Gemini AI:',
                        style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: Text(
                            feedback,
                            style: const TextStyle(color: Colors.white70, height: 1.4, fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AdminColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Tutup'),
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

  void _toggleSuspend(BuildContext context, String uid, bool isCurrentlySuspended, String name) async {
    final action = isCurrentlySuspended ? 'mengaktifkan kembali' : 'menangguhkan (suspend)';
    final confirmBtn = isCurrentlySuspended ? 'Aktifkan' : 'Suspend';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(isCurrentlySuspended ? 'Aktifkan Akun' : 'Konfirmasi Suspend'),
          content: Text('Apakah Anda yakin ingin $action akun murid "$name"?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Batal'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isCurrentlySuspended ? AdminColors.success : AdminColors.danger,
              ),
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await FirebaseFirestore.instance.collection('users').doc(uid).update({
                    'status': isCurrentlySuspended ? 'active' : 'suspended',
                    'isActive': isCurrentlySuspended ? true : false,
                  });

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Akun "$name" berhasil ${isCurrentlySuspended ? "diaktifkan" : "ditangguhkan"}.'),
                        backgroundColor: AdminColors.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Gagal mengubah status akun: $e'), backgroundColor: AdminColors.danger),
                    );
                  }
                }
              },
              child: Text(confirmBtn, style: const TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoChip(BuildContext context, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF475569),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color, {
    required String trendText,
    required bool trendPositive,
  }) {
    final Color iconBgColor = color.withOpacity(0.08);
    final Color curveColor = color.withOpacity(0.035);

    return Container(
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
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: CurvedBackgroundPainter(lineColor: curveColor),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: iconBgColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (trendPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          trendText,
                          style: TextStyle(
                            color: trendPositive ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.bold,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HoverableArtworkCard extends StatefulWidget {
  final String title;
  final String grade;
  final Color gradeColor;
  final int score;
  final String imageUrl;

  const _HoverableArtworkCard({
    required this.title,
    required this.grade,
    required this.gradeColor,
    required this.score,
    required this.imageUrl,
  });

  @override
  State<_HoverableArtworkCard> createState() => _HoverableArtworkCardState();
}

class _HoverableArtworkCardState extends State<_HoverableArtworkCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedScale(
        scale: _isHovered ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isHovered ? widget.gradeColor.withOpacity(0.4) : const Color(0xFFE2E8F0),
              width: _isHovered ? 1.5 : 1.2,
            ),
            boxShadow: [
              _isHovered
                  ? BoxShadow(
                      color: widget.gradeColor.withOpacity(0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    )
                  : BoxShadow(
                      color: Colors.black.withOpacity(0.015),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: widget.imageUrl.isNotEmpty
                          ? ClipRRect(
                              child: Image.network(
                                _getProxiedImageUrl(widget.imageUrl),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => CustomPaint(
                                  painter: GenerativeArtPainter(grade: widget.grade),
                                ),
                              ),
                            )
                          : CustomPaint(
                              painter: GenerativeArtPainter(grade: widget.grade),
                            ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Text(
                          'Grade ${widget.grade}',
                          style: TextStyle(
                            color: widget.gradeColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                    if (_isHovered)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withOpacity(0.2),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.visibility_rounded, size: 14, color: widget.gradeColor),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Detail',
                                    style: TextStyle(
                                      color: widget.gradeColor,
                                      fontWeight: FontWeight.bold,
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
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.smart_toy_rounded, size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        Text(
                          'Skor AI: ${widget.score}',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
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
    );
  }
}

class DotGridBackgroundPainter extends CustomPainter {
  final Color dotColor;
  DotGridBackgroundPainter({required this.dotColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = dotColor;
    const double spacing = 16.0;
    for (double x = 8.0; x < size.width; x += spacing) {
      for (double y = 8.0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant DotGridBackgroundPainter oldDelegate) => false;
}

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
      orbColors = [const Color(0xFF3B82F6), const Color(0xFF6366F1), const Color(0xFF8B5CF6).withOpacity(0)];
      orbitColor = const Color(0xFF818CF8);
    } else {
      orbColors = [const Color(0xFFF59E0B), const Color(0xFFEF4444), const Color(0xFFEC4899).withOpacity(0)];
      orbitColor = const Color(0xFFFBBF24);
    }

    final ambientPaint = Paint()
      ..shader = RadialGradient(
        colors: [orbColors[0].withOpacity(0.4), orbColors[1].withOpacity(0.0)],
        radius: 0.8,
      ).createShader(Rect.fromCircle(center: center, radius: radius * 2.0));
    canvas.drawCircle(center, radius * 1.8, ambientPaint);

    final orbitPaint = Paint()
      ..color = orbitColor.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.4);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: radius * 2.8, height: radius * 0.6),
      orbitPaint,
    );
    canvas.restore();

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(0.3);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: radius * 2.4, height: radius * 0.5),
      orbitPaint..color = Colors.white.withOpacity(0.7)..strokeWidth = 1.0,
    );
    canvas.restore();

    final orbPaint = Paint()
      ..shader = RadialGradient(
        colors: orbColors,
        radius: 1.0,
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, orbPaint);

    final specularPaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white.withOpacity(0.55), Colors.white.withOpacity(0.0)],
        radius: 0.8,
      ).createShader(Rect.fromCircle(center: Offset(center.dx - radius * 0.35, center.dy - radius * 0.35), radius: radius * 0.7));
    canvas.drawCircle(Offset(center.dx - radius * 0.35, center.dy - radius * 0.35), radius * 0.6, specularPaint);

    final starPaint = Paint()..color = Colors.white.withOpacity(0.8);
    canvas.drawCircle(Offset(center.dx + radius * 0.9, center.dy - radius * 0.8), 2.0, starPaint);
    canvas.drawCircle(Offset(center.dx - radius * 1.0, center.dy + radius * 0.7), 1.5, starPaint);
    canvas.drawCircle(Offset(center.dx + radius * 0.5, center.dy + radius * 1.1), 2.2, starPaint);
  }

  @override
  bool shouldRepaint(covariant GenerativeArtPainter oldDelegate) => oldDelegate.grade != grade;
}

class CurvedBackgroundPainter extends CustomPainter {
  final Color lineColor;
  CurvedBackgroundPainter({required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final path1 = Path()
      ..moveTo(size.width * 0.3, size.height)
      ..quadraticBezierTo(
        size.width * 0.6,
        size.height * 0.1,
        size.width * 1.1,
        size.height * 0.4,
      );

    final path2 = Path()
      ..moveTo(size.width * 0.4, size.height)
      ..quadraticBezierTo(
        size.width * 0.7,
        size.height * 0.2,
        size.width * 1.2,
        size.height * 0.5,
      );

    canvas.drawPath(path1, paint);
    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(covariant CurvedBackgroundPainter oldDelegate) =>
      oldDelegate.lineColor != lineColor;
}
