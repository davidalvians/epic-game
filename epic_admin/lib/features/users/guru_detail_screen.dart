import 'package:epic_admin/core/theme/admin_colors.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

bool _isImageFile(String url, String fileName) {
  if (url.isEmpty) return false;
  final cleanUrl = url.split('?').first.toLowerCase();
  return cleanUrl.endsWith('.png') ||
      cleanUrl.endsWith('.jpg') ||
      cleanUrl.endsWith('.jpeg') ||
      cleanUrl.endsWith('.webp') ||
      fileName.toLowerCase().endsWith('.png') ||
      fileName.toLowerCase().endsWith('.jpg') ||
      fileName.toLowerCase().endsWith('.jpeg') ||
      fileName.toLowerCase().endsWith('.webp');
}

String _getProxiedImageUrl(String url) {
  if (url.isEmpty) return '';
  if (url.contains('firebasestorage.googleapis.com') || url.contains('googleusercontent.com')) {
    return 'https://images.weserv.nl/?url=${Uri.encodeComponent(url)}';
  }
  return url;
}

String _getFileName(String url, String fallback) {
  if (url.isEmpty) return '';
  try {
    final decoded = Uri.decodeFull(url);
    final uri = Uri.parse(decoded);
    String path = uri.path;
    if (path.contains('/o/')) {
      path = path.split('/o/').last;
    }
    final filename = path.split('/').last;
    if (filename.isNotEmpty) {
      return filename;
    }
  } catch (e) {
    debugPrint('Error parsing filename from URL: $e');
  }
  return fallback;
}

class GuruDetailScreen extends StatelessWidget {
  final String id;
  const GuruDetailScreen({super.key, required this.id});

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
                  const Text('Data guru tidak ditemukan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('guru_verifikasi')
              .where('uid', isEqualTo: id)
              .snapshots(),
          builder: (context, verifSnapshot) {
            final verifDocs = (verifSnapshot.data?.docs ?? [])
                .cast<QueryDocumentSnapshot<Map<String, dynamic>>>()
                .toList();

            if (verifDocs.isNotEmpty) {
              verifDocs.sort((a, b) {
                final aTime = a.data()['createdAt'] as Timestamp?;
                final bTime = b.data()['createdAt'] as Timestamp?;
                if (aTime == null && bTime == null) return 0;
                if (aTime == null) return 1;
                if (bTime == null) return -1;
                return bTime.compareTo(aTime);
              });
            }

            final hasVerif = verifDocs.isNotEmpty;
            Map<String, dynamic> verifData = {};
            String verifDocId = '';
            if (hasVerif) {
              verifDocId = verifDocs.first.id;
              verifData = verifDocs.first.data();
            }

            final String teacherName = userData['namaLengkap'] ?? userData['nama'] ?? verifData['namaGuru'] ?? 'Tanpa Nama';
            final String email = userData['email'] ?? verifData['email'] ?? '-';
            final String school = userData['sekolah'] ?? verifData['sekolah'] ?? 'Belum diisi';
            final String guruStatus = userData['guruStatus'] ?? verifData['status'] ?? 'pending';
            final String userStatus = userData['status'] ?? 'active';
            final String? avatarUrl = userData['avatarUrl'] as String?;
            final bool isPending = guruStatus == 'pending';
            final bool isSuspended = userStatus == 'suspended';

        final dynamic verifiedAtVal = userData['verifiedAt'];
        final dynamic lastActiveVal = userData['lastActiveAt'] ?? userData['nyawaLastReset'];

        String verifiedInfo = 'Terverifikasi: -';
        if (verifiedAtVal is Timestamp) {
          final dt = verifiedAtVal.toDate();
          verifiedInfo = 'Terverifikasi: ${dt.day}/${dt.month}/${dt.year}';
        } else if (guruStatus == 'approved') {
          verifiedInfo = 'Terverifikasi: Aktif';
        }

        String activeTime = 'Aktif: -';
        if (lastActiveVal is Timestamp) {
          final dt = lastActiveVal.toDate();
          activeTime = 'Aktif: ${dt.day}/${dt.month}/${dt.year}';
        }

        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth < 768;

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
              'Detail Guru',
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
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 32, vertical: isMobile ? 16 : 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Card with Dot Grid Background
                    Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(isMobile ? 18 : 24),
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
                          // Dot Grid Background Accent
                          Positioned.fill(
                            child: CustomPaint(
                              painter: DotGridBackgroundPainter(
                                dotColor: const Color(0xFFE2E8F0).withOpacity(0.4),
                              ),
                            ),
                          ),
                          
                          Padding(
                            padding: EdgeInsets.all(isMobile ? 16 : 28),
                            child: isMobile
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 64,
                                            height: 64,
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              borderRadius: BorderRadius.circular(18),
                                            ),
                                            child: avatarUrl != null && avatarUrl.isNotEmpty
                                                ? ClipRRect(
                                                    borderRadius: BorderRadius.circular(18),
                                                    child: Image.network(
                                                      _getProxiedImageUrl(avatarUrl),
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (context, error, stackTrace) => const Center(
                                                        child: Icon(Icons.person_rounded, size: 32, color: Colors.white),
                                                      ),
                                                    ),
                                                  )
                                                : const Center(child: Icon(Icons.person_rounded, size: 32, color: Colors.white)),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  teacherName,
                                                  style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A), fontSize: 18),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: (isPending ? const Color(0xFFF59E0B) : const Color(0xFF10B981)).withOpacity(0.08),
                                                    borderRadius: BorderRadius.circular(12),
                                                    border: Border.all(
                                                      color: (isPending ? const Color(0xFFF59E0B) : const Color(0xFF10B981)).withOpacity(0.2),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Container(
                                                        width: 5,
                                                        height: 5,
                                                        decoration: BoxDecoration(
                                                          color: isPending ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                                                          shape: BoxShape.circle,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 5),
                                                      Text(
                                                        isPending ? 'Pending' : 'Approved',
                                                        style: TextStyle(
                                                          color: isPending ? const Color(0xFFB45309) : const Color(0xFF047857),
                                                          fontSize: 10.5,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  email,
                                                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          const Icon(Icons.school_rounded, size: 14, color: Color(0xFF64748B)),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              school,
                                              style: const TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.w600, fontSize: 12),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: [
                                          _buildInfoChip(context, Icons.verified_user_rounded, verifiedInfo),
                                          _buildInfoChip(context, Icons.access_time_rounded, activeTime),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          onPressed: () => _toggleSuspend(context, id, isSuspended, teacherName),
                                          icon: Icon(isSuspended ? Icons.play_arrow_rounded : Icons.block_flipped, size: 15),
                                          label: Text(isSuspended ? 'Aktifkan Akun' : 'Suspend Akun', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: isSuspended ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                            side: BorderSide(color: isSuspended ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2), width: 1.5),
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            backgroundColor: isSuspended ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : Row(
                                    children: [
                                      // Gradient Avatar with glowing ring and status dot
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
                                            Wrap(
                                              crossAxisAlignment: WrapCrossAlignment.center,
                                              spacing: 12,
                                              runSpacing: 8,
                                              children: [
                                                Text(
                                                  teacherName,
                                                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                                        fontWeight: FontWeight.w800,
                                                        color: const Color(0xFF0F172A),
                                                        fontSize: 24,
                                                        letterSpacing: -0.5,
                                                      ),
                                                ),
                                                
                                                // Status Badge with Soft Glow Drop Shadow
                                                GestureDetector(
                                                   onTap: (isPending && verifDocId.isNotEmpty)
                                                       ? () => context.go('/verifikasi/$verifDocId')
                                                       : null,
                                                   child: MouseRegion(
                                                     cursor: (isPending && verifDocId.isNotEmpty)
                                                         ? SystemMouseCursors.click
                                                         : SystemMouseCursors.basic,
                                                     child: Container(
                                                       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                       decoration: BoxDecoration(
                                                         color: (isPending ? const Color(0xFFF59E0B) : const Color(0xFF10B981)).withOpacity(0.08),
                                                         borderRadius: BorderRadius.circular(20),
                                                         border: Border.all(
                                                           color: (isPending ? const Color(0xFFF59E0B) : const Color(0xFF10B981)).withOpacity(0.2),
                                                         ),
                                                         boxShadow: [
                                                           BoxShadow(
                                                             color: (isPending ? const Color(0xFFF59E0B) : const Color(0xFF10B981)).withOpacity(0.04),
                                                             blurRadius: 6,
                                                             offset: const Offset(0, 2),
                                                           ),
                                                         ],
                                                       ),
                                                       child: Row(
                                                         mainAxisSize: MainAxisSize.min,
                                                         children: [
                                                           Container(
                                                             width: 6,
                                                             height: 6,
                                                             decoration: BoxDecoration(
                                                               color: isPending ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                                                               shape: BoxShape.circle,
                                                             ),
                                                           ),
                                                           const SizedBox(width: 6),
                                                           Text(
                                                             isPending ? 'Pending' : 'Approved',
                                                             style: TextStyle(
                                                               color: isPending ? const Color(0xFFB45309) : const Color(0xFF047857),
                                                               fontSize: 11,
                                                               fontWeight: FontWeight.bold,
                                                             ),
                                                           ),
                                                         ],
                                                       ),
                                                     ),
                                                   ),
                                                 ),
                                              ],
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
                                                  school,
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
                                                _buildInfoChip(context, Icons.verified_user_rounded, verifiedInfo),
                                                _buildInfoChip(context, Icons.access_time_rounded, activeTime),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      
                                      OutlinedButton.icon(
                                        onPressed: () => _toggleSuspend(context, id, isSuspended, teacherName),
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
                    SizedBox(height: isMobile ? 16 : 32),

                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('kelas')
                          .where('guruUid', isEqualTo: id)
                          .snapshots(),
                      builder: (context, classSnapshot) {
                        final classDocs = (classSnapshot.data?.docs ?? []).cast<QueryDocumentSnapshot<Map<String, dynamic>>>();
                        final int classCount = classDocs.length;
                        int totalStudents = 0;
                        for (var cDoc in classDocs) {
                          final cData = cDoc.data();
                            final List<dynamic> muridIds = cData['muridIds'] is List ? cData['muridIds'] : [];
                          totalStudents += muridIds.length;
                        }

                        final String fileUrl = verifData['buktiUrl'] ?? verifData['fileUrl'] ?? '';
                        final String fileName = verifData['fileName'] ?? _getFileName(fileUrl, 'bukti_mengajar.pdf');
                        final dynamic uploadDateVal = verifData['createdAt'];
                        String uploadDate = 'Diunggah pada: -';
                        if (uploadDateVal is Timestamp) {
                          final dt = uploadDateVal.toDate();
                          uploadDate = 'Diunggah pada: ${dt.day}/${dt.month}/${dt.year}';
                        }

                        final mainContent = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStatCard(
                                    context,
                                    'Kelas Aktif',
                                    classCount.toString(),
                                    Icons.school_rounded,
                                    AdminColors.primary,
                                    trendText: isPending ? 'Belum terverifikasi' : 'Aktif',
                                  ),
                                ),
                                SizedBox(width: isMobile ? 12 : 16),
                                Expanded(
                                  child: _buildStatCard(
                                    context,
                                    'Total Murid',
                                    totalStudents.toString(),
                                    Icons.group_rounded,
                                    const Color(0xFF10B981),
                                    trendText: isPending ? '0 terdaftar' : 'Aktif',
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: isMobile ? 24 : 36),
                            
                            Text(
                              'Kelas Yang Dimiliki',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0F172A),
                                    letterSpacing: -0.5,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            classDocs.isEmpty
                                ? Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 32),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'Belum ada kelas yang dibuat',
                                        style: TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: classDocs.length,
                                    itemBuilder: (context, index) {
                                      final classDoc = classDocs[index];
                                      final classData = classDoc.data();
                                      final String className = classData['namaKelas'] ?? 'Tanpa Nama';
                                      final List<dynamic> muridIds = classData['muridIds'] is List ? classData['muridIds'] : [];
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: _HoverableClassCard(
                                          className: className,
                                          students: '${muridIds.length} Murid',
                                          isActive: (classData['status'] ?? 'aktif') == 'aktif',
                                          classId: classDoc.id,
                                        ),
                                      );
                                    },
                                  ),
                          ],
                        );

                        final rightContent = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dokumen Verifikasi',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0F172A),
                                    letterSpacing: -0.5,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            _buildDocumentPreviewCard(context, fileName, uploadDate, fileUrl, isPending, verifDocId),
                          ],
                        );

                        if (isMobile) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              mainContent,
                              const SizedBox(height: 28),
                              rightContent,
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 2, child: mainContent),
                            const SizedBox(width: 24),
                            Expanded(flex: 1, child: rightContent),
                          ],
                        );
                      },
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

  Widget _buildDocumentPreviewCard(
    BuildContext context,
    String fileName,
    String uploadDate,
    String fileUrl,
    bool isPending,
    String verifDocId,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF334155), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: _isImageFile(fileUrl, fileName)
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      _getProxiedImageUrl(fileUrl),
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Center(
                        child: Icon(Icons.broken_image_rounded, size: 40, color: Colors.grey),
                      ),
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFEF4444), size: 44),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            fileName,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 13),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          Text(
            fileName,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(uploadDate, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: fileUrl.isNotEmpty ? () => _openDocument(context, fileUrl) : null,
              icon: const Icon(Icons.open_in_new_rounded, size: 15),
              label: const Text('Buka Dokumen', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
          if (isPending && verifDocId.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.go('/verifikasi/$verifDocId'),
                icon: const Icon(Icons.assignment_turned_in_rounded, size: 15),
                label: const Text('Detail Verifikasi Pending', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFF59E0B),
                  side: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: const Color(0xFFF59E0B).withOpacity(0.08),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openDocument(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      try {
        await launchUrl(uri);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal membuka dokumen: $e'), backgroundColor: AdminColors.danger),
          );
        }
      }
    }
  }

  void _approveTeacherVerif(BuildContext context, String uid, String verifDocId, String name) async {
    try {
      final batch = FirebaseFirestore.instance.batch();

      // Update user doc
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
      batch.update(userRef, {
        'guruStatus': 'approved',
        'role': 'guru',
        'verifiedAt': FieldValue.serverTimestamp(),
        'verifiedBy': 'Epic Admin',
      });

      // Update verifikasi doc if it exists
      if (verifDocId.isNotEmpty) {
        final verifRef = FirebaseFirestore.instance.collection('guru_verifikasi').doc(verifDocId);
        batch.update(verifRef, {
          'status': 'approved',
          'processedAt': FieldValue.serverTimestamp(),
          'catatanAdmin': 'Disetujui dari detail profil.',
        });
      }

      await batch.commit();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Akun Guru "$name" berhasil disetujui.'), backgroundColor: AdminColors.success),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyetujui verifikasi: $e'), backgroundColor: AdminColors.danger),
        );
      }
    }
  }

  void _toggleSuspend(BuildContext context, String uid, bool isCurrentlySuspended, String name) async {
    final action = isCurrentlySuspended ? 'mengaktifkan kembali' : 'menangguhkan (suspend)';
    final confirmBtn = isCurrentlySuspended ? 'Aktifkan' : 'Suspend';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(isCurrentlySuspended ? 'Aktifkan Akun' : 'Konfirmasi Suspend'),
          content: Text('Apakah Anda yakin ingin $action akun guru "$name"?'),
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
                          color: color.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          trendText,
                          style: TextStyle(
                            color: color,
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

class _HoverableClassCard extends StatefulWidget {
  final String className;
  final String students;
  final bool isActive;
  final String classId;

  const _HoverableClassCard({
    required this.className,
    required this.students,
    required this.isActive,
    required this.classId,
  });

  @override
  State<_HoverableClassCard> createState() => _HoverableClassCardState();
}

class _HoverableClassCardState extends State<_HoverableClassCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedScale(
        scale: _isHovered ? 1.008 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isHovered ? AdminColors.primary.withOpacity(0.3) : const Color(0xFFE2E8F0),
              width: _isHovered ? 1.5 : 1.2,
            ),
            boxShadow: [
              _isHovered
                  ? BoxShadow(
                      color: AdminColors.primary.withOpacity(0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    )
                  : BoxShadow(
                      color: Colors.black.withOpacity(0.005),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.school_rounded, color: AdminColors.primary, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.className,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.students,
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
                  color: (widget.isActive ? const Color(0xFF10B981) : const Color(0xFF64748B)).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  widget.isActive ? 'Aktif' : 'Nonaktif',
                  style: TextStyle(
                    color: widget.isActive ? const Color(0xFF047857) : const Color(0xFF475569),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () => context.go('/kelas/${widget.classId}'),
                icon: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
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
