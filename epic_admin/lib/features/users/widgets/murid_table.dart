import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:epic_admin/core/theme/admin_colors.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

String _getProxiedImageUrl(String url) {
  if (url.isEmpty) return '';
  if (url.contains('firebasestorage.googleapis.com') || url.contains('googleusercontent.com')) {
    return 'https://images.weserv.nl/?url=${Uri.encodeComponent(url)}';
  }
  return url;
}

class MuridTable extends StatelessWidget {
  /// Query pencarian (nama, ID, atau kelas). Kosong = tampilkan semua.
  final String searchQuery;

  /// Filter status akun. '' = semua, 'active' = aktif, 'suspended' = ditangguhkan.
  final String filterStatus;

  const MuridTable({
    super.key,
    this.searchQuery = '',
    this.filterStatus = '',
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'murid')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildEmptyState('Gagal memuat data murid');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AdminColors.primary),
            ),
          );
        }

        var docs = (snapshot.data?.docs ?? []).cast<QueryDocumentSnapshot<Map<String, dynamic>>>();

        // ── Client-side filtering ───────────────────────────────────────
        final query = searchQuery.trim().toLowerCase();
        if (query.isNotEmpty) {
          docs = docs.where((doc) {
            final data = doc.data();
            final name = (data['namaLengkap'] ?? '').toString().toLowerCase();
            final kelas = (data['kelas'] ?? '').toString().toLowerCase();
            final uid = doc.id.toLowerCase();
            final username = (data['username'] ?? '').toString().toLowerCase();
            return name.contains(query) ||
                kelas.contains(query) ||
                uid.contains(query) ||
                username.contains(query);
          }).toList();
        }

        if (filterStatus.isNotEmpty) {
          docs = docs.where((doc) {
            final data = doc.data();
            final status = (data['status'] ?? 'active').toString();
            return status == filterStatus;
          }).toList();
        }
        // ───────────────────────────────────────────────────────────────

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMobile) ...[
              _buildHeaderRow(context),
              const SizedBox(height: 6),
            ],
            Expanded(
              child: docs.isEmpty
                  ? _buildEmptyState(
                      query.isNotEmpty || filterStatus.isNotEmpty
                          ? 'Tidak ada murid yang sesuai pencarian'
                          : 'Belum ada data murid',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      physics: const BouncingScrollPhysics(),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data();
                        final String uid = doc.id;
                        final String name = data['namaLengkap'] ?? 'Tanpa Nama';
                        final String className = data['kelas'] ?? 'Belum ada kelas';
                        final String sekolah = data['sekolah'] ?? '';
                        final String classDisplay = sekolah.isNotEmpty ? '$className ($sekolah)' : className;
                        final int poin = data['poin'] is int ? data['poin'] : 0;
                        final String? avatarUrl = data['avatarUrl'] as String?;
                        final dynamic lastActiveVal = data['lastActiveAt'] ?? data['nyawaLastReset'];
                        final String status = data['status'] ?? 'active';
                        String lastActive = 'Baru saja';
                        if (lastActiveVal is Timestamp) {
                          final dt = lastActiveVal.toDate();
                          lastActive = '${dt.day}/${dt.month}/${dt.year}';
                        }

                        return _HoverableMuridRow(
                          name: name,
                          id: uid,
                          className: classDisplay,
                          score: poin.toDouble(),
                          lastActive: lastActive,
                          avatarUrl: avatarUrl,
                          status: status,
                          isMobile: isMobile,
                          delay: Duration(milliseconds: index * 40),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.school_rounded, size: 40, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              color: Color(0xFF475569),
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: const [
          Expanded(flex: 3, child: Text('NAMA SISWA', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 11, letterSpacing: 0.8))),
          Expanded(flex: 2, child: Text('KELAS', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 11, letterSpacing: 0.8))),
          Expanded(flex: 2, child: Text('TOTAL POIN', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 11, letterSpacing: 0.8))),
          Expanded(flex: 2, child: Text('AKTIVITAS TERAKHIR', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 11, letterSpacing: 0.8))),
          Expanded(flex: 2, child: Text('AKSI', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 11, letterSpacing: 0.8))),
        ],
      ),
    );
  }
}

class _HoverableMuridRow extends StatefulWidget {
  final String name;
  final String id;
  final String className;
  final double score;
  final String lastActive;
  final String? avatarUrl;
  final String status;
  final bool isMobile;
  final Duration delay;

  const _HoverableMuridRow({
    required this.name,
    required this.id,
    required this.className,
    required this.score,
    required this.lastActive,
    this.avatarUrl,
    required this.status,
    required this.isMobile,
    required this.delay,
  });

  @override
  State<_HoverableMuridRow> createState() => _HoverableMuridRowState();
}

class _HoverableMuridRowState extends State<_HoverableMuridRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    String initials = '';
    if (widget.name.isNotEmpty) {
      final parts = widget.name.trim().split(' ');
      initials = parts.take(2).map((e) => e.isNotEmpty ? e[0] : '').join().toUpperCase();
    }
    if (initials.isEmpty) {
      initials = 'S';
    }

    final bool isSuspended = widget.status == 'suspended';

    if (widget.isMobile) {
      // Mobile Card Layout
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSuspended ? AdminColors.danger.withOpacity(0.3) : const Color(0xFFE2E8F0),
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
            // Top: Avatar + Name + Score + Status
            Row(
              children: [
                _buildAvatarWidget(initials),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isSuspended)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFFCA5A5)),
                              ),
                              child: const Text(
                                'SUSPENDED',
                                style: TextStyle(color: Color(0xFFEF4444), fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Kelas: ${widget.className}',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AdminColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AdminColors.primary.withOpacity(0.15)),
                  ),
                  child: Text(
                    '${widget.score.toInt()} Poin',
                    style: const TextStyle(
                      color: AdminColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: Color(0xFFF1F5F9), height: 1),
            const SizedBox(height: 8),

            // Bottom: Info & Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ID: ${widget.id}',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                    ),
                    Text(
                      'Aktif: ${widget.lastActive}',
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      color: AdminColors.primary,
                      style: IconButton.styleFrom(
                        backgroundColor: AdminColors.primary.withOpacity(0.08),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.all(8),
                      ),
                      onPressed: () => context.go('/users/murid/${widget.id}'),
                      tooltip: 'Lihat Detail',
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(isSuspended ? Icons.check_circle_outline_rounded : Icons.block_rounded, size: 18),
                      color: isSuspended ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                      style: IconButton.styleFrom(
                        backgroundColor: (isSuspended ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withOpacity(0.08),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.all(8),
                      ),
                      onPressed: () => _showSuspendDialog(context, widget.id, widget.name),
                      tooltip: isSuspended ? 'Aktifkan Akun' : 'Suspend Akun',
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      color: const Color(0xFFEF4444),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444).withOpacity(0.08),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.all(8),
                      ),
                      onPressed: () => _showDeleteConfirmation(context, widget.id, widget.name),
                      tooltip: 'Hapus Murid',
                    ),
                  ],
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
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isHovered ? AdminColors.primary.withOpacity(0.4) : const Color(0xFFE2E8F0).withOpacity(0.5),
            width: 1.2,
          ),
          boxShadow: [
            _isHovered
                ? BoxShadow(
                    color: AdminColors.primary.withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  )
                : BoxShadow(
                    color: Colors.black.withOpacity(0.005),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
          ],
        ),
        transform: Matrix4.translationValues(0, _isHovered ? -3 : 0, 0),
        child: Row(
          children: [
            // Student Name & ID
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  _buildAvatarWidget(initials),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Class
            Expanded(
              flex: 2,
              child: Text(
                widget.className,
                style: const TextStyle(
                  color: Color(0xFF334155),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Score (Total Poin)
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AdminColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AdminColors.primary.withOpacity(0.12)),
                    ),
                    child: Text(
                      widget.score.toInt().toString(),
                      style: const TextStyle(
                        color: AdminColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Last Active
            Expanded(
              flex: 2,
              child: Text(
                widget.lastActive,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                ),
              ),
            ),

            // Action Buttons
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.visibility_outlined, size: 20),
                    color: const Color(0xFF64748B),
                    hoverColor: AdminColors.primary.withOpacity(0.08),
                    onPressed: () => context.go('/users/murid/${widget.id}'),
                    tooltip: 'Lihat Detail',
                  ),
                  IconButton(
                    icon: Icon(isSuspended ? Icons.check_circle_outline_rounded : Icons.block_rounded, size: 20),
                    color: isSuspended ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    hoverColor: (isSuspended ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withOpacity(0.08),
                    onPressed: () => _showSuspendDialog(context, widget.id, widget.name),
                    tooltip: isSuspended ? 'Aktifkan Akun' : 'Suspend Akun',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    color: const Color(0xFFEF4444),
                    hoverColor: const Color(0xFFEF4444).withOpacity(0.08),
                    onPressed: () => _showDeleteConfirmation(context, widget.id, widget.name),
                    tooltip: 'Hapus Murid',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: widget.delay, duration: 300.ms).slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic);
  }

  Widget _buildAvatarWidget(String initials) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AdminColors.primary.withOpacity(0.2)),
      ),
      child: widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.network(
                _getProxiedImageUrl(widget.avatarUrl!),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildInitials(initials),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AdminColors.primary.withOpacity(0.3),
                        ),
                      ),
                    ),
                  );
                },
              ),
            )
          : _buildInitials(initials),
    );
  }

  Widget _buildInitials(String initials) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AdminColors.primary.withOpacity(0.15),
            AdminColors.primary.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: AdminColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, String uid, String name) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Konfirmasi Hapus', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Apakah Anda yakin ingin menghapus murid "$name"?'),
              const SizedBox(height: 8),
              const Text('Tindakan ini permanen dan tidak dapat dibatalkan.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Batal'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AdminColors.danger, foregroundColor: Colors.white),
              child: const Text('Hapus Permanen'),
              onPressed: () async {
                Navigator.of(context).pop();

                final rootNavigator = Navigator.of(context, rootNavigator: true);
                final scaffoldMessenger = ScaffoldMessenger.of(context);

                showDialog(
                  context: context,
                  barrierDismissible: false,
                  useRootNavigator: true,
                  builder: (dialogContext) => const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AdminColors.primary),
                    ),
                  ),
                );

                try {
                  final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
                  String? username;
                  String? avatarUrl;
                  if (snap.exists) {
                    final data = snap.data() as Map<String, dynamic>?;
                    username = data?['username'] as String?;
                    avatarUrl = data?['avatarUrl'] as String?;
                  }

                  final artworksSnap = await FirebaseFirestore.instance
                      .collection('artworks')
                      .where('uid', isEqualTo: uid)
                      .get();

                  if (artworksSnap.docs.isNotEmpty) {
                    final batch = FirebaseFirestore.instance.batch();
                    for (var doc in artworksSnap.docs) {
                      final artData = doc.data();
                      final String imageUrl = artData['imageUrl']?.toString() ?? '';
                      if (imageUrl.isNotEmpty && imageUrl.contains('firebasestorage.googleapis.com')) {
                        try {
                          final ref = FirebaseStorage.instance.refFromURL(imageUrl);
                          await ref.delete();
                        } catch (e) {
                          debugPrint('Error deleting artwork file: $e');
                        }
                      }
                      batch.delete(doc.reference);
                    }
                    await batch.commit();
                  }

                  if (avatarUrl != null && avatarUrl.isNotEmpty && avatarUrl.contains('firebasestorage.googleapis.com')) {
                    try {
                      final ref = FirebaseStorage.instance.refFromURL(avatarUrl);
                      await ref.delete();
                    } catch (e) {
                      debugPrint('Error deleting avatar file: $e');
                    }
                  }

                  if (username != null && username.isNotEmpty) {
                    await FirebaseFirestore.instance.collection('usernames').doc(username.toLowerCase()).delete();
                  }

                  final kelasSnap = await FirebaseFirestore.instance
                      .collection('kelas')
                      .where('muridIds', arrayContains: uid)
                      .get();
                  if (kelasSnap.docs.isNotEmpty) {
                    final batch = FirebaseFirestore.instance.batch();
                    for (var doc in kelasSnap.docs) {
                      batch.update(doc.reference, {
                        'muridIds': FieldValue.arrayRemove([uid]),
                      });
                    }
                    await batch.commit();
                  }

                  await FirebaseFirestore.instance.collection('users').doc(uid).delete();

                  try {
                    rootNavigator.pop();
                  } catch (_) {}

                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text('Murid "$name" beserta semua karya dan berkas berhasil dihapus.'),
                      backgroundColor: AdminColors.success,
                    ),
                  );
                } catch (e) {
                  try {
                    rootNavigator.pop();
                  } catch (_) {}
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text('Gagal menghapus: $e'), backgroundColor: AdminColors.danger),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showSuspendDialog(BuildContext context, String uid, String name) async {
    try {
      final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!snap.exists || !context.mounted) return;
      final data = snap.data() as Map<String, dynamic>;
      final bool isSuspended = (data['status'] ?? 'active') == 'suspended';
      final String action = isSuspended ? 'mengaktifkan kembali' : 'menangguhkan (suspend)';
      final String btnText = isSuspended ? 'Aktifkan' : 'Suspend';

      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(isSuspended ? 'Aktifkan Akun Murid' : 'Suspend Akun Murid',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Text('Apakah Anda yakin ingin $action akun murid "$name"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isSuspended ? AdminColors.success : AdminColors.danger,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.of(ctx).pop();
                await FirebaseFirestore.instance.collection('users').doc(uid).update({
                  'status': isSuspended ? 'active' : 'suspended',
                  'isActive': isSuspended ? true : false,
                });
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Akun murid "$name" berhasil ${isSuspended ? "diaktifkan" : "ditangguhkan"}.'),
                      backgroundColor: AdminColors.success,
                    ),
                  );
                }
              },
              child: Text(btnText),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat data: $e'), backgroundColor: AdminColors.danger),
        );
      }
    }
  }
}
