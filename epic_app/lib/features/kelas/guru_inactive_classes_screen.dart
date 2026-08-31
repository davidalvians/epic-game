import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:epic_app/core/constants/app_colors.dart';
import 'package:epic_app/core/constants/app_fonts.dart';
import 'package:epic_app/core/utils/epic_notification.dart';
import 'package:epic_app/data/models/kelas_model.dart';
import 'package:epic_app/features/kelas/kelas_controller.dart';
import 'package:epic_app/shared/controllers/session_controller.dart';
import 'package:epic_app/data/repositories/kelas_repository.dart';

class GuruInactiveClassesScreen extends StatefulWidget {
  const GuruInactiveClassesScreen({super.key});

  @override
  State<GuruInactiveClassesScreen> createState() => _GuruInactiveClassesScreenState();
}

class _GuruInactiveClassesScreenState extends State<GuruInactiveClassesScreen> {
  final _session = Get.find<SessionController>();
  final _kelasRepo = KelasRepository();
  bool _isLoading = true;
  List<KelasModel> _inactiveClasses = [];

  @override
  void initState() {
    super.initState();
    _loadInactiveClasses();
  }

  Future<void> _loadInactiveClasses() async {
    setState(() => _isLoading = true);
    try {
      final uid = _session.user?.uid;
      if (uid == null) return;

      final allClasses = await _kelasRepo.getKelasByGuru(uid);
      setState(() {
        _inactiveClasses = allClasses.where((k) => k.status == 'nonaktif').toList();
      });
    } catch (e) {
      EpicNotification.error('Error', 'Gagal memuat kelas nonaktif');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _restoreKelas(KelasModel kelas) async {
    final ctrl = Get.put(KelasController());
    await ctrl.toggleStatusKelas(kelas.kelasId, true);
    await _loadInactiveClasses(); // Refresh
  }

  Future<void> _deleteKelasPermanently(KelasModel kelas) async {
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Hapus Permanen?'),
        content: Text('Anda yakin ingin menghapus kelas "${kelas.namaKelas}" secara permanen? Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus Permanen'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final ctrl = Get.put(KelasController());
      await ctrl.deleteKelasPermanen(kelas.kelasId);
      await _loadInactiveClasses(); // Refresh
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.light,
      appBar: AppBar(
        title: const Text('Kelas Nonaktif'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _inactiveClasses.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _loadInactiveClasses,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _inactiveClasses.length,
                    itemBuilder: (context, index) {
                      final kelas = _inactiveClasses[index];
                      return _buildInactiveClassCard(kelas);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
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
              child: const Icon(Icons.power_off_rounded,
                  size: 64, color: AppColors.inactive),
            ),
            const SizedBox(height: 24),
            Text(
              'Tidak ada kelas nonaktif',
              style: AppFonts.heading3(color: AppColors.dark),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Kelas yang Anda nonaktifkan akan muncul di sini.',
              style: AppFonts.bodyText(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInactiveClassCard(KelasModel kelas) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.class_rounded, color: Colors.grey),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        kelas.namaKelas,
                        style: AppFonts.heading3(color: Colors.grey[800]),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.vpn_key_rounded, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            kelas.kodeKelas,
                            style: AppFonts.caption(color: Colors.grey[600]),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.people_alt_rounded, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            '${kelas.jumlahMurid} Murid',
                            style: AppFonts.caption(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _restoreKelas(kelas),
                    icon: const Icon(Icons.restore_rounded, color: AppColors.primary),
                    label: const Text('Aktifkan Kembali', style: TextStyle(color: AppColors.primary)),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _deleteKelasPermanently(kelas),
                    icon: const Icon(Icons.delete_forever_rounded, color: AppColors.error),
                    label: const Text('Hapus Permanen', style: TextStyle(color: AppColors.error)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
