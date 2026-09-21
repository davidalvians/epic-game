import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:epic_app/core/constants/app_colors.dart';
import 'package:epic_app/core/constants/app_fonts.dart';
import 'package:epic_app/core/utils/epic_notification.dart';
import 'package:epic_app/data/models/kelas_model.dart';
import 'package:epic_app/data/repositories/kelas_repository.dart';
import 'package:epic_app/features/kelas/kelas_detail_guru_screen.dart';
import 'package:epic_app/shared/controllers/session_controller.dart';

class GuruArchivedClassesScreen extends StatefulWidget {
  const GuruArchivedClassesScreen({super.key});

  @override
  State<GuruArchivedClassesScreen> createState() =>
      _GuruArchivedClassesScreenState();
}

class _GuruArchivedClassesScreenState extends State<GuruArchivedClassesScreen> {
  final _session = Get.find<SessionController>();
  final _kelasRepo = KelasRepository();

  bool _isLoading = true;
  List<KelasModel> _archivedClasses = [];

  @override
  void initState() {
    super.initState();
    _loadArchivedClasses();
  }

  Future<void> _loadArchivedClasses() async {
    if (mounted) setState(() => _isLoading = true);

    try {
      final uid = _session.user?.uid;
      if (uid == null) return;

      final allClasses = await _kelasRepo.getKelasByGuru(uid);
      if (!mounted) return;

      setState(() {
        _archivedClasses =
            allClasses.where((kelas) => kelas.status == 'arsip').toList();
      });
    } catch (_) {
      EpicNotification.error('Error', 'Gagal memuat kelas yang diarsipkan');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.light,
      appBar: AppBar(
        title: const Text('Kelas yang Diarsipkan'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _archivedClasses.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _loadArchivedClasses,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _archivedClasses.length,
                    itemBuilder: (context, index) =>
                        _buildArchivedClassCard(_archivedClasses[index]),
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.archive_outlined,
                  size: 64, color: AppColors.inactive),
            ),
            const SizedBox(height: 24),
            Text(
              'Belum ada kelas yang diarsipkan',
              style: AppFonts.heading3(color: AppColors.dark),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Kelas yang telah Anda arsipkan akan muncul di sini.',
              style: AppFonts.bodyText(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArchivedClassCard(KelasModel kelas) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Get.to(() => KelasDetailGuruScreen(kelas: kelas)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.inventory_2_outlined,
                      color: Color(0xFF64748B)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(kelas.namaKelas,
                          style: AppFonts.heading3(
                              color: const Color(0xFF334155))),
                      const SizedBox(height: 6),
                      Text(
                        '${kelas.tahunAjaran} • ${kelas.jumlahMurid} murid',
                        style: AppFonts.caption(color: const Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Arsip • hanya dapat dilihat',
                        style: AppFonts.caption(color: const Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFF94A3B8)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
