import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:epic_admin/core/theme/admin_colors.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

class VerifikasiListScreen extends StatefulWidget {
  const VerifikasiListScreen({super.key});

  @override
  State<VerifikasiListScreen> createState() => _VerifikasiListScreenState();
}

class _VerifikasiListScreenState extends State<VerifikasiListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedIds.clear();
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('guru_verifikasi').snapshots(),
      builder: (context, overallSnapshot) {
        final verifDocs = overallSnapshot.data?.docs ?? [];

        // Count documents locally based on status
        int pendingCount = 0;
        int approvedCount = 0;
        int rejectedCount = 0;

        for (var doc in verifDocs) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status'] ?? 'pending';
          if (status == 'approved') {
            approvedCount++;
          } else if (status == 'rejected') {
            rejectedCount++;
          } else {
            pendingCount++;
          }
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Background glows
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
                      const Color(0xFF2563EB).withOpacity(0.05),
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

            Positioned.fill(
              child: SizedBox.expand(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Manual Header Row
                    if (isMobile)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('Dashboard', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: const Color(0xFF64748B))),
                              const Icon(Icons.chevron_right, size: 14, color: Color(0xFF64748B)),
                              Text('Verifikasi Guru', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AdminColors.primary, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Verifikasi Guru',
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF0F172A),
                                      letterSpacing: -0.5,
                                    ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.2)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.pending_actions_rounded, color: Color(0xFFD97706), size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$pendingCount Menunggu',
                                      style: const TextStyle(
                                        color: Color(0xFFB45309),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.04, end: 0, curve: Curves.easeOutQuad)
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text('Dashboard', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: const Color(0xFF64748B))),
                                  const Icon(Icons.chevron_right, size: 14, color: Color(0xFF64748B)),
                                  Text('Verifikasi Guru', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AdminColors.primary, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Verifikasi Guru',
                                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF0F172A),
                                      letterSpacing: -0.5,
                                    ),
                              ),
                            ],
                          ),
                          // Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.2)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.pending_actions_rounded, color: Color(0xFFD97706), size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  '$pendingCount Permohonan Menunggu',
                                  style: const TextStyle(
                                    color: Color(0xFFB45309),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.04, end: 0, curve: Curves.easeOutQuad),
                    SizedBox(height: isMobile ? 16 : 24),

                    // Capsule TabBar Container
                    Container(
                      width: isMobile ? double.infinity : 500,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        dividerColor: Colors.transparent,
                        indicator: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicatorPadding: const EdgeInsets.all(4),
                        labelColor: AdminColors.primary,
                        unselectedLabelColor: const Color(0xFF64748B),
                        labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 11 : 13),
                        tabs: [
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.hourglass_top_rounded, size: 13),
                                const SizedBox(width: 4),
                                Text('Pending ($pendingCount)'),
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle_rounded, size: 13),
                                const SizedBox(width: 4),
                                Text('Approved ($approvedCount)'),
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.cancel_rounded, size: 13),
                                const SizedBox(width: 4),
                                Text('Rejected ($rejectedCount)'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 100.ms, duration: 400.ms).slideY(begin: 0.04, end: 0, curve: Curves.easeOutQuad),
                    SizedBox(height: isMobile ? 16 : 24),

                    // TabBarView Content Area
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildFilteredList(context, 'pending', verifDocs, isMobile),
                          _buildFilteredList(context, 'approved', verifDocs, isMobile),
                          _buildFilteredList(context, 'rejected', verifDocs, isMobile),
                        ],
                      ),
                    ).animate().fadeIn(delay: 200.ms, duration: 400.ms).slideY(begin: 0.04, end: 0, curve: Curves.easeOutQuad),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilteredList(BuildContext context, String filterStatus, List<QueryDocumentSnapshot> allDocs, bool isMobile) {
    final filtered = allDocs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final status = data['status'] ?? 'pending';
      return status == filterStatus;
    }).toList();

    if (filtered.isEmpty) {
      String msg = 'Belum ada permohonan verifikasi pending.';
      if (filterStatus == 'approved') msg = 'Belum ada guru yang disetujui.';
      if (filterStatus == 'rejected') msg = 'Belum ada guru yang ditolak.';
      return _buildEmptyState(msg);
    }

    final filteredIds = filtered.map((d) => d.id).toList();
    final currentTabSelectedIds = _selectedIds.intersection(filteredIds.toSet());
    final bool isAllSelected = filteredIds.isNotEmpty && filteredIds.every((id) => _selectedIds.contains(id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (filterStatus == 'rejected')
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 24, vertical: 8),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: isAllSelected,
                    activeColor: AdminColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedIds.addAll(filteredIds);
                        } else {
                          _selectedIds.removeAll(filteredIds);
                        }
                      });
                    },
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Pilih (${currentTabSelectedIds.length}/${filtered.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569), fontSize: 12),
                  ),
                  const Spacer(),
                  if (currentTabSelectedIds.isNotEmpty) ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFEF2F2),
                        foregroundColor: const Color(0xFFEF4444),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      onPressed: () {
                        final selectedDocs = filtered.where((d) => _selectedIds.contains(d.id)).toList();
                        _showDeleteConfirmationDialog(context, selectedDocs);
                      },
                      icon: const Icon(Icons.delete_outline_rounded, size: 15),
                      label: const Text('Hapus Terpilih', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                    const SizedBox(width: 8),
                  ],
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    onPressed: () => _showDeleteConfirmationDialog(context, filtered),
                    icon: const Icon(Icons.delete_forever_rounded, size: 15),
                    label: const Text('Hapus Semua', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final doc = filtered[index];
              final data = doc.data() as Map<String, dynamic>;
              final String name = data['namaGuru'] ?? data['namaLengkap'] ?? data['nama'] ?? 'Tanpa Nama';
              final String school = data['sekolah'] ?? 'Belum diisi';
              final String status = data['status'] ?? 'pending';

              final dynamic createdVal = data['createdAt'];
              String dateStr = '-';
              if (createdVal is Timestamp) {
                final dt = createdVal.toDate();
                dateStr = '${dt.day}/${dt.month}/${dt.year}';
              }

              return _HoverableVerificationCard(
                id: doc.id,
                name: name,
                school: school,
                time: dateStr,
                delay: Duration(milliseconds: index * 40),
                status: status,
                isMobile: isMobile,
                showCheckbox: filterStatus == 'rejected',
                isSelected: _selectedIds.contains(doc.id),
                onSelectedChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedIds.add(doc.id);
                    } else {
                      _selectedIds.remove(doc.id);
                    }
                  });
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, List<QueryDocumentSnapshot> docsToDelete) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Konfirmasi Hapus (${docsToDelete.length} Permohonan)', style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Text(
              'Apakah Anda yakin ingin menghapus ${docsToDelete.length} permohonan verifikasi ini beserta akun guru dan file bukti mengajarnya?\n\nTindakan ini permanen dan tidak dapat dibatalkan.'),
          actions: [
            TextButton(
              child: const Text('Batal'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminColors.danger,
                foregroundColor: Colors.white,
              ),
              child: const Text('Hapus Permanen'),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteVerifications(docsToDelete);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteVerifications(List<QueryDocumentSnapshot> docsToDelete) async {
    if (docsToDelete.isEmpty) return;

    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AdminColors.primary),
        ),
      ),
    );

    try {
      int successCount = 0;
      for (var doc in docsToDelete) {
        final data = doc.data() as Map<String, dynamic>;
        final String fileUrl = data['buktiUrl'] ?? data['fileUrl'] ?? '';
        final String uid = data['uid'] ?? '';
        final String requestId = doc.id;

        if (uid.isNotEmpty) {
          try {
            final userSnap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
            String? username;
            String? avatarUrl;
            if (userSnap.exists) {
              final userData = userSnap.data() as Map<String, dynamic>?;
              username = userData?['username'] as String?;
              avatarUrl = userData?['avatarUrl'] as String?;
            }

            if (avatarUrl != null && avatarUrl.isNotEmpty && avatarUrl.contains('firebasestorage.googleapis.com')) {
              try {
                final ref = FirebaseStorage.instance.refFromURL(avatarUrl);
                await ref.delete();
              } catch (e) {
                debugPrint('Error deleting avatar: $e');
              }
            }

            if (username != null && username.isNotEmpty) {
              await FirebaseFirestore.instance.collection('usernames').doc(username.toLowerCase()).delete();
            }

            final classesSnap = await FirebaseFirestore.instance
                .collection('kelas')
                .where('guruUid', isEqualTo: uid)
                .get();
            if (classesSnap.docs.isNotEmpty) {
              for (var classDoc in classesSnap.docs) {
                await classDoc.reference.delete();
              }
            }

            await FirebaseFirestore.instance.collection('users').doc(uid).delete();
          } catch (e) {
            debugPrint('Error deleting teacher user: $e');
          }
        }

        if (fileUrl.isNotEmpty && fileUrl.contains('firebasestorage.googleapis.com')) {
          try {
            final ref = FirebaseStorage.instance.refFromURL(fileUrl);
            await ref.delete();
          } catch (e) {
            debugPrint('Error deleting storage file: $e');
          }
        }

        await FirebaseFirestore.instance.collection('guru_verifikasi').doc(requestId).delete();
        successCount++;
      }

      try {
        rootNavigator.pop();
      } catch (_) {}

      setState(() {
        _selectedIds.clear();
      });

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('$successCount permohonan verifikasi dan akun guru berhasil dihapus.'),
          backgroundColor: AdminColors.success,
        ),
      );
    } catch (e) {
      try {
        rootNavigator.pop();
      } catch (_) {}
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Gagal menghapus permohonan: $e'),
          backgroundColor: AdminColors.danger,
        ),
      );
    }
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFFE2E8F0),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.inbox_outlined, size: 48, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 20),
          Text(
            message,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1), curve: Curves.easeOutBack),
    );
  }
}

class _HoverableVerificationCard extends StatefulWidget {
  final String id;
  final String name;
  final String school;
  final String time;
  final Duration delay;
  final String status;
  final bool isMobile;
  final bool showCheckbox;
  final bool isSelected;
  final ValueChanged<bool?>? onSelectedChanged;

  const _HoverableVerificationCard({
    required this.id,
    required this.name,
    required this.school,
    required this.time,
    required this.delay,
    required this.status,
    required this.isMobile,
    this.showCheckbox = false,
    this.isSelected = false,
    this.onSelectedChanged,
  });

  @override
  State<_HoverableVerificationCard> createState() => _HoverableVerificationCardState();
}

class _HoverableVerificationCardState extends State<_HoverableVerificationCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    String initials = 'G';
    if (widget.name.isNotEmpty) {
      final cleanName = widget.name.replaceFirst('Pak ', '').replaceFirst('Bu ', '').trim();
      final parts = cleanName.split(' ');
      initials = parts.take(2).map((e) => e.isNotEmpty ? e[0] : '').join().toUpperCase();
    }
    if (initials.isEmpty) initials = 'G';

    Color statusColor;
    String statusText;
    IconData statusIcon;
    Color statusBgColor;
    Color statusTextColor;

    if (widget.status == 'approved') {
      statusColor = const Color(0xFF10B981);
      statusText = 'Disetujui';
      statusIcon = Icons.check_circle_rounded;
      statusBgColor = const Color(0xFF10B981).withOpacity(0.08);
      statusTextColor = const Color(0xFF047857);
    } else if (widget.status == 'rejected') {
      statusColor = const Color(0xFFEF4444);
      statusText = 'Ditolak';
      statusIcon = Icons.cancel_rounded;
      statusBgColor = const Color(0xFFEF4444).withOpacity(0.08);
      statusTextColor = const Color(0xFFB91C1C);
    } else {
      statusColor = const Color(0xFFF59E0B);
      statusText = 'Menunggu';
      statusIcon = Icons.hourglass_top_rounded;
      statusBgColor = const Color(0xFFF59E0B).withOpacity(0.08);
      statusTextColor = const Color(0xFFB45309);
    }

    if (widget.isMobile) {
      // Mobile Card Layout
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.015),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top: Checkbox (if rejected), Avatar, Name, Status Badge
            Row(
              children: [
                if (widget.showCheckbox) ...[
                  Checkbox(
                    value: widget.isSelected,
                    activeColor: AdminColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: widget.onSelectedChanged,
                  ),
                  const SizedBox(width: 4),
                ],
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [statusColor.withOpacity(0.8), statusColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ID: ${widget.id}',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: statusTextColor.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 11, color: statusTextColor),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusTextColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: Color(0xFFF1F5F9), height: 1),
            const SizedBox(height: 8),

            // Middle & Action: School, Date, and Review Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.school_rounded, size: 13, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              widget.school,
                              style: const TextStyle(color: Color(0xFF334155), fontSize: 12, fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 4),
                          Text(
                            widget.time,
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => context.go('/verifikasi/${widget.id}'),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.assignment_turned_in_rounded, size: 13, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'Review',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ).animate().fadeIn(delay: widget.delay, duration: 250.ms).slideY(begin: 0.04, end: 0, curve: Curves.easeOutQuad);
    }

    // Desktop Row Layout
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _isHovered ? AdminColors.primary.withOpacity(0.4) : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: [
            _isHovered
                ? BoxShadow(
                    color: AdminColors.primary.withOpacity(0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  )
                : BoxShadow(
                    color: Colors.black.withOpacity(0.01),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
          ],
        ),
        transform: Matrix4.translationValues(0, _isHovered ? -3 : 0, 0),
        child: Row(
          children: [
            if (widget.showCheckbox) ...[
              Checkbox(
                value: widget.isSelected,
                activeColor: AdminColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                onChanged: widget.onSelectedChanged,
              ),
              const SizedBox(width: 12),
            ],
            // Left indicator bar
            Container(
              width: 5,
              height: 52,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 20),

            // Col 1: Avatar + Name
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [statusColor.withOpacity(0.8), statusColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID: ${widget.id}',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Col 2: School
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  const Icon(Icons.school_rounded, size: 16, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.school,
                      style: const TextStyle(
                        color: Color(0xFF334155),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Col 3: Registered Date
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.time,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Col 4: Status Badge
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusBgColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusTextColor.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 12, color: statusTextColor),
                        const SizedBox(width: 6),
                        Text(
                          statusText,
                          style: TextStyle(
                            color: statusTextColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Col 5: Action Button
            AnimatedScale(
              scale: _isHovered ? 1.03 : 1.0,
              duration: const Duration(milliseconds: 150),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: InkWell(
                  onTap: () => context.go('/verifikasi/${widget.id}'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.assignment_turned_in_rounded, size: 14, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          'Review',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: widget.delay, duration: 300.ms).slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic);
  }
}
