import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:epic_app/features/games/menggambar/level_select_screen.dart';
import 'package:epic_app/data/repositories/user_repository.dart';
import 'package:epic_app/shared/controllers/session_controller.dart';
import 'package:epic_app/core/services/app_config_service.dart';
import 'package:epic_app/data/models/user_model.dart';

/// Layar pemilihan kategori game menggambar dengan konsep Glassmorphism & Aurora Background.
class MenggambarScreen extends StatelessWidget {
  const MenggambarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        extendBody: true,
        extendBodyBehindAppBar: true,
        backgroundColor: const Color(0xFFFAFCFF), // Premium backdrop color
        body: Stack(
          children: [
          // Main Scrollable Content
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Kategori 1: Keris (Amber/Gold Gemstone style)
                        const Category3DCard(
                          kategori: 'keris',
                          emoji: 'assets/images/icons/keris_icon.png',
                          judul: 'Keris',
                          deskripsi: 'Gambar gagang, bilah, dan wadah keris.',
                          gradientColors: [
                            Color(0xFFFDE047),
                            Color(0xFFF97316),
                            Color(0xFFEA580C),
                          ],
                          shadowColor: Color(0xFFF59E0B),
                          totalLevel: 4,
                        ),
                        const SizedBox(height: 16),

                        // Kategori 2: Batik (Amethyst/Purple Gemstone style)
                        const Category3DCard(
                          kategori: 'batik',
                          emoji: 'assets/images/icons/batik_icon.png',
                          judul: 'Batik',
                          deskripsi: 'Rancang motif batik tradisional.',
                          gradientColors: [
                            Color(0xFFF5D0FE),
                            Color(0xFFA855F7),
                            Color(0xFF6366F1),
                          ],
                          shadowColor: Color(0xFF8B5CF6),
                          totalLevel: 4,
                        ),
                        const SizedBox(height: 16),

                        // Kategori 3: Anyaman (Emerald/Jade Gemstone style)
                        const Category3DCard(
                          kategori: 'anyaman',
                          emoji: 'assets/images/icons/anyaman_icon.png',
                          judul: 'Anyaman',
                          deskripsi: 'Ciptakan pola anyaman bambu tradisional.',
                          gradientColors: [
                            Color(0xFF99F6E4),
                            Color(0xFF10B981),
                            Color(0xFF047857),
                          ],
                          shadowColor: Color(0xFF10B981),
                          totalLevel: 4,
                        ),
                        const SizedBox(height: 24),


                        const SizedBox(height: 40),
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
    ),
  );
}

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  // Premium Glass Back Button
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.arrow_back_ios_new_rounded,
                            color: Color(0xFF334155), size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Game Menggambar',
                    style: TextStyle(
                      fontFamily: 'FredokaOne',
                      fontSize: 18,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),

              // Crown Studio Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.workspace_premium_rounded,
                      color: Color(0xFFF59E0B),
                      size: 14,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'STUDIO',
                      style: TextStyle(
                        fontFamily: 'FredokaOne',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF475569),
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const Text(
            'Pilih Kategori',
            style: TextStyle(
              fontFamily: 'FredokaOne',
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Pilih media untuk mahakarya Anda.',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }


}

/// Widget kustom kartu kategori menggambar dengan gaya Glassmorphism modern & lencana Jewel 3D
class Category3DCard extends StatefulWidget {
  final String kategori;
  final String emoji;
  final String judul;
  final String deskripsi;
  final List<Color> gradientColors;
  final Color shadowColor;
  final int totalLevel;

  const Category3DCard({
    super.key,
    required this.kategori,
    required this.emoji,
    required this.judul,
    required this.deskripsi,
    required this.gradientColors,
    required this.shadowColor,
    required this.totalLevel,
  });

  @override
  State<Category3DCard> createState() => _Category3DCardState();
}

class _Category3DCardState extends State<Category3DCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    double scale = _isPressed ? 0.97 : 1.0;
    double opacity = _isPressed ? 0.8 : 1.0;

    final uid = Get.find<SessionController>().currentUser.value?.uid;

    return FutureBuilder<Map<String, dynamic>>(
      future: uid != null
          ? UserRepository().getProgress(uid, widget.kategori)
          : Future.value({}),
      builder: (context, snapshot) {
        int completedCount = 0;
        if (snapshot.hasData) {
          final progress = snapshot.data!;
          final levels = Map<String, dynamic>.from(progress['levels'] ?? {});
          levels.forEach((levelKey, levelData) {
            final bestSkor = levelData['bestSkor'] as int? ?? 0;
            if (bestSkor > 0) {
              completedCount++;
            }
          });
        }

        return GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) {
            setState(() => _isPressed = false);
            Get.to(
              () => LevelSelectScreen(kategori: widget.kategori),
              transition: Transition.rightToLeft,
            );
          },
          onTapCancel: () => setState(() => _isPressed = false),
          child: AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              opacity: opacity,
              duration: const Duration(milliseconds: 150),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: widget.shadowColor.withValues(alpha: 0.16),
                      blurRadius: 28,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.65),
                          width: 1.5,
                        ),
                      ),
                    child: Row(
                      children: [
                        // 3D Jewel Icon Box
                        Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            color: const Color(0xFFF8FAFC),
                            border: Border.all(
                              color: widget.emoji.endsWith('.png')
                                  ? (widget.kategori == 'batik'
                                      ? const Color(0xFFE8AEFF)
                                      : widget.kategori == 'anyaman'
                                          ? const Color(0xFF99F6E4)
                                          : const Color(0xFFFFD1A9))
                                  : Colors.white.withValues(alpha: 0.3),
                              width: widget.emoji.endsWith('.png') ? 1.5 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: widget.shadowColor.withValues(alpha: 0.4),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [

                              // Icon Emoji or Asset Image Centered
                              Center(
                                child: widget.emoji.endsWith('.png')
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(21),
                                        child: Image.asset(
                                          widget.emoji,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : Text(
                                        widget.emoji,
                                        style: const TextStyle(fontSize: 32),
                                      ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        
                        // Content Text & Acc
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    widget.judul,
                                    style: const TextStyle(
                                      fontFamily: 'FredokaOne',
                                      fontSize: 18,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  
                                  // Chevron Arrow Box
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                                    ),
                                    child: Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      color: widget.gradientColors[1],
                                      size: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.deskripsi,
                                style: const TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 12),
                              
                              // Indikator Level (LED progress pills style)
                              Row(
                                children: List.generate(widget.totalLevel, (i) {
                                  final isActive = i < completedCount;
                                  return Container(
                                    margin: const EdgeInsets.only(right: 6),
                                    width: isActive ? 32 : 14,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? widget.gradientColors[1]
                                          : const Color(0xFFE2E8F0).withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  );
                                }),
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
          ),
        ),
      );
      },
    );
  }
}
