import 'package:epic_admin/core/theme/admin_colors.dart';
import 'package:epic_admin/features/dashboard/widgets/activity_chart.dart';
import 'package:epic_admin/features/dashboard/widgets/grade_distribution_chart.dart';
import 'package:epic_admin/features/dashboard/widgets/popular_games_chart.dart';
import 'package:epic_admin/features/dashboard/widgets/stat_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Key _refreshKey = UniqueKey();

  void _handleRefresh() {
    setState(() {
      _refreshKey = UniqueKey();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Text('Data dasbor berhasil diperbarui!'),
          ],
        ),
        backgroundColor: AdminColors.success,
        behavior: SnackBarBehavior.floating,
        width: 320,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: _refreshKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ringkasan Dasbor',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Selamat datang kembali, Administrator! Berikut adalah ringkasan hari ini.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AdminColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AdminColors.outlineVariant.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: AdminColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          '${DateTime.now().day} ${_getMonthName(DateTime.now().month)} ${DateTime.now().year}',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: AdminColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.refresh, color: AdminColors.primary),
                      onPressed: _handleRefresh,
                      tooltip: 'Refresh Data',
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          // Statistik Grid (3 Columns on Desktop, 2 on Tablet, 1 on Mobile)
          LayoutBuilder(
            builder: (context, constraints) {
              int crossAxisCount = 3;
              if (constraints.maxWidth < 650) {
                crossAxisCount = 1;
              } else if (constraints.maxWidth < 1100) {
                crossAxisCount = 2;
              }

              return GridView.count(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 24,
                mainAxisSpacing: 24,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 2.3,
                children: [
                  _buildStatCardStream(
                    title: 'Murid Terdaftar',
                    query: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'murid'),
                    subtitle: 'Siswa aktif belajar',
                    icon: Icons.school_rounded,
                    color: Colors.blue,
                  ),
                  _buildStatCardStream(
                    title: 'Guru Aktif',
                    query: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'guru').where('guruStatus', isEqualTo: 'approved'),
                    subtitle: 'Pengelola kelas',
                    icon: Icons.person_rounded,
                    color: Colors.green,
                  ),
                  _buildStatCardStream(
                    title: 'Guru Pending',
                    query: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'guru').where('guruStatus', isEqualTo: 'pending'),
                    subtitle: 'Butuh verifikasi segera',
                    icon: Icons.warning_amber_rounded,
                    color: Colors.red,
                  ),
                  _buildStatCardStream(
                    title: 'Total Karya',
                    query: FirebaseFirestore.instance.collection('artworks'),
                    subtitle: 'Telah digambar',
                    icon: Icons.brush_rounded,
                    color: Colors.purple,
                  ),
                  _buildStatCardStream(
                    title: 'Pending Re-Score',
                    query: FirebaseFirestore.instance.collection('artworks').where('pendingRescore', isEqualTo: true),
                    subtitle: 'Menunggu proses AI',
                    icon: Icons.smart_toy_rounded,
                    color: Colors.orange,
                  ),
                  _buildStatCardStream(
                    title: 'Kelas Aktif',
                    query: FirebaseFirestore.instance.collection('kelas').where('status', isEqualTo: 'aktif'),
                    subtitle: 'Di seluruh sekolah',
                    icon: Icons.meeting_room_rounded,
                    color: Colors.teal,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 32),
          
          // Responsive Rows for Charts and Tables
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 1024;
              
              if (isDesktop) {
                return Column(
                  children: [
                    // Middle Row: GradeDistributionChart (Left) + ActivityChart (Right)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Expanded(
                          flex: 1,
                          child: GradeDistributionChart(),
                        ),
                        SizedBox(width: 24),
                        Expanded(
                          flex: 2,
                          child: ActivityChart(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    // Bottom Row: Aktivitas Terbaru (Left) + PopularGamesChart (Right)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: _buildAktivitasTerbaru(context),
                        ),
                        const SizedBox(width: 24),
                        const Expanded(
                          flex: 1,
                          child: PopularGamesChart(),
                        ),
                      ],
                    ),
                  ],
                );
              } else {
                // Mobile/Tablet Vertical Stack
                return Column(
                  children: [
                    const GradeDistributionChart(),
                    const SizedBox(height: 24),
                    const ActivityChart(),
                    const SizedBox(height: 24),
                    _buildAktivitasTerbaru(context),
                    const SizedBox(height: 24),
                    const PopularGamesChart(),
                  ],
                );
              }
            },
          ).animate().fadeIn(duration: 700.ms).slideY(begin: 0.05, end: 0, curve: Curves.easeOutQuad),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    if (month >= 1 && month <= 12) {
      return months[month - 1];
    }
    return '';
  }

  Widget _buildStatCardStream({
    required String title,
    required Query query,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        String value = '...';
        if (snapshot.hasError) {
          value = 'Error';
        } else if (snapshot.hasData) {
          value = snapshot.data!.docs.length.toString();
        }
        return StatCard(
          title: title,
          value: value,
          subtitle: subtitle,
          icon: icon,
          color: color,
        );
      },
    );
  }

  // Beautiful Tabular "Aktivitas Terbaru" (styled after the reference's "Last Trips")
  Widget _buildAktivitasTerbaru(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('artworks')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Container(
            height: 420,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AdminColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AdminColors.outlineVariant.withOpacity(0.2)),
            ),
            child: const Center(
              child: Text(
                'Gagal memuat aktivitas terbaru',
                style: TextStyle(color: AdminColors.danger),
              ),
            ),
          );
        }

        final docs = snapshot.hasData ? snapshot.data!.docs : [];

        return Container(
          height: 420,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AdminColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AdminColors.outlineVariant.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.01),
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Aktivitas Terbaru',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AdminColors.textPrimary,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Daftar karya seni siswa yang baru disubmit',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AdminColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Table Headers
              Row(
                children: const [
                  Expanded(
                    flex: 3,
                    child: Text(
                      'PENGGUNA',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AdminColors.textSecondary, fontSize: 11, letterSpacing: 0.8),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'AKTIVITAS / JUDUL KARYA',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AdminColors.textSecondary, fontSize: 11, letterSpacing: 0.8),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'KATEGORI',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AdminColors.textSecondary, fontSize: 11, letterSpacing: 0.8),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'SKOR AI',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AdminColors.textSecondary, fontSize: 11, letterSpacing: 0.8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: Color(0xFFF1F5F9)),
              const SizedBox(height: 8),
              // Table Body List
              Expanded(
                child: docs.isEmpty
                    ? const Center(
                        child: Text(
                          'Belum ada karya terbaru',
                          style: TextStyle(color: AdminColors.textSecondary, fontSize: 13),
                        ),
                      )
                    : ListView.separated(
                        itemCount: docs.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final artDoc = docs[index];
                          final data = artDoc.data() as Map<String, dynamic>;
                          final String uid = data['uid'] ?? '';
                          final String judulKarya = data['judulKarya'] ?? 'Tanpa Judul';
                          final String kategori = data['kategori'] ?? '-';
                          final int? skorAI = data['skorAI'] is int ? data['skorAI'] : null;
                          final String grade = data['grade'] ?? '-';
                          final timestamp = data['createdAt'];
                          DateTime createdAt = DateTime.now();
                          if (timestamp is Timestamp) {
                            createdAt = timestamp.toDate();
                          }

                          Color roleColor = AdminColors.primary;
                          if (kategori.toLowerCase() == 'batik') roleColor = const Color(0xFF2563EB);
                          if (kategori.toLowerCase() == 'keris') roleColor = const Color(0xFF64748B);
                          if (kategori.toLowerCase() == 'anyaman') roleColor = const Color(0xFFF59E0B);

                          return FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
                            builder: (context, userSnapshot) {
                              String studentName = 'Loading...';
                              String studentEmail = '...';
                              if (userSnapshot.hasData && userSnapshot.data!.exists) {
                                final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                                studentName = userData['namaLengkap'] ?? 'Siswa';
                                studentEmail = userData['email'] ?? '';
                              } else if (userSnapshot.hasError) {
                                studentName = 'Error';
                              }

                              final String avatarText = studentName.isNotEmpty ? studentName[0].toUpperCase() : 'S';

                              return Row(
                                children: [
                                  // Member Avatar & Details
                                  Expanded(
                                    flex: 3,
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor: roleColor.withOpacity(0.1),
                                          child: Text(
                                            avatarText,
                                            style: TextStyle(
                                              color: roleColor,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                studentName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  color: AdminColors.textPrimary,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                studentEmail,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AdminColors.textSecondary,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Action
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      'Menggambar "$judulKarya"',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: AdminColors.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  // Kategori Pill Badge
                                  Expanded(
                                    flex: 2,
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: roleColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            kategori.toUpperCase(),
                                            style: TextStyle(
                                              color: roleColor,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Score / Time
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          skorAI != null ? '$skorAI ($grade)' : 'Pending',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: skorAI != null ? AdminColors.success : AdminColors.inactive,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _formatTimeAgo(createdAt),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AdminColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
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

  String _formatTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays > 7) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} hari lalu';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} jam lalu';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} menit lalu';
    } else {
      return 'Baru saja';
    }
  }
}
