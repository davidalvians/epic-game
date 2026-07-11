import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:epic_app/core/utils/helpers.dart';
import 'package:epic_app/data/repositories/user_repository.dart';
import 'package:epic_app/features/games/menggambar/drawing_screen.dart';
import 'package:epic_app/features/games/anyaman/anyaman_screen.dart';
import 'package:epic_app/shared/controllers/session_controller.dart';

/// Layar pemilihan level dalam satu kategori (Modern 3D Horizontal Carousel Slider).
class LevelSelectScreen extends StatefulWidget {
  final String kategori;

  const LevelSelectScreen({super.key, required this.kategori});

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  final UserRepository _userRepo = UserRepository();
  Map<String, dynamic> _levels = {};
  bool _isLoading = true;

  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.8, initialPage: 0);
    _pageController.addListener(() {
      if (_pageController.page != null) {
        int next = _pageController.page!.round();
        if (_currentPage != next) {
          setState(() {
            _currentPage = next;
          });
        }
      }
    });
    _loadProgress();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadProgress() async {
    final uid = Get.find<SessionController>().currentUser.value?.uid;
    if (uid == null) return;

    final progress = await _userRepo.getProgress(uid, widget.kategori);
    final levels = Map<String, dynamic>.from(progress['levels'] ?? {});

    // Level 1 selalu unlocked
    if (!levels.containsKey('1')) {
      levels['1'] = {'unlocked': true, 'bestSkor': 0, 'bestPoin': 0};
    }

    if (mounted) {
      setState(() {
        _levels = levels;
        _isLoading = false;
      });
    }
  }

  Color get _primaryColor {
    switch (widget.kategori.toLowerCase()) {
      case 'batik':
        return const Color(0xFF8B5CF6);
      case 'anyaman':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFFFF7A00);
    }
  }

  Color get _secondaryColor {
    switch (widget.kategori.toLowerCase()) {
      case 'batik':
        return const Color(0xFF6366F1); // Indigo
      case 'anyaman':
        return const Color(0xFF059669); // Emerald Darker
      default:
        return const Color(0xFFEA580C); // Orange Darker
    }
  }

  String _getLevelSubtitle(int level, int maxPoin) {
    switch (widget.kategori.toLowerCase()) {
      case 'anyaman':
        switch (level) {
          case 1:
            return 'Grid 8x8 • Minimal 2 warna berbeda';
          case 2:
            return 'Grid 10x10 • Minimal 3 warna berbeda';
          case 3:
            return 'Grid 12x12 • Minimal 4 warna berbeda';
          case 4:
            return 'Grid 14x14 • Multi-warna & Asisten Simetri';
          default:
            return '';
        }
      case 'batik':
        switch (level) {
          case 1:
            return 'Menggambar pola garis & motif dasar berulang';
          case 2:
            return 'Menggambar motif seimbang dengan simetri cermin';
          case 3:
            return 'Mendesain motif dengan min. 3 jenis bangun datar';
          case 4:
            return 'Eksplorasi karya batik terbaik';
          default:
            return '';
        }
      case 'keris':
        switch (level) {
          case 1:
            return 'Menggambar gagang & ukiran keris Madura';
          case 2:
            return 'Menggambar dan mengukir bilah keris';
          case 3:
            return 'Merancang warangka keris dengan bangun geometri';
          case 4:
            return 'Menggabungkan gagang, bilah, & warangka utuh';
          default:
            return '';
        }
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Hitung statistik
    int completedCount = 0;
    _levels.forEach((key, val) {
      if (val is Map) {
        if ((val['bestSkor'] as num? ?? 0) > 0) {
          completedCount++;
        }
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFFAFCFF),
      body: Stack(
        children: [
          // Aurora Blob 1 (Top Left)
          Positioned(
            left: -80,
            top: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _primaryColor.withValues(alpha: 0.18),
              ),
            ),
          ),
          // Aurora Blob 2 (Middle Right)
          Positioned(
            right: -100,
            top: 250,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _secondaryColor.withValues(alpha: 0.14),
              ),
            ),
          ),
          // Aurora Blob 3 (Bottom Left)
          Positioned(
            left: -60,
            bottom: -60,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _primaryColor.withValues(alpha: 0.16),
              ),
            ),
          ),
          // Blur filter to smooth the blobs into soft glowing gradients
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: const SizedBox.shrink(),
            ),
          ),

          // Main Content Layout
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTopHeader(completedCount),
                if (_isLoading)
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                else ...[
                  const Spacer(),
                  // Restrict PageView height to make the cards cozy and beautiful
                  SizedBox(
                    height: 435,
                    child: PageView.builder(
                      controller: _pageController,
                      physics: const BouncingScrollPhysics(),
                      clipBehavior: Clip.none,
                      itemCount: 4,
                      itemBuilder: (context, index) {
                        return _buildCardPage(index + 1);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDotIndicator(),
                  const Spacer(flex: 2),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader(int completedCount) {
    final emoji = Helpers.getKategoriEmoji(widget.kategori);
    final label = Helpers.getKategoriLabel(widget.kategori);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Get.back(),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  color: _primaryColor, size: 16),
            ),
          ),
          const SizedBox(width: 14),
          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GradientText(
                  '$emoji $label',
                  style: const TextStyle(
                    fontFamily: 'FredokaOne',
                    fontSize: 22,
                  ),
                  gradient: LinearGradient(
                    colors: [_primaryColor, _secondaryColor],
                  ),
                ),
                Text(
                  '$completedCount dari 4 Misi Selesai',
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          // Small Top circular progress indicator
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 42,
                height: 42,
                child: CircularProgressIndicator(
                  value: completedCount / 4.0,
                  strokeWidth: 4.0,
                  backgroundColor: const Color(0xFFE2E8F0),
                  valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                ),
              ),
              Text(
                '${((completedCount / 4.0) * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontFamily: 'FredokaOne',
                  fontSize: 10,
                  color: _primaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardPage(int level) {
    final levelData = _levels['$level'] ?? {};
    final isUnlocked = levelData['unlocked'] == true || level == 1;
    final bestSkor = levelData['bestSkor'] as int? ?? 0;
    final bestPoin = levelData['bestPoin'] as int? ?? 0;
    final isCompleted = bestSkor > 0;
    final levelLabel = Helpers.getLevelLabel(widget.kategori, level);
    final maxPoin = Helpers.maxPoinPerLevel(level);
    final levelSubtitle = _getLevelSubtitle(level, maxPoin);

    // Apply scale and opacity animation dynamically based on PageView focus
    final double scale = _currentPage == (level - 1) ? 1.0 : 0.88;
    final double opacity = _currentPage == (level - 1) ? 1.0 : 0.55;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: opacity,
      child: Transform.scale(
        scale: scale,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: isUnlocked
                ? LinearGradient(
                    colors: [_primaryColor, _secondaryColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : const LinearGradient(
                    colors: [Color(0xFFE2E8F0), Color(0xFFCBD5E1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            boxShadow: isUnlocked
                ? [
                    BoxShadow(
                      color: _primaryColor.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    )
                  ]
                : null,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.4),
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Top bar: Row of Badge & Status Icon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      'MISI 0$level',
                      style: const TextStyle(
                        fontFamily: 'FredokaOne',
                        fontSize: 11,
                        color: Colors.white,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  Icon(
                    isUnlocked
                        ? (isCompleted ? Icons.check_circle_rounded : Icons.lock_open_rounded)
                        : Icons.lock_outline_rounded,
                    color: Colors.white.withValues(alpha: 0.7),
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 2. Main Center Content (Tightly grouped and centered)
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                          ),
                        ],
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: isUnlocked
                            ? (isCompleted
                                ? const Icon(Icons.stars_rounded, color: Color(0xFFFBBF24), size: 50)
                                : Text(
                                    Helpers.getKategoriEmoji(widget.kategori),
                                    style: const TextStyle(fontSize: 40),
                                  ))
                            : const Icon(
                                Icons.lock_outline_rounded,
                                color: Color(0xFF64748B),
                                size: 36,
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      levelLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'FredokaOne',
                        fontSize: 20,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black26,
                            offset: Offset(0, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        isUnlocked ? levelSubtitle : 'Selesaikan misi sebelumnya untuk membuka level ini.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white.withValues(alpha: 0.9),
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 3. Bottom Area (Score and CTA Button)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isCompleted) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildGemstoneText('Skor: $bestSkor', Icons.insights_rounded),
                          Container(width: 1.5, height: 16, color: Colors.white24),
                          _buildGemstoneText('🌟 $bestPoin Pts', Icons.stars_rounded),
                        ],
                      ),
                    ),
                  ] else if (isUnlocked) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.stars_rounded, size: 14, color: Color(0xFFFBBF24)),
                          const SizedBox(width: 6),
                          Text(
                            'Target: $maxPoin Poin Maks',
                            style: const TextStyle(
                              fontFamily: 'FredokaOne',
                              fontSize: 11,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_outline_rounded, size: 14, color: Colors.white60),
                          SizedBox(width: 6),
                          Text(
                            'Selesaikan level sebelumnya',
                            style: TextStyle(
                              fontFamily: 'FredokaOne',
                              fontSize: 11,
                              color: Colors.white60,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isUnlocked
                          ? () {
                              if (widget.kategori.toLowerCase() == 'anyaman') {
                                Get.to(
                                  () => AnyamanScreen(level: level),
                                  transition: Transition.rightToLeft,
                                );
                              } else {
                                Get.to(
                                  () => DrawingScreen(
                                    kategori: widget.kategori,
                                    level: level,
                                  ),
                                  transition: Transition.rightToLeft,
                                );
                              }
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        disabledBackgroundColor: Colors.white.withValues(alpha: 0.25),
                        foregroundColor: isUnlocked ? _primaryColor : const Color(0xFF94A3B8),
                        elevation: isUnlocked ? 3 : 0,
                        shadowColor: _primaryColor.withValues(alpha: 0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        isUnlocked
                            ? (isCompleted ? 'MAIN LAGI' : 'MULAI MISI')
                            : 'TERKUNCI',
                        style: const TextStyle(
                          fontFamily: 'FredokaOne',
                          fontSize: 14,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGemstoneText(String text, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFFFBBF24)),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontFamily: 'FredokaOne',
            fontSize: 12,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildDotIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final isActive = _currentPage == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: isActive ? _primaryColor : const Color(0xFFCBD5E1),
          ),
        );
      }),
    );
  }

}

/// Helper widget to render beautiful gradient text.
class GradientText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Gradient gradient;

  const GradientText(
    this.text, {
    super.key,
    required this.style,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => gradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: Text(text, style: style),
    );
  }
}
