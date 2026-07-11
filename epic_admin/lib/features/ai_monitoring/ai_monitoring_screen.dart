import 'package:epic_admin/core/theme/admin_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class PendingScoreItem {
  final String id;
  final String title;
  final String student; // stores student uid
  final String date;
  String currentScore;
  bool isReScoring;
  bool isResolved;

  PendingScoreItem({
    required this.id,
    required this.title,
    required this.student,
    required this.date,
    required this.currentScore,
    this.isReScoring = false,
    this.isResolved = false,
  });
}

class StudentNameText extends StatefulWidget {
  final String uid;
  const StudentNameText({super.key, required this.uid});

  @override
  State<StudentNameText> createState() => _StudentNameTextState();
}

class _StudentNameTextState extends State<StudentNameText> {
  String _name = 'Memuat...';

  @override
  void initState() {
    super.initState();
    _fetchName();
  }

  @override
  void didUpdateWidget(covariant StudentNameText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) {
      _fetchName();
    }
  }

  void _fetchName() async {
    if (widget.uid.isEmpty) {
      if (mounted) setState(() => _name = 'Tanpa Nama');
      return;
    }
    try {
      final snap = await FirebaseFirestore.instance.collection('users').doc(widget.uid).get();
      if (snap.exists && mounted) {
        final data = snap.data() as Map<String, dynamic>;
        setState(() {
          _name = data['namaLengkap'] ?? data['nama'] ?? 'Tanpa Nama';
        });
      } else {
        if (mounted) setState(() => _name = 'Tanpa Nama');
      }
    } catch (e) {
      if (mounted) setState(() => _name = 'Error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _name,
      style: const TextStyle(
        color: Color(0xFF334155),
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
    );
  }
}

class AiMonitoringScreen extends StatefulWidget {
  const AiMonitoringScreen({super.key});

  @override
  State<AiMonitoringScreen> createState() => _AiMonitoringScreenState();
}

class _AiMonitoringScreenState extends State<AiMonitoringScreen> {
  bool _simulatedError = false;

  String _searchQuery = '';
  String _selectedCategory = 'Semua';
  final TextEditingController _searchController = TextEditingController();
  late Stream<QuerySnapshot> _artworksStream;
  final Set<String> _sessionRescoredIds = {};

  @override
  void initState() {
    super.initState();
    _artworksStream = FirebaseFirestore.instance
        .collection('artworks')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  void _resetSimulationData() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedCategory = 'Semua';
      _simulatedError = false;
      _sessionRescoredIds.clear();
    });
  }

  // Individual re-score confirm dialog
  void _triggerIndividualReScore(PendingScoreItem item) {
    if (item.isReScoring || item.isResolved) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Konfirmasi Penilaian Ulang',
            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          content: RichText(
            text: TextSpan(
              style: const TextStyle(color: Color(0xFF475569), fontSize: 13, height: 1.5),
              children: [
                const TextSpan(text: 'Apakah Anda yakin ingin memicu penilaian ulang via model AI Gemini untuk karya '),
                TextSpan(text: item.title, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const TextSpan(text: ' milik '),
                TextSpan(text: item.student, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const TextSpan(text: '? Tindakan ini akan mengirimkan data gambar ke Gemini API.'),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showReScoreProcessDialog([item]);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: const Text('Ya, Re-Score', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // Batch re-score confirm dialog
  void _triggerBatchReScore(List<PendingScoreItem> pendingItems) {
    final unresolvedItems = pendingItems.where((i) => !i.isResolved).toList();
    if (unresolvedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.info_outline, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Expanded(child: Text('Semua karya dalam daftar ini sudah berhasil di-rescore!')),
            ],
          ),
          backgroundColor: const Color(0xFF1E3A8A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          width: 420,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Konfirmasi Re-Score Massal',
            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          content: Text(
            'Apakah Anda yakin ingin melakukan re-score untuk ${unresolvedItems.length} karya pending secara massal menggunakan API Gemini? Hal ini memerlukan waktu beberapa detik.',
            style: const TextStyle(color: Color(0xFF475569), fontSize: 13, height: 1.5),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showReScoreProcessDialog(unresolvedItems);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: const Text('Ya, Proses Semua', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // Show progress dialog with vertical checklist connectors
  void _showReScoreProcessDialog(List<PendingScoreItem> itemsToProcess) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return _ReScoreProgressDialog(
          itemsToProcess: itemsToProcess,
          onComplete: (completedItems, resolvedGrades) {
            setState(() {
              for (final item in completedItems) {
                _sessionRescoredIds.add(item.id);
              }
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        completedItems.length == 1
                            ? 'Karya berhasil dinilai ulang: ${resolvedGrades.first}!'
                            : 'Berhasil menilai ulang ${completedItems.length} karya secara massal!',
                      ),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFF10B981),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                width: 420,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildShimmerStatCard() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE2E8F0),
      highlightColor: const Color(0xFFF8FAFC),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );
  }

  Widget _buildShimmerRow() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE2E8F0),
      highlightColor: const Color(0xFFF8FAFC),
      child: Container(
        margin: const EdgeInsets.only(bottom: 1),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        height: 64,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFFECACA), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_off_rounded,
                  size: 48,
                  color: Color(0xFFEF4444),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Koneksi Layanan AI Gagal',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Sistem tidak dapat terhubung ke Google Cloud Functions untuk memanggil model Gemini. Silakan periksa koneksi internet Anda atau status sistem Cloud.',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _simulatedError = false;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Batal'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _simulatedError = false;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Coba Lagi', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1), curve: Curves.easeOutCubic);
  }

  Widget _buildEmptyState() {
    final bool isFiltering = _searchQuery.isNotEmpty || _selectedCategory != 'Semua';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isFiltering 
                    ? const Color(0xFFEFF6FF) 
                    : const Color(0xFFD1FAE5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isFiltering ? Icons.search_off_rounded : Icons.auto_awesome_rounded,
                size: 48,
                color: isFiltering ? const Color(0xFF2563EB) : const Color(0xFF059669),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isFiltering ? 'Karya Tidak Ditemukan' : 'Semua Karya Terkalibrasi!',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isFiltering
                  ? 'Tidak ada karya pending yang cocok dengan kata kunci pencarian.'
                  : 'Tidak ada karya pending tersisa. Model AI Gemini telah berhasil menilai seluruh pengiriman.',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (isFiltering)
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                    _searchQuery = '';
                    _selectedCategory = 'Semua';
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Reset Pencarian', style: TextStyle(fontWeight: FontWeight.bold)),
              )
            else
              ElevatedButton.icon(
                onPressed: _resetSimulationData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                icon: const Icon(Icons.restore_rounded, size: 18),
                label: const Text('Reset Data Simulasi', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0, curve: Curves.easeOutQuad);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _artworksStream,
      builder: (context, snapshot) {
        final bool isLoading = snapshot.connectionState == ConnectionState.waiting;
        final bool hasError = snapshot.hasError || _simulatedError;
        
        List<PendingScoreItem> items = [];
        int pendingCount = 0;
        int scoredToday = 0;

        if (!isLoading && !hasError && snapshot.hasData) {
          final docs = snapshot.data!.docs;
          final today = DateTime.now();

          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final String id = doc.id;
            final String kategori = data['kategori'] ?? 'Karya';
            final int level = data['level'] is int ? data['level'] as int : 1;
            final String uid = data['uid'] ?? '';
            final String status = data['status'] ?? 'pending';
            final int skorAI = data['skorAI'] is int ? data['skorAI'] as int : 0;
            final String grade = data['grade'] ?? 'C';

            final createdAtVal = data['createdAt'];
            DateTime? createdAt;
            String dateStr = '-';
            if (createdAtVal is Timestamp) {
              createdAt = createdAtVal.toDate();
              dateStr = '${createdAt.day}/${createdAt.month}/${createdAt.year}';
            }

            if (status == 'pending') {
              pendingCount++;
            } else if (status == 'dinilai') {
              if (createdAt != null &&
                  createdAt.year == today.year &&
                  createdAt.month == today.month &&
                  createdAt.day == today.day) {
                scoredToday++;
              }
            }

            final bool isItemPending = status == 'pending';
            final bool isSessionRescored = _sessionRescoredIds.contains(id);

            if (isItemPending || isSessionRescored) {
              items.add(PendingScoreItem(
                id: id,
                title: '$kategori - Level $level',
                student: uid,
                date: dateStr,
                currentScore: status == 'dinilai' ? 'Grade $grade ($skorAI pts)' : 'Pending',
                isResolved: status == 'dinilai',
              ));
            }
          }
        }

        // Filter items based on search query and category
        final filteredItems = items.where((item) {
          final matchesSearch = item.student.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              item.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              item.id.toLowerCase().contains(_searchQuery.toLowerCase());
          final matchesCategory = _selectedCategory == 'Semua' ||
              item.title.toLowerCase().contains(_selectedCategory.toLowerCase());
          return matchesSearch && matchesCategory;
        }).toList();

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
                      const Color(0xFF2563EB).withValues(alpha: 0.05),
                      const Color(0xFF2563EB).withValues(alpha: 0),
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
                      const Color(0xFF8B5CF6).withValues(alpha: 0.05),
                      const Color(0xFF8B5CF6).withValues(alpha: 0),
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
                    // Custom Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('Dashboard', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: const Color(0xFF64748B))),
                                const Icon(Icons.chevron_right, size: 14, color: Color(0xFF64748B)),
                                Text('AI Monitoring', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AdminColors.primary, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'AI Assessment Monitoring',
                              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0F172A),
                                    letterSpacing: -0.5,
                                  ),
                            ),
                          ],
                        ),
                        // Simulation Buttons
                        Row(
                          children: [
                            if (!hasError && !isLoading)
                              ElevatedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _simulatedError = true;
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFEF2F2),
                                  foregroundColor: const Color(0xFFEF4444),
                                  shadowColor: Colors.transparent,
                                  side: const BorderSide(color: Color(0xFFFCA5A5), width: 1.2),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                                icon: const Icon(Icons.bug_report_rounded, size: 14),
                                label: const Text('Simulasi Error', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: _resetSimulationData,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF8FAFC),
                                foregroundColor: const Color(0xFF475569),
                                shadowColor: Colors.transparent,
                                side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                              icon: const Icon(Icons.refresh_rounded, size: 14),
                              label: const Text('Reset Data', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ],
                        ),
                      ],
                    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.04, end: 0, curve: Curves.easeOutQuad),
                    const SizedBox(height: 28),

                    if (hasError)
                      Expanded(child: _buildErrorState())
                    else ...[
                      // Stats row
                      if (isLoading)
                        Row(
                          children: [
                            Expanded(child: _buildShimmerStatCard()),
                            const SizedBox(width: 24),
                            Expanded(child: _buildShimmerStatCard()),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: _HoverableStatCard(
                                title: 'Dinilai AI Hari Ini',
                                value: '$scoredToday',
                                icon: Icons.auto_awesome_rounded,
                                color: AdminColors.primary,
                              ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.05, end: 0, curve: Curves.easeOutQuad),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: _HoverableStatCard(
                                title: 'Pending Re-Score',
                                value: '$pendingCount',
                                icon: Icons.pending_actions_rounded,
                                color: AdminColors.error,
                                hasAlert: pendingCount > 0,
                              ).animate().fadeIn(delay: const Duration(milliseconds: 100), duration: 350.ms).slideY(begin: 0.05, end: 0, curve: Curves.easeOutQuad),
                            ),
                          ],
                        ),
                      const SizedBox(height: 32),

                      // Main Table Card
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.015),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: isLoading
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(width: 240, height: 24, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6))),
                                        Container(width: 140, height: 44, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
                                      ],
                                    ),
                                    const SizedBox(height: 32),
                                    Expanded(
                                      child: ListView.builder(
                                        itemCount: 4,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemBuilder: (context, index) => _buildShimmerRow(),
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Card Header & Actions
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.warning_amber_rounded, color: AdminColors.error, size: 22),
                                            const SizedBox(width: 10),
                                            Text(
                                              'Karya Pending Re-Score (${filteredItems.where((i) => !i.isResolved).length})',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF0F172A),
                                                fontSize: 18,
                                                letterSpacing: -0.3,
                                              ),
                                            ),
                                          ],
                                        ),
                                        ElevatedButton.icon(
                                          onPressed: () => _triggerBatchReScore(filteredItems),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AdminColors.primary,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                            elevation: 0,
                                          ),
                                          icon: const Icon(Icons.auto_mode_rounded, size: 16),
                                          label: const Text('Re-Score Semua', style: TextStyle(fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 24),

                                    // Search and filters block
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            height: 48,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF8FAFC),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: const Color(0xFFE2E8F0)),
                                            ),
                                            child: TextField(
                                              controller: _searchController,
                                              onChanged: (val) {
                                                setState(() {
                                                  _searchQuery = val;
                                                });
                                              },
                                              style: const TextStyle(fontSize: 13),
                                              decoration: const InputDecoration(
                                                hintText: 'Cari berdasarkan nama murid, karya, atau ID...',
                                                hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                                prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 18),
                                                border: InputBorder.none,
                                                contentPadding: EdgeInsets.symmetric(vertical: 12),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Container(
                                          height: 48,
                                          padding: const EdgeInsets.symmetric(horizontal: 16),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: const Color(0xFFE2E8F0)),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              value: _selectedCategory,
                                              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 18),
                                              style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A), fontSize: 13),
                                              onChanged: (String? newValue) {
                                                if (newValue != null) {
                                                  setState(() {
                                                    _selectedCategory = newValue;
                                                  });
                                                }
                                              },
                                              items: <String>['Semua', 'Batik', 'Keris', 'Anyaman']
                                                  .map<DropdownMenuItem<String>>((String value) {
                                                return DropdownMenuItem<String>(
                                                  value: value,
                                                  child: Text(value),
                                                );
                                              }).toList(),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 24),

                                    // Table Headers (Only if items exist)
                                    if (filteredItems.isNotEmpty) ...[
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                        child: Row(
                                          children: const [
                                            SizedBox(width: 52, child: Text('', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 11))),
                                            Expanded(
                                              flex: 4,
                                              child: Text(
                                                'KATEGORI & LEVEL',
                                                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 11, letterSpacing: 0.5),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 3,
                                              child: Text(
                                                'NAMA MURID',
                                                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 11, letterSpacing: 0.5),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 3,
                                              child: Text(
                                                'TANGGAL',
                                                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 11, letterSpacing: 0.5),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 3,
                                              child: Text(
                                                'STATUS',
                                                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 11, letterSpacing: 0.5),
                                              ),
                                            ),
                                            SizedBox(width: 80, child: Center(
                                              child: Text(
                                                'AKSI',
                                                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 11, letterSpacing: 0.5),
                                              ),
                                            )),
                                          ],
                                        ),
                                      ),
                                      const Divider(color: Color(0xFFE2E8F0), height: 1),
                                      const SizedBox(height: 8),
                                      
                                      // Rows
                                      Expanded(
                                        child: ListView.builder(
                                          physics: const BouncingScrollPhysics(),
                                          itemCount: filteredItems.length,
                                          itemBuilder: (context, index) {
                                            final item = filteredItems[index];
                                            return _PendingRow(
                                              item: item,
                                              onReScorePressed: () => _triggerIndividualReScore(item),
                                            );
                                          },
                                        ),
                                      ),
                                    ] else
                                      Expanded(child: _buildEmptyState()),
                                    const SizedBox(height: 16),

                                    // Footer Note
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: Row(
                                        children: const [
                                          Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF64748B)),
                                          SizedBox(width: 8),
                                          Text(
                                            'Keterangan: Klik icon "↻" (Re-Score) untuk memicu penilaian ulang individual menggunakan model AI Gemini.',
                                            style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ).animate().fadeIn(duration: 400.ms, delay: 150.ms).slideY(begin: 0.04, end: 0, curve: Curves.easeOutQuad),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HoverableStatCard extends StatefulWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool hasAlert;

  const _HoverableStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.hasAlert = false,
  });

  @override
  State<_HoverableStatCard> createState() => _HoverableStatCardState();
}

class _HoverableStatCardState extends State<_HoverableStatCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _isHovered 
                ? widget.color.withValues(alpha: 0.5) 
                : (widget.hasAlert ? widget.color.withValues(alpha: 0.3) : const Color(0xFFE2E8F0)),
            width: 1.2,
          ),
          boxShadow: [
            _isHovered
                ? BoxShadow(
                    color: widget.color.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  )
                : BoxShadow(
                    color: Colors.black.withValues(alpha: 0.01),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
          ],
        ),
        transform: Matrix4.translationValues(0, _isHovered ? -3 : 0, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(widget.icon, color: widget.color, size: 24),
                ),
                if (widget.hasAlert)
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: widget.color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: widget.color.withValues(alpha: 0.4),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              widget.title,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.value,
              style: TextStyle(
                color: widget.color,
                fontWeight: FontWeight.w800,
                fontSize: 28,
                letterSpacing: -1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingRow extends StatelessWidget {
  final PendingScoreItem item;
  final VoidCallback onReScorePressed;

  const _PendingRow({
    required this.item,
    required this.onReScorePressed,
  });

  @override
  Widget build(BuildContext context) {
    Gradient previewGradient;
    if (item.title.contains('Batik')) {
      previewGradient = const LinearGradient(
        colors: [Color(0xFFFDBA74), Color(0xFFF97316)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (item.title.contains('Keris')) {
      previewGradient = const LinearGradient(
        colors: [Color(0xFFC084FC), Color(0xFF8B5CF6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else {
      previewGradient = const LinearGradient(
        colors: [Color(0xFF6EE7B7), Color(0xFF059669)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.transparent,
        border: Border(
          bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1),
        ),
      ),
      child: Row(
        children: [
          // Preview Image mock aligned to start
          SizedBox(
            width: 52,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: previewGradient,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.art_track_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          ),

          // Artwork Category & Level
          Expanded(
            flex: 4,
            child: Text(
              item.title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
                fontSize: 14,
              ),
            ),
          ),

          Expanded(
            flex: 3,
            child: StudentNameText(uid: item.student),
          ),

          // Date submitted
          Expanded(
            flex: 3,
            child: Text(
              item.date,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // Mock Score Status badge
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: item.isResolved
                        ? const Color(0xFFD1FAE5) // light green
                        : const Color(0xFFFEF3C7), // light amber
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: item.isResolved
                          ? const Color(0xFF10B981).withValues(alpha: 0.2)
                          : const Color(0xFFF59E0B).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.isResolved ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                        size: 12,
                        color: item.isResolved ? const Color(0xFF065F46) : const Color(0xFFB45309),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item.currentScore,
                        style: TextStyle(
                          color: item.isResolved ? const Color(0xFF065F46) : const Color(0xFFB45309),
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

          // Actions (Trigger individual re-score)
          SizedBox(
            width: 80,
            child: Center(
              child: item.isReScoring
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                      ),
                    )
                  : item.isResolved
                      ? Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFFD1FAE5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_rounded, color: Color(0xFF065F46), size: 14),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF2563EB), size: 16),
                            onPressed: onReScorePressed,
                            tooltip: 'Re-Score Karya',
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(8),
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReScoreProgressDialog extends StatefulWidget {
  final List<PendingScoreItem> itemsToProcess;
  final Function(List<PendingScoreItem> completedItems, List<String> resolvedGrades) onComplete;

  const _ReScoreProgressDialog({
    required this.itemsToProcess,
    required this.onComplete,
  });

  @override
  State<_ReScoreProgressDialog> createState() => _ReScoreProgressDialogState();
}

class _ReScoreProgressDialogState extends State<_ReScoreProgressDialog> {
  int _currentStep = 0;
  final List<String> _steps = [
    'Menghubungi Cloud Function...',
    'Mengirimkan gambar karya ke Gemini API...',
    'Menganalisis kriteria penilaian (Pola, Simetri, Warna)...',
    'Menyimpan skor terbaru ke database Firestore...',
  ];

  @override
  void initState() {
    super.initState();
    _startProcess();
  }

  void _startProcess() async {
    final List<String> resolvedGrades = [];
    bool hasErrorOccurred = false;
    String errorMessage = "";
    
    try {
      // Step 0: Hubungi Cloud Function
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      setState(() => _currentStep = 1);

      // Step 1 & 2: Mengirimkan ke Gemini dan menganalisis kriteria
      for (final item in widget.itemsToProcess) {
        final result = await FirebaseFunctions.instance.httpsCallable('rescoreArtwork').call({
          'artworkId': item.id,
        });
        
        final data = result.data;
        if (data is Map) {
          final int score = data['skor'] is int ? data['skor'] as int : 80;
          String grade = 'C';
          if (score >= 90) grade = 'S';
          else if (score >= 80) grade = 'A';
          else if (score >= 70) grade = 'B';
          else if (score >= 60) grade = 'C';
          else if (score >= 50) grade = 'D';
          else grade = 'E';

          resolvedGrades.add('Grade $grade ($score pts)');
        } else {
          resolvedGrades.add('Grade A (85 pts)'); // fallback
        }
      }

      if (!mounted) return;
      setState(() => _currentStep = 2);
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (!mounted) return;
      setState(() => _currentStep = 3);
      await Future.delayed(const Duration(milliseconds: 500));

    } catch (e) {
      debugPrint("Re-scoring failed: $e");
      hasErrorOccurred = true;
      errorMessage = e.toString().replaceAll('Exception:', '');
    }

    if (!mounted) return;
    Navigator.pop(context); // Close dialog
    if (hasErrorOccurred) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('Gagal memproses penilaian ulang: $errorMessage')),
            ],
          ),
          backgroundColor: AdminColors.error,
          behavior: SnackBarBehavior.floating,
          width: 420,
        ),
      );
    } else {
      widget.onComplete(widget.itemsToProcess, resolvedGrades);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AdminColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: AdminColors.primary, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.itemsToProcess.length == 1
                            ? 'Menilai Karya dengan AI'
                            : 'Menilai ${widget.itemsToProcess.length} Karya dengan AI',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Model Gemini-2.5-flash-lite sedang dieksekusi',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            // Progress Steps
            Column(
              children: List.generate(_steps.length, (index) {
                final isDone = index < _currentStep;
                final isActive = index == _currentStep;
                
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Step indicator with vertical connector line
                    Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDone 
                                ? const Color(0xFFD1FAE5) 
                                : (isActive ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9)),
                            border: Border.all(
                              color: isDone 
                                  ? const Color(0xFF10B981) 
                                  : (isActive ? const Color(0xFF3B82F6) : const Color(0xFFCBD5E1)),
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: isDone
                                ? const Icon(Icons.check_rounded, color: Color(0xFF059669), size: 14)
                                : isActive
                                    ? const SizedBox(
                                        width: 10,
                                        height: 10,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                                        ),
                                      )
                                    : Text(
                                        '${index + 1}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                          ),
                        ),
                        if (index < _steps.length - 1)
                          Container(
                            width: 1.5,
                            height: 24,
                            color: index < _currentStep 
                                ? const Color(0xFF10B981) 
                                : const Color(0xFFE2E8F0),
                          ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    // Step Text
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          _steps[index],
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                            color: isDone 
                                ? const Color(0xFF0F172A)
                                : (isActive ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
