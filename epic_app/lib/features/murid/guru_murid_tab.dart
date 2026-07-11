import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:epic_app/core/constants/app_colors.dart';
import 'package:epic_app/core/constants/app_fonts.dart';
import 'package:epic_app/features/murid/guru_murid_controller.dart';
import 'package:epic_app/features/murid/profil_murid_screen.dart';

class GuruMuridTab extends StatelessWidget {
  const GuruMuridTab({super.key});

  String _formatLastActive(DateTime? dt) {
    if (dt == null) return 'Belum Aktif';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) {
      return 'Baru saja';
    } else if (diff.inHours < 24) {
      return 'Hari ini';
    } else if (diff.inDays == 1) {
      return 'Kemarin';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} hari lalu';
    } else {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
      return '${dt.day} ${months[dt.month - 1]}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(GuruMuridController());
    final searchCtrl = TextEditingController();

    final double bottomPadding = MediaQuery.of(context).padding.bottom;
    final double bottomNavHeight = 72 + (bottomPadding > 0 ? bottomPadding : 12);
    final double listBottomPadding = bottomNavHeight + 16;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF9F0),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daftar Murid',
              style: TextStyle(
                fontFamily: 'FredokaOne',
                fontSize: 22,
                color: Color(0xFF1E293B),
              ),
            ),
            Obx(() => Text(
              'Total: ${controller.filteredStudents.length} murid terdaftar',
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            )),
          ],
        ),
        centerTitle: false,
        automaticallyImplyLeading: false,
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        final students = controller.filteredStudents;

        return Column(
          children: [
            // --- HEADER FILTER & SEARCH PANEL (Floating Premium Card) ---
            Container(
              margin: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFF1F5F9)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Search Bar Input
                  TextFormField(
                    controller: searchCtrl,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                    onChanged: (val) {
                      controller.searchQuery.value = val;
                    },
                    decoration: InputDecoration(
                      hintText: 'Cari nama atau username murid...',
                      hintStyle: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 13,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
                      suffixIcon: controller.searchQuery.value.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, color: Colors.grey, size: 18),
                              onPressed: () {
                                searchCtrl.clear();
                                controller.searchQuery.value = '';
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Dropdown Filter Kelas
                  Row(
                    children: [
                      const Icon(Icons.class_rounded, size: 16, color: Color(0xFF64748B)),
                      const SizedBox(width: 8),
                      const Text(
                        'Filter:',
                        style: TextStyle(
                          fontFamily: 'FredokaOne',
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          height: 38,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: controller.selectedClassFilter.value,
                              isExpanded: true,
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary, size: 18),
                              style: const TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                              items: [
                                const DropdownMenuItem<String>(
                                  value: 'Semua',
                                  child: Text('Semua Kelas'),
                                ),
                                ...controller.classes.map((kelas) {
                                  return DropdownMenuItem<String>(
                                    value: kelas.kelasId,
                                    child: Text(kelas.namaKelas),
                                  );
                                }),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  controller.selectedClassFilter.value = val;
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // --- SORTING CHIPS ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Text(
                    'Urutkan:',
                    style: TextStyle(
                      fontFamily: 'FredokaOne',
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildSortChip(controller, 'nama', 'Nama'),
                          const SizedBox(width: 8),
                          _buildSortChip(controller, 'nilai', 'Nilai'),
                          const SizedBox(width: 8),
                          _buildSortChip(controller, 'aktif', 'Aktif'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // --- STUDENT LIST ---
            Expanded(
              child: students.isEmpty
                  ? _buildEmptyState(controller.searchQuery.value.isNotEmpty)
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(20, 4, 20, listBottomPadding),
                      physics: const BouncingScrollPhysics(),
                      itemCount: students.length,
                      itemBuilder: (context, index) {
                        final student = students[index];
                        return _buildStudentCard(context, student);
                      },
                    ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildSortChip(GuruMuridController controller, String type, String label) {
    return Obx(() {
      final isSelected = controller.sortBy.value == type;
      return GestureDetector(
        onTap: () => controller.sortBy.value = type,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'FredokaOne',
              fontSize: 11,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      );
    });
  }

  Widget _buildStudentCard(BuildContext context, StudentViewModel student) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            Get.to(() => ProfilMuridScreen(
                  muridUid: student.uid,
                  kelasName: student.namaKelas,
                  sekolah: student.namaSekolah,
                ));
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar Ring Gradasi
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFFFF7A00), Color(0xFFFFB070)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(1.5),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xFFFFF7ED),
                      backgroundImage: student.avatarUrl.isNotEmpty ? NetworkImage(student.avatarUrl) : null,
                      child: student.avatarUrl.isEmpty
                          ? Text(
                              student.nama.isNotEmpty ? student.nama[0].toUpperCase() : '?',
                              style: const TextStyle(
                                fontFamily: 'FredokaOne',
                                color: AppColors.primary,
                                fontSize: 16,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Name & Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              student.nama,
                              style: const TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1E293B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFFE8D6)),
                            ),
                            child: Text(
                              student.namaKelas,
                              style: const TextStyle(
                                fontFamily: 'FredokaOne',
                                fontSize: 10,
                                color: Color(0xFFEA580C),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Chips row
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _buildBadgeChip(
                            Icons.palette_outlined,
                            '${student.totalKarya} karya',
                            const Color(0xFF3B82F6),
                          ),
                          _buildBadgeChip(
                            Icons.star_rounded,
                            'Avg ${student.avgNilai.toStringAsFixed(0)}',
                            Colors.amber.shade700,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Last Active Right Side
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildActivePill(student.lastActiveAt),
                    const SizedBox(height: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActivePill(DateTime? lastActiveAt) {
    final text = _formatLastActive(lastActiveAt);
    final isRecent = text == 'Baru saja' || text == 'Hari ini';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isRecent ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isRecent ? const Color(0xFF22C55E) : Colors.grey.shade500,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: isRecent ? const Color(0xFF15803D) : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isSearch) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSearch ? Icons.search_off_rounded : Icons.people_outline_rounded,
              size: 72,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              isSearch ? 'Murid Tidak Ditemukan' : 'Tidak Ada Murid',
              style: const TextStyle(
                fontFamily: 'FredokaOne',
                fontSize: 18,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isSearch
                  ? 'Coba gunakan nama atau username lain.'
                  : 'Murid belum terdaftar di kelas manapun yang aktif.',
              style: AppFonts.bodySmall(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
