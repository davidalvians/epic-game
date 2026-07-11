import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:epic_app/core/constants/app_colors.dart';
import 'package:epic_app/core/routes/app_routes.dart';
import 'package:epic_app/features/profile/profile_controller.dart';
import 'package:epic_app/shared/controllers/session_controller.dart';
import 'package:epic_app/shared/widgets/user_avatar_widget.dart';
import 'package:epic_app/features/profile/avatar_picker_controller.dart';
import 'package:epic_app/features/profile/settings/edit_profile/edit_profile_screen.dart' as epic_edit_profile;
import 'package:epic_app/features/profile/settings/edit_school/edit_school_screen.dart' as epic_edit_school;
import 'package:epic_app/features/profile/settings/game_settings/game_settings_screen.dart' as epic_game_settings;
import 'package:epic_app/features/kelas/guru_inactive_classes_screen.dart' as epic_guru_inactive;
import 'package:epic_app/data/repositories/kelas_repository.dart';
import 'package:epic_app/data/models/kelas_model.dart';
import 'package:epic_app/features/profile/settings/keamanan_akun_screen.dart' as epic_security;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutQuart,
    ));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animController.forward();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ProfileController());
    final avatarController = Get.put(AvatarPickerController());
    final session = Get.find<SessionController>();

    return Scaffold(
      backgroundColor: const Color(0xFFFFF9F0),
      body: Obx(() {
        final user = controller.user;

        if (session.isLoading.value) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        if (user == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person_off_rounded, size: 80, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('Sesi telah berakhir atau tidak ditemukan.', style: TextStyle(fontFamily: 'Nunito', fontSize: 16)),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Get.offAllNamed(Routes.auth),
                  child: const Text('Login Ulang'),
                ),
              ],
            ),
          );
        }

        return Stack(
          children: [
            // 1. Mesh Gradient Background
            _buildMeshBackground(context),

            // 2. Konten Utama (Overlapping & Animasi)
            FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 130),
                    child: Column(
                      children: [
                        // Judul Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.person_outline_rounded, color: Color(0xFFFF7A00), size: 24),
                            const SizedBox(width: 8),
                            Text(
                              'Profil Saya',
                              style: TextStyle(
                                fontFamily: 'FredokaOne',
                                fontSize: 20,
                                color: const Color(0xFF1E293B),
                                shadows: [
                                  Shadow(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    offset: const Offset(0, 2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),

                        // Glassmorphic Profile Card
                        ClipRRect(
                          borderRadius: BorderRadius.circular(32),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(32),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF9E7777).withValues(alpha: 0.04),
                                    blurRadius: 30,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  // Foto Profil dengan Premium Ring Glow
                                  GestureDetector(
                                    onTap: () => avatarController.showPickerDialog(),
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      alignment: Alignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: const Color(0xFFFFB03A),
                                              width: 3.5,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFFFFB03A).withValues(alpha: 0.25),
                                                blurRadius: 18,
                                                spreadRadius: 2,
                                              ),
                                            ],
                                          ),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.white, width: 4),
                                            ),
                                            child: UserAvatarWidget(
                                              avatarUrl: session.currentUser.value?.avatarUrl,
                                              name: user.namaPanggilan.isNotEmpty
                                                  ? user.namaPanggilan
                                                  : user.namaLengkap,
                                              radius: 50,
                                              borderColor: Colors.transparent,
                                              borderWidth: 0,
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 2,
                                          right: 2,
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFB03A),
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.white, width: 3),
                                              boxShadow: const [
                                                BoxShadow(
                                                  color: Colors.black12,
                                                  blurRadius: 4,
                                                  offset: Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Identitas User
                                  Text(
                                    user.namaLengkap,
                                    style: const TextStyle(
                                      fontFamily: 'FredokaOne',
                                      fontSize: 22,
                                      color: Color(0xFF1E293B),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  if (user.username.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        '@${user.username}',
                                        style: const TextStyle(
                                          fontFamily: 'Nunito',
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ),

                                  // Role Badge (Khusus Guru Terverifikasi)
                                  if (user.role == 'guru') ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDCFCE7),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: const Color(0xFFBBF7D0)),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.verified_user_rounded, color: Color(0xFF16A34A), size: 14),
                                          SizedBox(width: 4),
                                          Text(
                                            '🎓 Guru Terverifikasi',
                                            style: TextStyle(
                                              fontFamily: 'FredokaOne',
                                              fontSize: 11,
                                              color: Color(0xFF16A34A),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],

                                  const SizedBox(height: 8),
                                  // Teks info Email / Sekolah
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Text(
                                      user.role == 'guru' && user.sekolah.isNotEmpty
                                          ? user.sekolah
                                          : user.email,
                                      style: const TextStyle(
                                        fontFamily: 'Nunito',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Stats Card (Poin & Nyawa / Kelas & Murid)
                        if (user.role != 'guru')
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(color: const Color(0xFFE2D5C8)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 30,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // Info Sekolah & Kelas Murid
                                if (user.sekolah.isNotEmpty)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    margin: const EdgeInsets.only(bottom: 14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF7ED),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: const Color(0xFFFED7AA)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.school_outlined, color: Color(0xFFFF7A00), size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            user.sekolah,
                                            style: const TextStyle(
                                              fontFamily: 'Nunito',
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFFEA580C),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (user.kelas.isNotEmpty)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFF7A00).withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              user.kelas,
                                              style: const TextStyle(
                                                fontFamily: 'FredokaOne',
                                                fontSize: 11,
                                                color: Color(0xFFFF7A00),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),

                                // Poin & Nyawa Boxes
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildStatBox(
                                        icon: Icons.stars_rounded,
                                        iconColor: Colors.white,
                                        bgColor: const Color(0xFFFFF7ED),
                                        label: 'Total Poin',
                                        value: '${user.poin}',
                                        isWhiteText: true,
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFFF97316), Color(0xFFFFB03A)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildStatBox(
                                        icon: Icons.favorite_rounded,
                                        iconColor: Colors.white,
                                        bgColor: const Color(0xFFFFF1F2),
                                        label: 'Nyawa Hari Ini',
                                        value: '${user.nyawaEfektif}',
                                        isWhiteText: true,
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFFEF4444), Color(0xFFFF7675)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          )
                        else
                          StreamBuilder<List<KelasModel>>(
                            stream: KelasRepository().watchKelasByGuru(user.uid),
                            builder: (context, snap) {
                              final classes = snap.data ?? [];
                              final activeCount = classes.where((k) => k.isActive).length;
                              final totalMurid = classes.where((k) => k.isActive).expand((k) => k.muridIds).toSet().length;

                              return Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(color: const Color(0xFFE2D5C8)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 30,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _buildStatBox(
                                        icon: Icons.class_rounded,
                                        iconColor: Colors.white,
                                        bgColor: const Color(0xFFFFF7ED),
                                        label: 'Kelas Aktif',
                                        value: '$activeCount',
                                        isWhiteText: true,
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF10B981), Color(0xFF059669)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildStatBox(
                                        icon: Icons.people_alt_rounded,
                                        iconColor: Colors.white,
                                        bgColor: const Color(0xFFEFF6FF),
                                        label: 'Total Murid',
                                        value: '$totalMurid',
                                        isWhiteText: true,
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        const SizedBox(height: 24),

                        // Grouped Menu Settings
                        if (user.role != 'guru') ...[
                          // --- Murid Menu Groups ---
                          _buildSectionHeader('⚙️  PENGATURAN'),
                          const SizedBox(height: 8),
                          Container(
                            decoration: _buildMenuContainerDecoration(),
                            child: Column(
                              children: [
                                _buildMenuItem(
                                  icon: Icons.person_outline_rounded,
                                  title: 'Edit Profil',
                                  subtitle: 'Ganti nama, username, dan info dasar',
                                  iconColor: const Color(0xFF4F46E5),
                                  iconBgColor: const Color(0xFFEEF2FF),
                                  onTap: () => Get.to(() => const epic_edit_profile.EditProfileScreen()),
                                ),
                                const Divider(height: 1, color: Color(0xFFF1F5F9), indent: 76, endIndent: 20),
                                _buildMenuItem(
                                  icon: Icons.school_outlined,
                                  title: 'Data Sekolah',
                                  subtitle: 'Ubah informasi sekolah dan domisilimu',
                                  iconColor: const Color(0xFFD97706),
                                  iconBgColor: const Color(0xFFFFF7ED),
                                  onTap: () => Get.to(() => const epic_edit_school.EditSchoolScreen()),
                                ),
                                const Divider(height: 1, color: Color(0xFFF1F5F9), indent: 76, endIndent: 20),
                                _buildMenuItem(
                                  icon: Icons.class_outlined,
                                  title: 'Ruang Kelas Saya',
                                  subtitle: 'Gabung ke kelas guru',
                                  iconColor: const Color(0xFF059669),
                                  iconBgColor: const Color(0xFFECFDF5),
                                  onTap: () => Get.toNamed(Routes.kelas),
                                ),
                                const Divider(height: 1, color: Color(0xFFF1F5F9), indent: 76, endIndent: 20),
                                _buildMenuItem(
                                  icon: Icons.settings_outlined,
                                  title: 'Pengaturan Game',
                                  subtitle: 'Efek suara dan musik',
                                  iconColor: const Color(0xFFDB2777),
                                  iconBgColor: const Color(0xFFFDF2F8),
                                  onTap: () => Get.to(() => const epic_game_settings.GameSettingsScreen()),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          _buildSectionHeader('ℹ️  INFO LAINNYA'),
                          const SizedBox(height: 8),
                          Container(
                            decoration: _buildMenuContainerDecoration(),
                            child: _buildMenuItem(
                              icon: Icons.info_outline_rounded,
                              title: 'Tentang EPIC',
                              subtitle: 'Informasi aplikasi dan misi pelestarian',
                              iconColor: const Color(0xFF475569),
                              iconBgColor: const Color(0xFFF8FAFC),
                              onTap: () => _showAboutEpicDialog(context),
                            ),
                          ),
                        ] else ...[
                          // --- Guru Menu Groups ---
                          _buildSectionHeader('⚙️  PENGATURAN'),
                          const SizedBox(height: 8),
                          Container(
                            decoration: _buildMenuContainerDecoration(),
                            child: Column(
                              children: [
                                _buildMenuItem(
                                  icon: Icons.person_outline_rounded,
                                  title: 'Edit Profil',
                                  subtitle: 'Ganti nama, username, dan info dasar',
                                  iconColor: const Color(0xFF4F46E5),
                                  iconBgColor: const Color(0xFFEEF2FF),
                                  onTap: () => Get.to(() => const epic_edit_profile.EditProfileScreen()),
                                ),
                                const Divider(height: 1, color: Color(0xFFF1F5F9), indent: 76, endIndent: 20),
                                _buildMenuItem(
                                  icon: Icons.school_outlined,
                                  title: 'Ubah Nama Sekolah',
                                  subtitle: 'Ubah informasi sekolah dan domisilimu',
                                  iconColor: const Color(0xFFD97706),
                                  iconBgColor: const Color(0xFFFFF7ED),
                                  onTap: () => Get.to(() => const epic_edit_school.EditSchoolScreen()),
                                ),
                                const Divider(height: 1, color: Color(0xFFF1F5F9), indent: 76, endIndent: 20),
                                _buildMenuItem(
                                  icon: Icons.power_off_rounded,
                                  title: 'Kelas Nonaktif',
                                  subtitle: 'Kelola kelas yang dinonaktifkan',
                                  iconColor: const Color(0xFF059669),
                                  iconBgColor: const Color(0xFFECFDF5),
                                  onTap: () => Get.to(() => const epic_guru_inactive.GuruInactiveClassesScreen()),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          _buildSectionHeader('🔑  AKUN'),
                          const SizedBox(height: 8),
                          Container(
                            decoration: _buildMenuContainerDecoration(),
                            child: _buildMenuItem(
                              icon: Icons.security_rounded,
                              title: 'Keamanan Akun',
                              subtitle: 'Lihat HP login, riwayat, dan hapus akun',
                              iconColor: const Color(0xFF0284C7),
                              iconBgColor: const Color(0xFFF0F9FF),
                              onTap: () => Get.to(() => const epic_security.KeamananAkunScreen()),
                            ),
                          ),
                          const SizedBox(height: 20),

                          _buildSectionHeader('ℹ️  INFO LAINNYA'),
                          const SizedBox(height: 8),
                          Container(
                            decoration: _buildMenuContainerDecoration(),
                            child: _buildMenuItem(
                              icon: Icons.info_outline_rounded,
                              title: 'Tentang EPIC',
                              subtitle: 'Informasi aplikasi dan misi pelestarian',
                              iconColor: const Color(0xFF475569),
                              iconBgColor: const Color(0xFFF8FAFC),
                              onTap: () => _showAboutEpicDialog(context),
                            ),
                          ),
                        ],
                        const SizedBox(height: 32),

                        // Tombol Keluar Akun (Premium Danger style)
                        ElevatedButton(
                          onPressed: controller.logout,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFEF2F2),
                            foregroundColor: const Color(0xFFEF4444),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                              side: const BorderSide(color: Color(0xFFFEE2E2)),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.logout_rounded, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Keluar Akun',
                                style: TextStyle(
                                  fontFamily: 'FredokaOne',
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildMeshBackground(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Stack(
      children: [
        // Solid base canvas
        Container(color: const Color(0xFFFFFDF9)),

        // Blob 1: Top Right - Gold/Orange
        Positioned(
          top: -size.height * 0.1,
          right: -size.width * 0.2,
          child: Container(
            width: size.width * 0.9,
            height: size.width * 0.9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFE0B2).withValues(alpha: 0.45),
            ),
          ),
        ),

        // Blob 2: Mid Left - Rose/Salmon
        Positioned(
          top: size.height * 0.35,
          left: -size.width * 0.3,
          child: Container(
            width: size.width * 0.8,
            height: size.width * 0.8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFCDD2).withValues(alpha: 0.35),
            ),
          ),
        ),

        // Blob 3: Bottom Right - Lavender/Indigo
        Positioned(
          bottom: -size.height * 0.1,
          right: -size.width * 0.1,
          child: Container(
            width: size.width * 0.7,
            height: size.width * 0.7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFE8EAF6).withValues(alpha: 0.45),
            ),
          ),
        ),

        // Blur overlay
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 75, sigmaY: 75),
            child: Container(color: Colors.transparent),
          ),
        ),
      ],
    );
  }

  BoxDecoration _buildMenuContainerDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: const Color(0xFFE2D5C8)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 30,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 10.0),
        child: Text(
          title,
          style: const TextStyle(
            fontFamily: 'FredokaOne',
            fontSize: 11,
            color: Color(0xFF94A3B8),
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }

  Widget _buildStatBox({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String label,
    required String value,
    Gradient? gradient,
    bool isWhiteText = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: gradient == null ? bgColor : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: gradient != null
            ? [
                BoxShadow(
                  color: (gradient as LinearGradient).colors.first.withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          Icon(icon, color: isWhiteText ? Colors.white : iconColor, size: 24),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'FredokaOne',
              fontSize: 20,
              color: isWhiteText ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isWhiteText ? Colors.white.withValues(alpha: 0.8) : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color iconColor,
    required Color iconBgColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'FredokaOne',
                      fontSize: 14,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1), size: 22),
          ],
        ),
      ),
    );
  }

  void _showAboutEpicDialog(BuildContext context) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF9F0),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Tentang EPIC 🎓',
                style: TextStyle(
                  fontFamily: 'FredokaOne',
                  fontSize: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'EPIC (Ecocultural Pattern Innovation Creator) lahir dari sebuah keyakinan sederhana: bahwa matematika bisa dipelajari dengan cara yang jauh lebih bermakna ketika dikaitkan dengan budaya dan kehidupan nyata anak-anak Indonesia.',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Versi Aplikasi: ',
                      style: TextStyle(fontFamily: 'Nunito', fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      'v1.0.0',
                      style: TextStyle(fontFamily: 'FredokaOne', fontSize: 12, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Get.back(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  elevation: 0,
                ),
                child: const Text(
                  'Tutup',
                  style: TextStyle(fontFamily: 'FredokaOne', fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
