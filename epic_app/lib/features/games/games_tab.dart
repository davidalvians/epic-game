import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:epic_app/core/constants/app_colors.dart';
import 'package:epic_app/data/models/game_model.dart';
import 'package:epic_app/data/repositories/game_repository.dart';
import 'package:epic_app/features/games/menggambar/menggambar_screen.dart';
import 'package:epic_app/features/games/menggambar/level_select_screen.dart';

/// Tab Game — menampilkan daftar game yang tersedia dari Firestore.
class GamesTab extends StatefulWidget {
  const GamesTab({super.key});

  @override
  State<GamesTab> createState() => _GamesTabState();
}

class _GamesTabState extends State<GamesTab> {
  final GameRepository _gameRepo = GameRepository();
  List<GameModel> _games = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadGames();
  }

  Future<void> _loadGames() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      final games = await _gameRepo.getGames();
      setState(() {
        // Filter out drawing subcategories from main menu
        _games = games.where((g) => 
          !['keris', 'batik', 'anyaman'].contains(g.kategori.toLowerCase())
        ).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFCFF), // Premium backdrop color
      body: Stack(
        children: [
          // Main Scrollable Content
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                Expanded(
                  child: _buildContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pilih Game',
            style: TextStyle(
              fontFamily: 'FredokaOne',
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Yuk, main dan kumpulkan Poin!',
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

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 64, color: Color(0xFFCBD5E1)),
            const SizedBox(height: 16),
            const Text(
              'Gagal memuat game',
              style: TextStyle(
                fontFamily: 'FredokaOne',
                fontSize: 18,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadGames,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      physics: const BouncingScrollPhysics(),
      children: [
        // ── Game Menggambar (selalu tampil) ──
        _buildMenggambarCard(),
        const SizedBox(height: 16),

        // ── Game dari Firestore ──
        ..._games.asMap().entries.map((e) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildGameCard(e.value),
              if (e.key < _games.length - 1) const SizedBox(height: 16),
            ],
          );
        }),

        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildMenggambarCard() {
    return Premium3DGameCard(
      onTap: () => Get.to(() => const MenggambarScreen()),
      title: 'Menggambar',
      description: 'Gambar keris, batik, atau anyaman.',
      isLocked: false,
      gradientColors: const [Color(0xFFFF7A00), Color(0xFFFF5100)],
      plateColor: const Color(0xFFC24100),
      shadowColor: const Color(0xFFFF5100),
      iconWidget: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: Image.asset(
          'assets/images/icons/ic_game_menggambar.png',
          fit: BoxFit.cover,
        ),
      ),
      footerWidget: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.stars_rounded, color: Color(0xFFFFB800), size: 16),
          SizedBox(width: 6),
          Text(
            '3 Kategori  •  4 Level',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 12,
              color: Color(0xFF475569),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      trailingWidget: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
        ),
        child: const Icon(
          Icons.arrow_forward_ios_rounded,
          color: Color(0xFFFF5100),
          size: 14,
        ),
      ),
    );
  }

  Widget _buildGameCard(GameModel game) {
    final bool locked = game.isLocked;
    final themeColor = locked ? const Color(0xFF64748B) : const Color(0xFF4F46E5);
    return Premium3DGameCard(
      onTap: locked
          ? null
          : () => Get.to(() => LevelSelectScreen(kategori: game.kategori)),
      title: game.nama,
      description: game.deskripsi,
      isLocked: locked,
      gradientColors: locked
          ? const [Color(0xFFE2E8F0), Color(0xFFCBD5E1)]
          : const [Color(0xFF6366F1), Color(0xFF4F46E5)], // Indigo theme for dynamic games
      plateColor: locked ? const Color(0xFF94A3B8) : const Color(0xFF3730A3),
      shadowColor: locked ? Colors.black : const Color(0xFF4F46E5),
      iconWidget: Center(
        child: Icon(
          Icons.videogame_asset_rounded,
          color: locked ? const Color(0xFF94A3B8) : themeColor,
          size: 42,
        ),
      ),
      footerWidget: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: locked ? const Color(0xFFE2E8F0) : const Color(0xFFEEF2FF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: locked ? const Color(0xFFCBD5E1) : const Color(0xFFC7D2FE),
            width: 1,
          ),
        ),
        child: Text(
          game.kategori.toUpperCase(),
          style: TextStyle(
            fontFamily: 'FredokaOne',
            fontSize: 9,
            color: locked ? const Color(0xFF94A3B8) : themeColor,
            letterSpacing: 0.5,
          ),
        ),
      ),
      trailingWidget: locked
          ? const Icon(Icons.lock_rounded, color: Color(0xFFCBD5E1), size: 24)
          : Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
              ),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                color: themeColor,
                size: 14,
              ),
            ),
    );
  }
}

/// Widget Kartu Game Kustom dengan Efek Glassmorphism Premium & Pendar Jewel 3D
class Premium3DGameCard extends StatefulWidget {
  final VoidCallback? onTap;
  final String title;
  final String description;
  final Widget iconWidget;
  final List<Color> gradientColors;
  final Color shadowColor;
  final Color plateColor;
  final Widget? footerWidget;
  final Widget? trailingWidget;
  final bool isLocked;

  const Premium3DGameCard({
    super.key,
    required this.onTap,
    required this.title,
    required this.description,
    required this.iconWidget,
    required this.gradientColors,
    required this.shadowColor,
    required this.plateColor,
    this.footerWidget,
    this.trailingWidget,
    this.isLocked = false,
  });

  @override
  State<Premium3DGameCard> createState() => _Premium3DGameCardState();
}

class _Premium3DGameCardState extends State<Premium3DGameCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    double scale = _isPressed ? 0.97 : 1.0;
    double opacity = _isPressed ? 0.8 : 1.0;

    return GestureDetector(
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _isPressed = true),
      onTapUp: widget.onTap == null
          ? null
          : (_) {
              setState(() => _isPressed = false);
              widget.onTap!();
            },
      onTapCancel: widget.onTap == null ? null : () => setState(() => _isPressed = false),
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
                  color: widget.isLocked
                      ? Colors.black.withValues(alpha: 0.04)
                      : widget.shadowColor.withValues(alpha: 0.16),
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
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: widget.isLocked
                          ? Colors.white.withValues(alpha: 0.3)
                          : Colors.white.withValues(alpha: 0.65),
                      width: 1.5,
                    ),
                  ),
                child: Row(
                  children: [
                    // 3D Jewel Icon Box (pendar permata mewah)
                    Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        color: widget.isLocked ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
                        border: Border.all(
                          color: widget.isLocked
                              ? const Color(0xFFCBD5E1)
                              : Color.lerp(widget.gradientColors[0], Colors.white, 0.35)!,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (widget.isLocked ? Colors.grey : widget.shadowColor)
                                .withValues(alpha: widget.isLocked ? 0.05 : 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: widget.iconWidget,
                          ),

                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // Main Content Text
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.title,
                            style: TextStyle(
                              fontFamily: 'FredokaOne',
                              fontSize: 18,
                              color: widget.isLocked ? const Color(0xFF94A3B8) : const Color(0xFF1E293B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.description,
                            style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 12,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.footerWidget != null) ...[
                            const SizedBox(height: 10),
                            widget.footerWidget!,
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Trailing Action widget (arrow or lock)
                    if (widget.trailingWidget != null)
                      widget.trailingWidget!,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  }
}

