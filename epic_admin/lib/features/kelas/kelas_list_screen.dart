import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:epic_admin/core/theme/admin_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

class ClassItem {
  final String name;
  final String code;
  final String teacher;
  final int students;
  final String id;
  final String status;

  ClassItem({
    required this.name,
    required this.code,
    required this.teacher,
    required this.students,
    required this.id,
    required this.status,
  });
}

class KelasListScreen extends StatefulWidget {
  const KelasListScreen({super.key});

  @override
  State<KelasListScreen> createState() => _KelasListScreenState();
}

class _KelasListScreenState extends State<KelasListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _generateClassCode() {
    final rand = Random();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(6, (index) => chars[rand.nextInt(chars.length)]).join();
  }

  void _showCreateClassDialog(BuildContext context) async {
    final nameController = TextEditingController();
    String? selectedGuruId;
    String? selectedGuruNama;

    // Fetch approved teachers to display in dropdown
    final teachersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'guru')
        .where('guruStatus', isEqualTo: 'approved')
        .get();

    final teachers = teachersSnapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'uid': doc.id,
        'nama': data['namaLengkap'] ?? data['nama'] ?? 'Tanpa Nama',
      };
    }).toList();

    if (!context.mounted) return;

    if (teachers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Belum ada guru terverifikasi. Harap verifikasi guru terlebih dahulu.'),
          backgroundColor: AdminColors.danger,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Buat Kelas Baru', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Nama Kelas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      hintText: 'Misal: Kelas 5-A',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Wali Kelas / Guru', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedGuruId,
                    hint: const Text('Pilih Guru'),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    items: teachers.map((t) {
                      return DropdownMenuItem<String>(
                        value: t['uid'],
                        child: Text(t['nama']!),
                      );
                    }).toList(),
                    onChanged: (val) {
                      final selected = teachers.firstWhere((t) => t['uid'] == val);
                      setDialogState(() {
                        selectedGuruId = val;
                        selectedGuruNama = selected['nama'];
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: const Text('Batal'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty || selectedGuruId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Lengkapi nama kelas dan pilih guru.'), backgroundColor: AdminColors.danger),
                      );
                      return;
                    }

                    Navigator.of(context).pop();

                    try {
                      final code = _generateClassCode();
                      await FirebaseFirestore.instance.collection('kelas').add({
                        'namaKelas': name,
                        'kodeKelas': code,
                        'guruId': selectedGuruId,
                        'guruUid': selectedGuruId,
                        'guruNama': selectedGuruNama,
                        'muridIds': [],
                        'status': 'aktif',
                        'createdAt': FieldValue.serverTimestamp(),
                      });

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Kelas "$name" dengan kode "$code" berhasil dibuat!'), backgroundColor: AdminColors.success),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Gagal membuat kelas: $e'), backgroundColor: AdminColors.danger),
                        );
                      }
                    }
                  },
                  child: const Text('Buat Kelas', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('kelas').snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final allClasses = docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final List<dynamic> muridIds = data['muridIds'] is List ? data['muridIds'] : [];
          return ClassItem(
            id: doc.id,
            name: data['namaKelas'] ?? 'Kelas Tanpa Nama',
            code: data['kodeKelas'] ?? '-',
            teacher: data['guruNama'] ?? 'Tanpa Guru',
            students: muridIds.length,
            status: data['status'] ?? 'aktif',
          );
        }).toList();

        final query = _searchController.text.toLowerCase();
        final filteredClasses = allClasses.where((item) {
          return item.name.toLowerCase().contains(query) ||
              item.teacher.toLowerCase().contains(query) ||
              item.code.toLowerCase().contains(query);
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
                    // Header
                    if (isMobile)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('Dashboard', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: const Color(0xFF64748B))),
                              const Icon(Icons.chevron_right, size: 14, color: Color(0xFF64748B)),
                              Text('Manajemen Kelas', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AdminColors.primary, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Manajemen Kelas',
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF0F172A),
                                      letterSpacing: -0.5,
                                    ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () => _showCreateClassDialog(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AdminColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                icon: const Icon(Icons.add_rounded, size: 16),
                                label: const Text('Buat Kelas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
                                  Text('Manajemen Kelas', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AdminColors.primary, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Manajemen Kelas',
                                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF0F172A),
                                      letterSpacing: -0.5,
                                    ),
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _showCreateClassDialog(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AdminColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Buat Kelas Baru', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.04, end: 0, curve: Curves.easeOutQuad),
                    SizedBox(height: isMobile ? 16 : 24),

                    // Class List Card Container
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.all(isMobile ? 14 : 28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(isMobile ? 18 : 24),
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.015),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Search Box & Header info
                            if (isMobile)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Daftar Kelas Aktif',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0F172A),
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        '${filteredClasses.length} kelas',
                                        style: const TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: _searchController,
                                    decoration: InputDecoration(
                                      hintText: 'Cari nama, wali kelas, atau kode...',
                                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 18),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(color: AdminColors.primary, width: 1.5),
                                      ),
                                      filled: true,
                                      fillColor: const Color(0xFFF8FAFC),
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    ),
                                  ),
                                ],
                              )
                            else
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Daftar Kelas Aktif',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0F172A),
                                          fontSize: 18,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Menampilkan ${filteredClasses.length} kelas terdaftar',
                                        style: const TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(
                                    width: 340,
                                    child: TextField(
                                      controller: _searchController,
                                      decoration: InputDecoration(
                                        hintText: 'Cari nama kelas, wali kelas, atau kode...',
                                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
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
                                          borderSide: const BorderSide(color: AdminColors.primary, width: 1.5),
                                        ),
                                        filled: true,
                                        fillColor: const Color(0xFFF8FAFC),
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            SizedBox(height: isMobile ? 12 : 24),

                            // Custom Table Column Headers on Desktop
                            if (!isMobile) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                child: Row(
                                  children: const [
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        'NAMA KELAS',
                                        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 11, letterSpacing: 0.5),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        'KODE KELAS',
                                        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 11, letterSpacing: 0.5),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 4,
                                      child: Text(
                                        'WALI KELAS',
                                        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 11, letterSpacing: 0.5),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        'JUMLAH MURID',
                                        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 11, letterSpacing: 0.5),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'STATUS',
                                        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 11, letterSpacing: 0.5),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 80,
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
                              const SizedBox(height: 12),
                            ],

                            // Rows
                            Expanded(
                              child: filteredClasses.isEmpty
                                  ? _buildEmptyState()
                                  : ListView.builder(
                                      physics: const BouncingScrollPhysics(),
                                      itemCount: filteredClasses.length,
                                      itemBuilder: (context, index) {
                                        final item = filteredClasses[index];
                                        return _HoverableClassRow(
                                          item: item,
                                          isMobile: isMobile,
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 200.ms, duration: 400.ms).slideY(begin: 0.04, end: 0, curve: Curves.easeOutQuad),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
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
            child: const Icon(Icons.search_off_rounded, size: 40, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          const Text(
            'Tidak ada kelas yang cocok',
            style: TextStyle(
              color: Color(0xFF475569),
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Coba periksa kata kunci pencarian Anda kembali.',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
            ),
          ),
        ],
      ).animate().fadeIn(duration: 350.ms),
    );
  }
}

class _HoverableClassRow extends StatefulWidget {
  final ClassItem item;
  final bool isMobile;

  const _HoverableClassRow({
    required this.item,
    required this.isMobile,
  });

  @override
  State<_HoverableClassRow> createState() => _HoverableClassRowState();
}

class _HoverableClassRowState extends State<_HoverableClassRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    String initials = 'G';
    if (widget.item.teacher.isNotEmpty) {
      final cleanName = widget.item.teacher.replaceFirst('Pak ', '').replaceFirst('Bu ', '').trim();
      final parts = cleanName.split(' ');
      initials = parts.take(2).map((e) => e.isNotEmpty ? e[0] : '').join().toUpperCase();
    }
    if (initials.isEmpty) initials = 'G';

    if (widget.isMobile) {
      // Mobile Card Layout
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
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
            // Top: Class Icon + Name + Status
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      widget.item.name.replaceAll('Kelas ', '').take(3),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
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
                        widget.item.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 8,
                            backgroundColor: const Color(0xFFEFF6FF),
                            child: Text(
                              initials,
                              style: const TextStyle(color: Color(0xFF2563EB), fontSize: 8, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              widget.item.teacher,
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: widget.item.status == 'aktif' ? const Color(0xFFD1FAE5) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: (widget.item.status == 'aktif' ? const Color(0xFF10B981) : const Color(0xFF64748B)).withOpacity(0.2),
                    ),
                  ),
                  child: Text(
                    widget.item.status == 'aktif' ? 'Aktif' : 'Nonaktif',
                    style: TextStyle(
                      color: widget.item.status == 'aktif' ? const Color(0xFF065F46) : const Color(0xFF475569),
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: Color(0xFFF1F5F9), height: 1),
            const SizedBox(height: 8),

            // Bottom: Code Capsule with Copy + Student Count + Detail Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Code capsule
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.item.code,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF334155),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: widget.item.code));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Kode kelas ${widget.item.code} berhasil disalin!'),
                              backgroundColor: const Color(0xFF059669),
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        child: const Icon(Icons.copy_rounded, size: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Text(
                      '${widget.item.students} Murid',
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: () => context.go('/kelas/${widget.item.id}'),
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
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        child: const Text(
                          'Detail',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Desktop Row Layout
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _isHovered ? AdminColors.primary.withOpacity(0.4) : const Color(0xFFE2E8F0),
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
            // Col 1: Class Name
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
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
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        widget.item.name.replaceAll('Kelas ', ''),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      widget.item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                        fontSize: 15,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Col 2: Code Capsule with Copy
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.item.code,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF334155),
                            letterSpacing: 0.5,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: widget.item.code));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Kode kelas ${widget.item.code} berhasil disalin!',
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
                              size: 14,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Col 3: Teacher Info
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFFEFF6FF),
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.item.teacher,
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

            // Col 4: Students Count
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  const Icon(Icons.groups_rounded, size: 16, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.item.students} Murid',
                    style: const TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Col 5: Status
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.item.status == 'aktif' ? const Color(0xFFD1FAE5) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: (widget.item.status == 'aktif' ? const Color(0xFF10B981) : const Color(0xFF64748B)).withOpacity(0.2),
                      ),
                    ),
                    child: Text(
                      widget.item.status == 'aktif' ? 'Aktif' : 'Nonaktif',
                      style: TextStyle(
                        color: widget.item.status == 'aktif' ? const Color(0xFF065F46) : const Color(0xFF475569),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Col 6: Detail Button
            AnimatedScale(
              scale: _isHovered ? 1.03 : 1.0,
              duration: const Duration(milliseconds: 150),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: InkWell(
                  onTap: () => context.go('/kelas/${widget.item.id}'),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withOpacity(0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.visibility_rounded, size: 12, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          'Detail',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
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
    );
  }
}

extension StringExtension on String {
  String take(int n) {
    if (length <= n) return this;
    return substring(0, n);
  }
}
