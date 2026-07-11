import 'dart:ui';
import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:epic_app/core/constants/app_assets.dart';
import 'package:epic_app/core/constants/app_colors.dart';
import 'package:epic_app/features/home/home_controller.dart';
import 'package:epic_app/features/home/widgets/daily_mission_card.dart';
import 'package:epic_app/features/home/widgets/animated_knight_widget.dart';
import 'package:epic_app/core/services/draft_service.dart';
import 'package:epic_app/features/games/menggambar/drawing_screen.dart';
import 'package:epic_app/features/games/anyaman/anyaman_screen.dart';
import 'package:epic_app/features/kelas/gabung_kelas_screen.dart';

import 'package:epic_app/shared/controllers/session_controller.dart';
import 'package:epic_app/shared/widgets/user_avatar_widget.dart';
import 'package:epic_app/features/games/games_tab.dart';
import 'package:epic_app/features/kelas/kelas_controller.dart';
import 'package:epic_app/core/routes/circular_reveal_route.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with TickerProviderStateMixin {
  late AnimationController _playBtnAnimCtrl;
  late Animation<double> _playBtnScale;

  late AnimationController _pressCtrl;
  late Animation<double> _pressScale;

  final GlobalKey _playButtonKey = GlobalKey();
  bool _isTransitioning = false;

  @override
  void initState() {
    super.initState();
    Get.put(HomeController());

    // Animasi Pulse/Detak
    _playBtnAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _playBtnScale = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _playBtnAnimCtrl, curve: Curves.easeInOut),
    );

    // Animasi Press/Feedback Tekan (Taktil)
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _pressScale = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _playBtnAnimCtrl.dispose();
    _pressCtrl.dispose();
    super.dispose();
  }

  void _onPlayTapped() async {
    if (_isTransitioning) return;

    // Ambil info MediaQuery dan Navigator sebelum async gap
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final navigator = Navigator.of(context);

    setState(() {
      _isTransitioning = true;
    });

    // Hentikan animasi detak
    _playBtnAnimCtrl.stop();

    // Animasi tombol mengecil sedikit (feedback taktil)
    await _pressCtrl.forward();

    if (!mounted) return;

    // Dapatkan koordinat pusat tombol secara dinamis
    final RenderBox? renderBox = _playButtonKey.currentContext?.findRenderObject() as RenderBox?;
    final Offset centerOffset;
    if (renderBox != null) {
      centerOffset = renderBox.localToGlobal(
        Offset(renderBox.size.width / 2, renderBox.size.height / 2),
      );
    } else {
      centerOffset = Offset(screenWidth / 2, (screenHeight * 0.45) - 2);
    }

    // Jalankan transisi melingkar (Circular Reveal)
    await navigator.push(
      CircularRevealPageRoute(
        page: const GamesTab(),
        centerOffset: centerOffset,
      ),
    );

    if (!mounted) return;

    // Kembalikan tombol ke ukuran semula setelah kembali dari menu game
    await _pressCtrl.reverse();

    setState(() {
      _isTransitioning = false;
    });

    // Nyalakan kembali animasi detak
    _playBtnAnimCtrl.repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final topHalfHeight = screenHeight * 0.45;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF9F0),
      body: Stack(
        children: [
          Column(
            children: [
              _buildTopHalf(context, topHalfHeight),
              Expanded(
                child: _buildBottomHalf(),
              ),
            ],
          ),

          // Header (Profil & Poin) di atas segalanya
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: _buildHeader(),
            ),
          ),

          // Tombol Mulai Bermain
          Positioned(
            top: topHalfHeight - 35,
            left: 0,
            right: 0,
            child: Center(
              child: _buildPlayButton(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHalf(BuildContext context, double height) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.sky,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(50),
          bottomRight: Radius.circular(50),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 20,
            offset: Offset(0, 10),
          )
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Image
          Positioned.fill(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(50),
                bottomRight: Radius.circular(50),
              ),
              child: Image.asset(
                AppAssets.homeBg,
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Gradient Overlay di bawah
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 100,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(50),
                bottomRight: Radius.circular(50),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.3),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Animasi Awan
          const Positioned.fill(child: CloudAnimationWidget()),

          // Avatar Character Animasi Ksatria
          const Positioned(
            bottom: 45,
            child: AnimatedKnightWidget(),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayButton() {
    return GestureDetector(
      key: _playButtonKey,
      onTap: _onPlayTapped,
      child: AnimatedBuilder(
        animation: Listenable.merge([_playBtnAnimCtrl, _pressCtrl]),
        builder: (context, child) {
          double currentScale =
              _isTransitioning ? _pressScale.value : _playBtnScale.value;

          return Transform.scale(
            scale: currentScale,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF9900), Color(0xFFFF5500)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF5500).withValues(alpha: 0.5),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.5),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                    spreadRadius: 1,
                  )
                ],
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 28),
                  SizedBox(width: 8),
                  Text(
                    'MULAI BERMAIN',
                    style: TextStyle(
                      fontFamily: 'FredokaOne',
                      fontSize: 20,
                      color: Colors.white,
                      letterSpacing: 1.2,
                      shadows: [
                        Shadow(
                            color: Colors.black26,
                            offset: Offset(0, 2),
                            blurRadius: 4)
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    final session = Get.find<SessionController>();
    return Obx(() {
      final user = session.currentUser.value;
      if (user == null) return const SizedBox.shrink();

      final nyawa = user.nyawaEfektif;

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            // ── Profil Kiri (Avatar + Nama + Sekolah) ──
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        UserAvatarWidget(
                          avatarUrl: user.avatarUrl,
                          name: user.namaPanggilan.isNotEmpty
                              ? user.namaPanggilan
                              : user.namaLengkap,
                          radius: 12,
                          borderColor: Colors.white,
                          borderWidth: 1.5,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                user.namaPanggilan.isNotEmpty
                                    ? user.namaPanggilan
                                    : user.namaLengkap,
                                style: const TextStyle(
                                  fontFamily: 'FredokaOne',
                                  fontSize: 11,
                                  color: Color(0xFF1E293B),
                                  shadows: [
                                    Shadow(color: Colors.white, blurRadius: 4)
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (user.sekolah.isNotEmpty)
                                Text(
                                  user.sekolah,
                                  style: const TextStyle(
                                    fontFamily: 'Nunito',
                                    fontSize: 9,
                                    color: Color(0xFFC2410C),
                                    fontWeight: FontWeight.w700,
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
                ),
              ),
            ),
            const SizedBox(width: 8),

            // ── Poin (Kanan - Kotak 1) ──
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.stars_rounded,
                          color: Color(0xFFFF7A00), size: 16),
                      const SizedBox(width: 4),
                      Text(
                        _formatPoin(user.poin),
                        style: const TextStyle(
                          fontFamily: 'FredokaOne',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                          shadows: [
                            Shadow(color: Colors.white, blurRadius: 4)
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // ── Nyawa (Kanan - Kotak 2) ──
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        nyawa > 0 ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: nyawa > 0 ? const Color(0xFFEF4444) : const Color(0xFFCBD5E1),
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$nyawa',
                        style: const TextStyle(
                          fontFamily: 'FredokaOne',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                          shadows: [
                            Shadow(color: Colors.white, blurRadius: 4)
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  String _formatPoin(int poin) {
    if (poin >= 1000) {
      return '${(poin / 1000).toStringAsFixed(poin % 1000 == 0 ? 0 : 1)}k';
    }
    return poin.toString();
  }

  Widget _buildBottomHalf() {
    final session = Get.find<SessionController>();
    // Ambil atau inisialisasi KelasController untuk memantau status kelas
    final KelasController kelasCtrl = Get.isRegistered<KelasController>()
        ? Get.find<KelasController>()
        : Get.put(KelasController());

    // Inisialisasi DailyMissionController agar data misi ter-load & bisa diakses header Row
    final dailyCtrl = Get.isRegistered<DailyMissionController>()
        ? Get.find<DailyMissionController>()
        : Get.put(DailyMissionController());

    return Obx(() {
      final user = session.currentUser.value;
      // Cek secara real-time apakah ada kelas aktif
      final hasActiveKelas = kelasCtrl.kelasList.any((k) => k.status == 'aktif');

      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 40, 20, 12),
        child: ListView(
          physics: const BouncingScrollPhysics(),
          children: [

            // Banner Ajakan Gabung Kelas (Tampil jika murid tidak memiliki kelas aktif)
            if (user != null && !hasActiveKelas) ...[
              GestureDetector(
                onTap: () => Get.to(() => const GabungKelasScreen()),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFF7ED), Color(0xFFFFEDD5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFFD8A8), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF7A00).withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF7A00).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.school_rounded, color: Color(0xFFEA580C), size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Belum Gabung Kelas? 🏫',
                              style: TextStyle(
                                fontFamily: 'FredokaOne',
                                fontSize: 14,
                                color: Color(0xFFEA580C),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Ayo gabung kelas gurumu agar karyamu masuk leaderboard kelas!',
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFEA580C), size: 14),
                    ],
                  ),
                ),
              ),
            ],
            
            Row(
              children: [
                const Text(
                  'Misi Harian',
                  style: TextStyle(
                    fontFamily: 'FredokaOne',
                    fontSize: 20,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(width: 10),
                Obx(() {
                  if (dailyCtrl.isLoading.value || dailyCtrl.missions.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  final completed = dailyCtrl.missions.where((m) => m.isCompleted).length;
                  final total = dailyCtrl.missions.length;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFFFD8A8),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '$completed/$total Selesai',
                      style: const TextStyle(
                        fontFamily: 'FredokaOne',
                        fontSize: 10,
                        color: Color(0xFFEA580C),
                      ),
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 12),
            const DailyMissionCard(),
            const SizedBox(height: 12),
            const Text(
              'Lanjutkan',
              style: TextStyle(
                fontFamily: 'FredokaOne',
                fontSize: 20,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 12),
            if (user != null)
              const _ContinueDrawingBanner(),
            
            const SizedBox(height: 40),
          ],
        ),
      );
    });
  }


} // End of _HomeTabState



class _ContinueDrawingBanner extends StatelessWidget {
  const _ContinueDrawingBanner();


  String _formatSisa(int detik) {
    final m = detik ~/ 60;
    final s = detik % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final draftService = Get.find<DraftService>();

    return Obx(() {
      if (draftService.drafts.isEmpty) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF94A3B8).withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFE4C8), Color(0xFFFFD1A9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.bookmark_outline_rounded, color: Color(0xFFEA580C), size: 22),
                ),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Belum ada draf tersimpan',
                    style: TextStyle(
                      fontFamily: 'FredokaOne',
                      fontSize: 14,
                      color: Color(0xFF475569),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Mulai bermain untuk menyimpan progres!',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }

      return SizedBox(
        height: 190,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          clipBehavior: Clip.none,
          padding: const EdgeInsets.only(top: 4, bottom: 16),
          itemCount: draftService.drafts.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final draft = draftService.drafts[index];
            return _DraftItemCard(
              draft: draft,
              formatSisa: _formatSisa,
            );
          },
        ),
      );
    });
  }
}

class _DraftItemCard extends StatefulWidget {
  final dynamic draft;
  final String Function(int) formatSisa;

  const _DraftItemCard({
    required this.draft,
    required this.formatSisa,
  });

  @override
  State<_DraftItemCard> createState() => _DraftItemCardState();
}

class _DraftItemCardState extends State<_DraftItemCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final String kategori = draft.kategori.toLowerCase();
    final bool isMenggambar = draft.gameType == 'menggambar';
    final bool isAnyaman = draft.gameType == 'anyaman';

    // Per-kategori theme config
    final _DraftTheme theme = _getDraftTheme(kategori, isMenggambar, isAnyaman);

    final String kategoriLabel =
        '${draft.kategori[0].toUpperCase()}${draft.kategori.substring(1)}';

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        if (isMenggambar) {
          Get.to(
            () => DrawingScreen(kategori: draft.kategori, level: draft.level),
            arguments: {'isLanjutkan': true},
          );
        } else if (isAnyaman) {
          Get.to(
            () => AnyamanScreen(level: draft.level),
            arguments: {'isLanjutkan': true},
          );
        }
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: Container(
          width: 136,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: theme.shadowColor.withValues(alpha: 0.12),
                blurRadius: 4,
                offset: const Offset(0, 1.5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                // ── Background gradient (Solid colors, premium)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: theme.bgGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),

                // ── Decorative circle blob top-right
                Positioned(
                  top: -20,
                  right: -20,
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                ),

                // ── Decorative circle blob bottom-left
                Positioned(
                  bottom: -12,
                  left: -12,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),

                // ── Content layer
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Real image icon box (Solid Frame, no glass)
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.asset(
                            theme.iconPath,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Category name
                      Text(
                        kategoriLabel,
                        style: const TextStyle(
                          fontFamily: 'FredokaOne',
                          fontSize: 13,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black38,
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),

                      // Level & timer row (Solid badge, no glass)
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Text(
                              'Lv ${draft.level}',
                              style: TextStyle(
                                fontFamily: 'FredokaOne',
                                fontSize: 9,
                                color: theme.textColor,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.timer_rounded,
                                  size: 11, color: Colors.white),
                              const SizedBox(width: 3),
                              Text(
                                widget.formatSisa(draft.remainingSeconds),
                                style: const TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Spacer(),

                      // Continue button (Solid White, high-contrast, premium)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.play_arrow_rounded,
                                size: 14, color: theme.textColor),
                            const SizedBox(width: 4),
                            Text(
                              'Lanjutkan',
                              style: TextStyle(
                                fontFamily: 'FredokaOne',
                                fontSize: 11,
                                color: theme.textColor,
                              ),
                            ),
                          ],
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
    );
  }

  _DraftTheme _getDraftTheme(
      String kategori, bool isMenggambar, bool isAnyaman) {
    if (isAnyaman || kategori == 'anyaman') {
      return const _DraftTheme(
        bgGradient: [
          Color(0xFF38BDF8),
          Color(0xFF0EA5E9),
          Color(0xFF0369A1),
        ],
        shadowColor: Color(0xFF0EA5E9),
        iconPath: AppAssets.iconAnyaman,
        textColor: Color(0xFF0369A1),
      );
    }
    switch (kategori) {
      case 'keris':
        return const _DraftTheme(
          bgGradient: [
            Color(0xFFFB923C),
            Color(0xFFF97316),
            Color(0xFFC2410C),
          ],
          shadowColor: Color(0xFFF97316),
          iconPath: AppAssets.iconKeris,
          textColor: Color(0xFFC2410C),
        );
      case 'batik':
        return const _DraftTheme(
          bgGradient: [
            Color(0xFFC084FC),
            Color(0xFFA855F7),
            Color(0xFF7E22CE),
          ],
          shadowColor: Color(0xFFA855F7),
          iconPath: AppAssets.iconBatik,
          textColor: Color(0xFF7E22CE),
        );
      default:
        return const _DraftTheme(
          bgGradient: [
            Color(0xFFFBBF24),
            Color(0xFFF59E0B),
            Color(0xFFB45309),
          ],
          shadowColor: Color(0xFFF59E0B),
          iconPath: AppAssets.icGameMenggambar,
          textColor: Color(0xFFB45309),
        );
    }
  }
}

class _DraftTheme {
  final List<Color> bgGradient;
  final Color shadowColor;
  final String iconPath;
  final Color textColor;

  const _DraftTheme({
    required this.bgGradient,
    required this.shadowColor,
    required this.iconPath,
    required this.textColor,
  });
}




class CloudAnimationWidget extends StatefulWidget {
  const CloudAnimationWidget({super.key});
  @override
  State<CloudAnimationWidget> createState() => _CloudAnimationWidgetState();
}

class _CloudAnimationWidgetState extends State<CloudAnimationWidget> with TickerProviderStateMixin {
  late AnimationController _ctrl1, _ctrl2, _ctrl3;

  @override
  void initState() {
    super.initState();
    _ctrl1 = AnimationController(vsync: this, duration: const Duration(seconds: 40))..repeat();
    _ctrl2 = AnimationController(vsync: this, duration: const Duration(seconds: 55))..repeat();
    _ctrl3 = AnimationController(vsync: this, duration: const Duration(seconds: 30))..repeat();
  }

  @override
  void dispose() {
    _ctrl1.dispose();
    _ctrl2.dispose();
    _ctrl3.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        _buildCloud(_ctrl1, AppAssets.cloud1, 120, 60, w),
        _buildCloud(_ctrl2, AppAssets.cloud2, 80, 95, w, offset: 0.4),
        _buildCloud(_ctrl3, AppAssets.cloud3, 100, 75, w, offset: 0.7),
      ],
    );
  }

  Widget _buildCloud(
    AnimationController ctrl,
    String assetPath,
    double size,
    double top,
    double screenWidth, {
    double offset = 0.0,
  }) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) {
        final progress = (ctrl.value + offset) % 1.0;
        final dx = screenWidth - (progress * (screenWidth + size + 50));
        return Positioned(
          top: top,
          left: dx,
          child: Image.asset(assetPath, width: size, fit: BoxFit.contain),
        );
      },
    );
  }
}
