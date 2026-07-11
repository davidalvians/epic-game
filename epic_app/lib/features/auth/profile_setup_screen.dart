import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:epic_app/core/constants/app_colors.dart';
import 'package:epic_app/core/constants/app_fonts.dart';
import 'package:epic_app/features/auth/profile_setup_controller.dart';
import 'package:epic_app/shared/controllers/session_controller.dart';

/// Layar setup profil setelah Google Sign-In pertama kali.
/// Sesuai PRD §3.3 — Onboarding Screen.
class ProfileSetupScreen extends StatelessWidget {
  const ProfileSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(ProfileSetupController());
    final session = Get.find<SessionController>();

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8EE),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              // Header
              Center(
                child: Column(
                  children: [
                    // Avatar dari Google
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                      backgroundImage: (session.user != null && session.user!.avatarUrl.isNotEmpty)
                          ? NetworkImage(session.user!.avatarUrl)
                          : null,
                      child: (session.user == null || session.user!.avatarUrl.isEmpty)
                          ? const Icon(Icons.person, size: 40, color: AppColors.primary)
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Lengkapi Profilmu!',
                      style: AppFonts.heading2(color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Isi data di bawah agar pengalaman belajarmu lebih seru',
                      style: AppFonts.bodySmall(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ─── Nama Lengkap ─────────────────────────
              _buildLabel('Nama Lengkap', isRequired: true),
              const SizedBox(height: 8),
              _buildTextField(
                controller: ctrl.namaController,
                hint: 'Contoh: Ahmad Rizky Pratama',
                icon: Icons.person_rounded,
              ),

              const SizedBox(height: 20),

              // ─── Username ─────────────────────────────
              _buildLabel('Username', isRequired: true),
              const SizedBox(height: 8),
              Obx(() => _buildTextField(
                    controller: ctrl.usernameController,
                    hint: 'contoh: rizky_cool',
                    icon: Icons.alternate_email_rounded,
                    onChanged: ctrl.onUsernameChanged,
                    suffix: ctrl.isCheckingUsername.value
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          )
                        : ctrl.usernameController.text.isNotEmpty
                            ? Icon(
                                ctrl.isUsernameAvailable.value
                                    ? Icons.check_circle_rounded
                                    : Icons.cancel_rounded,
                                color: ctrl.isUsernameAvailable.value
                                    ? Colors.green
                                    : Colors.red,
                                size: 22,
                              )
                            : null,
                    errorText: ctrl.usernameError.value.isNotEmpty
                        ? ctrl.usernameError.value
                        : null,
                  )),

              const SizedBox(height: 20),

              // ─── Nama Sekolah ─────────────────────────
              _buildLabel('Nama Sekolah', isRequired: true),
              const SizedBox(height: 8),
              _buildTextField(
                controller: ctrl.sekolahController,
                hint: 'Contoh: SDN 1 Bangkalan',
                icon: Icons.school_rounded,
              ),

              const SizedBox(height: 24),

              // ─── Role Selection ───────────────────────
              _buildLabel('Saya adalah', isRequired: true),
              const SizedBox(height: 12),
              Obx(() => Row(
                    children: [
                      Expanded(
                        child: _buildRoleChip(
                          ctrl: ctrl,
                          label: 'Murid',
                          icon: Icons.face_rounded,
                          value: 'murid',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildRoleChip(
                          ctrl: ctrl,
                          label: 'Guru',
                          icon: Icons.school_rounded,
                          value: 'guru',
                        ),
                      ),
                    ],
                  )),

              const SizedBox(height: 24),

              // ─── Data Tambahan Murid ──────────────────
              Obx(() {
                if (ctrl.selectedRole.value == 'murid') {
                  return _buildMuridFields(ctrl);
                } else {
                  return _buildGuruFields(ctrl);
                }
              }),

              const SizedBox(height: 32),

              // ─── Submit Button ────────────────────────
              Obx(() => GestureDetector(
                    onTap: ctrl.isLoading.value ? null : ctrl.submitProfile,
                    child: Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, Color(0xFFFF6B35)],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Center(
                        child: ctrl.isLoading.value
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.check_circle_rounded,
                                      color: Colors.white, size: 22),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Simpan & Mulai!',
                                    style:
                                        AppFonts.button(color: Colors.white),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  )),

              // ─── Guru Pending Info ────────────────────
              Obx(() {
                if (ctrl.selectedRole.value == 'guru') {
                  return Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              color: Colors.blue, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Setelah mendaftar sebagai guru, akunmu akan diverifikasi oleh admin EPIC (estimasi 1x24 jam). Kamu tetap bisa bermain sebagai murid biasa sambil menunggu.',
                              style: AppFonts.caption(
                                  color: Colors.blue.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              }),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Helper Widgets ─────────────────────────────────────────────────

  Widget _buildLabel(String text, {bool isRequired = false}) {
    return Row(
      children: [
        Text(
          text,
          style: AppFonts.bodyText(
            color: AppColors.textPrimary,
            weight: FontWeight.w700,
          ),
        ),
        if (isRequired)
          const Text(' *',
              style: TextStyle(color: AppColors.error, fontSize: 16)),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    void Function(String)? onChanged,
    Widget? suffix,
    String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            style: AppFonts.bodyText(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppFonts.bodyText(color: Colors.grey.shade400),
              prefixIcon: Icon(icon, color: AppColors.primary, size: 22),
              suffixIcon: suffix != null
                  ? Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: suffix,
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 16),
            child: Text(
              errorText,
              style: AppFonts.caption(color: AppColors.error),
            ),
          ),
      ],
    );
  }

  Widget _buildRoleChip({
    required ProfileSetupController ctrl,
    required String label,
    required IconData icon,
    required String value,
  }) {
    final isSelected = ctrl.selectedRole.value == value;
    return GestureDetector(
      onTap: () => ctrl.selectedRole.value = value,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.15)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : Colors.grey,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'FredokaOne',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColors.primary : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMuridFields(ProfileSetupController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Data Tambahan (Opsional)',
          style: AppFonts.bodySmall(
            color: AppColors.textSecondary,
            weight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),

        // Kelas
        _buildLabel('Kelas'),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Obx(() => DropdownButtonFormField<String>(
                initialValue: ctrl.selectedKelas.value.isEmpty
                    ? null
                    : ctrl.selectedKelas.value,
                items: ['1 SD', '2 SD', '3 SD', '4 SD', '5 SD', '6 SD']
                    .map((k) => DropdownMenuItem(
                          value: k,
                          child: Text(k,
                              style: AppFonts.bodyText(
                                  color: AppColors.textPrimary)),
                        ))
                    .toList(),
                onChanged: (v) => ctrl.selectedKelas.value = v ?? '',
                hint: Text('Pilih kelas',
                    style: AppFonts.bodyText(color: Colors.grey.shade400)),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.class_rounded,
                      color: AppColors.primary, size: 22),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              )),
        ),

        const SizedBox(height: 16),

        // Provinsi
        _buildLabel('Provinsi'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: ctrl.provinsiController,
          hint: 'Contoh: Jawa Timur',
          icon: Icons.location_on_rounded,
        ),

        const SizedBox(height: 16),

        // Kabupaten/Kota
        _buildLabel('Kabupaten/Kota'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: ctrl.kabupatenController,
          hint: 'Contoh: Bangkalan',
          icon: Icons.location_city_rounded,
        ),

        const SizedBox(height: 16),

        // Kecamatan
        _buildLabel('Kecamatan'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: ctrl.kecamatanController,
          hint: 'Contoh: Bangkalan',
          icon: Icons.map_rounded,
        ),
      ],
    );
  }

  Widget _buildGuruFields(ProfileSetupController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Data Guru (Untuk Verifikasi)',
          style: AppFonts.bodySmall(
            color: AppColors.textSecondary,
            weight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),

        // Upload Bukti Mengajar — WAJIB
        _buildLabel('Upload Bukti Mengajar', isRequired: true),
        const SizedBox(height: 8),
        Obx(() {
          final file = ctrl.buktiFile.value;
          final fileName = ctrl.buktiFileName.value;

          if (file != null) {
            // ─── State: File Sudah Dipilih (Preview) ─────────
            return Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.green.withValues(alpha: 0.5),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Preview Gambar
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(15),
                    ),
                    child: Image.file(
                      file,
                      width: double.infinity,
                      height: 180,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: double.infinity,
                        height: 180,
                        color: Colors.grey.shade100,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.image_rounded,
                                color: Colors.grey, size: 48),
                            SizedBox(height: 8),
                            Text('Tidak bisa preview',
                                style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Info & Tombol Hapus
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            fileName,
                            style: AppFonts.bodySmall(
                              color: AppColors.textPrimary,
                              weight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Tombol ganti file
                        GestureDetector(
                          onTap: ctrl.pickBuktiFile,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.refresh_rounded,
                                    size: 16, color: AppColors.primary),
                                const SizedBox(width: 4),
                                Text('Ganti',
                                    style: AppFonts.caption(
                                        color: AppColors.primary)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Tombol hapus
                        GestureDetector(
                          onTap: ctrl.removeBuktiFile,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.close_rounded,
                                size: 16, color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          // ─── State: Belum Ada File (Upload Area) ─────────
          return GestureDetector(
            onTap: ctrl.pickBuktiFile,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  style: BorderStyle.solid,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.cloud_upload_rounded,
                        color: AppColors.primary, size: 36),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tap untuk upload bukti mengajar',
                    style: AppFonts.bodySmall(
                      color: AppColors.textPrimary,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'SK Guru / Kartu GTK / ID resmi guru',
                    style: AppFonts.caption(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Format: JPG atau PNG · Maks. 5 MB',
                    style: AppFonts.caption(color: Colors.grey.shade400),
                  ),
                ],
              ),
            ),
          );
        }),

        // Warning: wajib upload
        Padding(
          padding: const EdgeInsets.only(top: 8, left: 4),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 14, color: Colors.orange.shade700),
              const SizedBox(width: 6),
              Text(
                'Wajib diisi untuk mendaftar sebagai guru',
                style: AppFonts.caption(color: Colors.orange.shade700),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Mata Pelajaran
        _buildLabel('Mata Pelajaran'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: ctrl.mataPelajaranController,
          hint: 'Contoh: Matematika',
          icon: Icons.menu_book_rounded,
        ),
      ],
    );
  }
}
