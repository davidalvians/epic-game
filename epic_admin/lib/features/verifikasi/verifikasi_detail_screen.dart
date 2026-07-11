import 'package:epic_admin/core/theme/admin_colors.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_storage/firebase_storage.dart';

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
  if (url.contains('firebasestorage.googleapis.com')) {
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

class VerifikasiDetailScreen extends StatefulWidget {
  final String id;
  const VerifikasiDetailScreen({super.key, required this.id});

  @override
  State<VerifikasiDetailScreen> createState() => _VerifikasiDetailScreenState();
}

class _VerifikasiDetailScreenState extends State<VerifikasiDetailScreen> {
  final TextEditingController _catatanController = TextEditingController();
  late Stream<DocumentSnapshot> _verifStream;

  @override
  void initState() {
    super.initState();
    _verifStream = FirebaseFirestore.instance.collection('guru_verifikasi').doc(widget.id).snapshots();
  }

  // Preset reject notes
  final List<String> _presets = [
    'SK Mengajar buram & tidak terbaca',
    'Nama di SK tidak cocok dengan akun',
    'Masa berlaku SK mengajar sudah habis',
    'Dokumen SK tidak ditandatangani kepsek',
  ];

  @override
  void dispose() {
    _catatanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWide = screenWidth >= 1100;
    final bool isWideButtons = screenWidth >= 600;

    return StreamBuilder<DocumentSnapshot>(
      stream: _verifStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            body: Center(child: Text('Terjadi kesalahan memuat data: ${snapshot.error}')),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AdminColors.primary),
              ),
            ),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Permohonan verifikasi tidak ditemukan.', style: TextStyle(fontWeight: FontWeight.bold)),
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

        final verifData = snapshot.data!.data() as Map<String, dynamic>;
        final String teacherName = verifData['namaGuru'] ?? verifData['namaLengkap'] ?? verifData['nama'] ?? 'Tanpa Nama';
        final String email = verifData['email'] ?? '-';
        final String school = verifData['sekolah'] ?? '-';
        final String subject = verifData['mataPelajaran'] ?? verifData['mapel'] ?? '-';
        final String status = verifData['status'] ?? 'pending';
        final String uid = verifData['uid'] ?? '';
        final String fileUrl = verifData['buktiUrl'] ?? verifData['fileUrl'] ?? '';
        final String fileName = verifData['fileName'] ?? _getFileName(fileUrl, 'bukti_mengajar.pdf');

        final dynamic createdVal = verifData['createdAt'];
        String dateStr = '-';
        if (createdVal is Timestamp) {
          final dt = createdVal.toDate();
          dateStr = '${dt.day}/${dt.month}/${dt.year}';
        }

        final Widget infoGuruWidget = Container(
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
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'PROFIL PEMOHON',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64748B),
                            letterSpacing: 1.2,
                            fontSize: 11,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: (status == 'approved' 
                                    ? const Color(0xFF10B981) 
                                    : (status == 'rejected' ? const Color(0xFFEF4444) : const Color(0xFFF59E0B))).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: (status == 'approved' 
                                      ? const Color(0xFF10B981) 
                                      : (status == 'rejected' ? const Color(0xFFEF4444) : const Color(0xFFF59E0B))).withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                status == 'approved' 
                                    ? Icons.check_circle_rounded 
                                    : (status == 'rejected' ? Icons.cancel_rounded : Icons.hourglass_top_rounded), 
                                size: 10, 
                                color: status == 'approved' 
                                    ? const Color(0xFF047857) 
                                    : (status == 'rejected' ? const Color(0xFFB91C1C) : const Color(0xFFD97706)),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  color: status == 'approved' 
                                      ? const Color(0xFF047857) 
                                      : (status == 'rejected' ? const Color(0xFFB91C1C) : const Color(0xFFB45309)),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Avatar + Name Block
                    Row(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2563EB).withOpacity(0.15),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(Icons.person_rounded, size: 40, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                teacherName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                  fontSize: 20,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                email,
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 28),
                    const Divider(color: Color(0xFFE2E8F0), height: 1),
                    const SizedBox(height: 24),
                    
                    // Grid of Details
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(2),
                        1: FlexColumnWidth(3),
                      },
                      children: [
                        _buildTableRow('ID Permohonan', widget.id, Icons.vpn_key_rounded),
                        _buildTableRow('Instansi / Sekolah', school, Icons.school_rounded),
                        _buildTableRow('Mata Pelajaran', subject, Icons.book_rounded),
                        _buildTableRow('Tanggal Daftar', dateStr, Icons.calendar_today_rounded),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.04, end: 0, curve: Curves.easeOutQuad);

        Widget buildBuktiMengajarWidget({required bool expandPreview}) {
          return Container(
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
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: expandPreview ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'DOKUMEN PENDUKUNG',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF64748B),
                          letterSpacing: 1.2,
                          fontSize: 11,
                        ),
                      ),
                      const Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 16),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: (_isImageFile(fileUrl, fileName) ? const Color(0xFF3B82F6) : const Color(0xFFEF4444)).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _isImageFile(fileUrl, fileName) ? Icons.image_rounded : Icons.picture_as_pdf_rounded,
                            color: _isImageFile(fileUrl, fileName) ? const Color(0xFF3B82F6) : const Color(0xFFEF4444),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fileName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _isImageFile(fileUrl, fileName) ? 'Format: Image Document' : 'Format: PDF Document',
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
                  const SizedBox(height: 24),
                  
                  expandPreview
                      ? Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.01),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                child: _isImageFile(fileUrl, fileName)
                                    ? Image.network(
                                        _getProxiedImageUrl(fileUrl),
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error, stackTrace) => const Center(
                                          child: Padding(
                                            padding: EdgeInsets.all(20.0),
                                            child: Icon(Icons.broken_image_rounded, size: 50, color: Colors.grey),
                                          ),
                                        ),
                                      )
                                    : SKDocumentPreview(
                                        teacherName: teacherName,
                                        school: school,
                                        subject: subject,
                                        date: dateStr,
                                      ),
                              ),
                            ),
                          ),
                        )
                      : Container(
                          height: 380,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.01),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: _isImageFile(fileUrl, fileName)
                                  ? Image.network(
                                      _getProxiedImageUrl(fileUrl),
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) => const Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(20.0),
                                          child: Icon(Icons.broken_image_rounded, size: 50, color: Colors.grey),
                                        ),
                                      ),
                                    )
                                  : SKDocumentPreview(
                                      teacherName: teacherName,
                                      school: school,
                                      subject: subject,
                                      date: dateStr,
                                    ),
                            ),
                          ),
                        ),
                  const SizedBox(height: 24),
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: fileUrl.isNotEmpty ? () => _openDocument(context, fileUrl) : null,
                      icon: const Icon(Icons.open_in_new_rounded, size: 14),
                      label: const Text('Buka Dokumen', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.04, end: 0, curve: Curves.easeOutQuad);
        }

        final Widget catatanAdminWidget = Container(
          padding: const EdgeInsets.all(32),
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
              const Text(
                'CATATAN PENINJAUAN',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
                  letterSpacing: 1.2,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 16),
              
              if (status == 'pending') ...[
                const Text(
                  'Templat Penolakan Cepat:',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: _presets.map((preset) {
                    return MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _catatanController.text = preset;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            preset,
                            style: const TextStyle(
                              color: Color(0xFF475569),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                
                TextField(
                  controller: _catatanController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Tulis catatan atau instruksi perbaikan untuk guru...',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
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
                  ),
                ),
                const SizedBox(height: 32),
                
                if (isWideButtons)
                  Row(
                    children: [
                      Expanded(
                        child: _buildGradientButton(
                          onPressed: () => _approveTeacher(context, uid, widget.id, teacherName),
                          text: 'Setujui & Aktifkan Guru',
                          icon: Icons.check_circle_rounded,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF059669), Color(0xFF10B981)],
                          ),
                          shadowColor: const Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: _buildGradientButton(
                          onPressed: () => _rejectTeacher(context, uid, widget.id, teacherName, _catatanController.text),
                          text: 'Tolak Permohonan',
                          icon: Icons.cancel_rounded,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
                          ),
                          shadowColor: const Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildGradientButton(
                        onPressed: () => _approveTeacher(context, uid, widget.id, teacherName),
                        text: 'Setujui & Aktifkan Guru',
                        icon: Icons.check_circle_rounded,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF059669), Color(0xFF10B981)],
                        ),
                        shadowColor: const Color(0xFF10B981),
                      ),
                      const SizedBox(height: 12),
                      _buildGradientButton(
                        onPressed: () => _rejectTeacher(context, uid, widget.id, teacherName, _catatanController.text),
                        text: 'Tolak Permohonan',
                        icon: Icons.cancel_rounded,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
                        ),
                        shadowColor: const Color(0xFFEF4444),
                      ),
                    ],
                  ),
              ] else ...[
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
                      const Text(
                        'Catatan Admin:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        verifData['catatanAdmin'] ?? 'Tidak ada catatan.',
                        style: const TextStyle(fontSize: 14, color: Color(0xFF334155), height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      if (verifData['processedAt'] != null)
                        Text(
                          'Diproses pada: ${(verifData['processedAt'] as Timestamp).toDate().toString()}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                        ),
                    ],
                  ),
                ),
                if (status == 'rejected') ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminColors.danger,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.delete_forever_rounded, size: 18),
                      label: const Text('Hapus Permohonan & Berkas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      onPressed: () => _deleteRejectedVerification(context, widget.id, fileUrl, uid),
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 20),
              const Center(
                child: Text(
                  '* Perubahan status verifikasi akan disinkronisasikan langsung ke perangkat Guru',
                  style: TextStyle(color: Color(0xFF94A3B8), fontStyle: FontStyle.italic, fontSize: 12),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideY(begin: 0.04, end: 0, curve: Curves.easeOutQuad);

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
                    // Manual Header Row with Back Button
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
                                Text('Verifikasi Guru', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: const Color(0xFF64748B))),
                                const Icon(Icons.chevron_right, size: 14, color: Color(0xFF64748B)),
                                Text('Review', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AdminColors.primary, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Review Permohonan Guru',
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
                        padding: const EdgeInsets.only(top: 8, bottom: 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Responsive panel row / column
                            if (isWide)
                              IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          infoGuruWidget,
                                          const SizedBox(height: 32),
                                          catatanAdminWidget,
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 32),
                                    Expanded(
                                      child: buildBuktiMengajarWidget(expandPreview: true),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  infoGuruWidget,
                                  const SizedBox(height: 24),
                                  buildBuktiMengajarWidget(expandPreview: false),
                                  const SizedBox(height: 24),
                                  catatanAdminWidget,
                                ],
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

  void _approveTeacher(BuildContext context, String uid, String requestId, String name) async {
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

      // Update verifikasi doc
      final verifRef = FirebaseFirestore.instance.collection('guru_verifikasi').doc(requestId);
      batch.update(verifRef, {
        'status': 'approved',
        'processedAt': FieldValue.serverTimestamp(),
        'catatanAdmin': 'Disetujui dari peninjauan verifikasi.',
      });

      await batch.commit();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Permohonan guru "$name" berhasil disetujui.'), backgroundColor: AdminColors.success),
        );
        context.pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyetujui: $e'), backgroundColor: AdminColors.danger),
        );
      }
    }
  }

  void _rejectTeacher(BuildContext context, String uid, String requestId, String name, String notes) async {
    if (notes.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mohon isi catatan penolakan.'), backgroundColor: AdminColors.danger),
      );
      return;
    }

    try {
      final batch = FirebaseFirestore.instance.batch();

      // Update user doc
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
      batch.update(userRef, {
        'guruStatus': 'rejected',
      });

      // Update verifikasi doc
      final verifRef = FirebaseFirestore.instance.collection('guru_verifikasi').doc(requestId);
      batch.update(verifRef, {
        'status': 'rejected',
        'processedAt': FieldValue.serverTimestamp(),
        'catatanAdmin': notes,
      });

      await batch.commit();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Permohonan guru "$name" ditolak dengan catatan.'), backgroundColor: AdminColors.success),
        );
        context.pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menolak: $e'), backgroundColor: AdminColors.danger),
        );
      }
    }
  }

  void _deleteRejectedVerification(BuildContext context, String requestId, String fileUrl, String uid) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Konfirmasi Hapus Permohonan', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text(
            'Apakah Anda yakin ingin menghapus permohonan verifikasi ini beserta file bukti mengajarnya dari Firebase Storage?\n\nTindakan ini akan mereset status guru tersebut menjadi aktif kembali.\n\nTindakan ini permanen dan tidak dapat dibatalkan.'
          ),
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
              onPressed: () async {
                Navigator.of(context).pop(); // Dismiss confirmation dialog
                
                final rootNavigator = Navigator.of(context, rootNavigator: true);
                final pageNavigator = Navigator.of(context);
                final scaffoldMessenger = ScaffoldMessenger.of(context);

                // Show loading spinner
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (dialogContext) => const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AdminColors.primary),
                    ),
                  ),
                );

                try {
                  // 1. If uid is provided, clean up and delete user document completely
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

                      // Delete avatar image from Storage
                      if (avatarUrl != null && avatarUrl.isNotEmpty && avatarUrl.contains('firebasestorage.googleapis.com')) {
                        try {
                          final ref = FirebaseStorage.instance.refFromURL(avatarUrl);
                          await ref.delete();
                        } catch (e) {
                          debugPrint('Error deleting avatar: $e');
                        }
                      }

                      // Delete username reservation
                      if (username != null && username.isNotEmpty) {
                        await FirebaseFirestore.instance.collection('usernames').doc(username.toLowerCase()).delete();
                      }

                      // Remove/delete classes associated with this teacher (if any)
                      final classesSnap = await FirebaseFirestore.instance
                          .collection('kelas')
                          .where('guruUid', isEqualTo: uid)
                          .get();
                      if (classesSnap.docs.isNotEmpty) {
                        for (var classDoc in classesSnap.docs) {
                          await classDoc.reference.delete();
                        }
                      }

                      // Delete user document
                      await FirebaseFirestore.instance.collection('users').doc(uid).delete();
                    } catch (e) {
                      debugPrint('Error deleting teacher user: $e');
                    }
                  }

                  // 2. Delete proof file from Firebase Storage
                  if (fileUrl.isNotEmpty && fileUrl.contains('firebasestorage.googleapis.com')) {
                    try {
                      final ref = FirebaseStorage.instance.refFromURL(fileUrl);
                      await ref.delete();
                    } catch (e) {
                      debugPrint('Error deleting storage file: $e');
                    }
                  }

                  // 3. Delete Firestore verification doc
                  await FirebaseFirestore.instance.collection('guru_verifikasi').doc(requestId).delete();

                  // Safely pop the loading spinner from the root navigator
                  try {
                    rootNavigator.pop();
                  } catch (_) {}

                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Permohonan verifikasi dan akun guru berhasil dihapus.'),
                      backgroundColor: AdminColors.success,
                    ),
                  );

                  // Go back to list page on the page/nested navigator
                  try {
                    pageNavigator.pop();
                  } catch (_) {}
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
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildGradientButton({
    required VoidCallback onPressed,
    required String text,
    required IconData icon,
    required Gradient gradient,
    required Color shadowColor,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: shadowColor.withOpacity(0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 18.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  TableRow _buildTableRow(String label, String value, IconData icon) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF64748B)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            value,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class SKDocumentPreview extends StatelessWidget {
  final String teacherName;
  final String school;
  final String subject;
  final String date;

  const SKDocumentPreview({
    super.key,
    required this.teacherName,
    required this.school,
    required this.subject,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kop Surat
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF1E3A8A).withOpacity(0.15)),
                ),
                child: const Center(
                  child: Icon(Icons.school_rounded, size: 24, color: Color(0xFF1E3A8A)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'YAYASAN EPIC SEJAHTERA',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        color: Color(0xFF1E3A8A),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Text(
                      'SD NEGERI 1 BANGKALAN',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                    Text(
                      'Jl. Letnan Mestu No. 12, Bangkalan, Jawa Timur',
                      style: TextStyle(
                        fontSize: 7.5,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Kop divider lines
          const Divider(color: Color(0xFF1E3A8A), thickness: 2, height: 4),
          const SizedBox(height: 1),
          const Divider(color: Color(0xFF1E3A8A), thickness: 0.8, height: 1),
          const SizedBox(height: 16),
          
          // Judul SK
          Center(
            child: Column(
              children: [
                const Text(
                  'SURAT KEPUTUSAN',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    decoration: TextDecoration.underline,
                    color: Color(0xFF0F172A),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Nomor: 800/104/SDN-1/VI/2026',
                  style: TextStyle(
                    fontSize: 8.5,
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          const Text(
            'TENTANG:',
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'PENGANGKATAN GURU HONORER / KONTRAK SEKOLAH',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          
          Text(
            'Menimbang, Mengingat, dan Memutuskan, terhitung mulai tanggal pendaftaran mengangkat nama di bawah ini sebagai Guru Honorer di unit kerja sekolah kami:',
            style: TextStyle(
              fontSize: 8.5,
              color: Color(0xFF475569),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          
          // Data Guru
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(2.5),
                1: FlexColumnWidth(4.5),
              },
              children: [
                _buildSKRow('Nama Guru', teacherName),
                _buildSKRow('Mata Pelajaran', subject),
                _buildSKRow('Unit Kerja', school),
                _buildSKRow('TMT Pengangkatan', date),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // Penutup
          Text(
            'Keputusan ini diberikan kepada yang bersangkutan untuk diketahui dan dilaksanakan dengan penuh rasa tanggung jawab.',
            style: TextStyle(
              fontSize: 8.5,
              color: Color(0xFF475569),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          
          // Tanda Tangan & Cap Stempel Stack
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 180,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: 14,
                    left: -12,
                    child: Opacity(
                      opacity: 0.6,
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF2563EB), width: 1.5),
                        ),
                        child: Center(
                          child: Transform.rotate(
                            angle: -0.2,
                            child: const Text(
                              'SDN 1\nBANGKALAN',
                              style: TextStyle(
                                color: Color(0xFF2563EB),
                                fontSize: 5,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ditetapkan di: Bangkalan',
                        style: TextStyle(fontSize: 8, color: Color(0xFF64748B)),
                      ),
                      Text(
                        'Pada tanggal: $date',
                        style: const TextStyle(fontSize: 8, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Kepala Sekolah SDN 1,',
                        style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      
                      Container(
                        height: 38,
                        alignment: Alignment.centerLeft,
                        child: Icon(Icons.gesture_rounded, color: Colors.blue[800]!.withOpacity(0.55), size: 28),
                      ),
                      
                      const Text(
                        'Drs. H. Mulyono, M.Pd.',
                        style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), decoration: TextDecoration.underline),
                      ),
                      const Text(
                        'NIP. 19680512 199403 1 002',
                        style: TextStyle(fontSize: 7.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  TableRow _buildSKRow(String label, String value) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
              fontSize: 8.5,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Text(
            value,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.bold,
              fontSize: 8.5,
            ),
          ),
        ),
      ],
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
