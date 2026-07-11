import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:confetti/confetti.dart';
import 'package:epic_app/core/utils/helpers.dart';
import 'package:epic_app/data/repositories/user_repository.dart';
import 'package:epic_app/data/repositories/artwork_repository.dart';
import 'package:epic_app/data/repositories/misi_harian_repository.dart';
import 'package:epic_app/shared/controllers/session_controller.dart';
import 'package:epic_app/core/services/ai_scoring_service.dart';
import 'package:epic_app/core/services/app_config_service.dart';
import 'package:epic_app/data/repositories/kelas_repository.dart';
import 'package:epic_app/core/services/draft_service.dart';
import 'package:epic_app/core/services/audio_service.dart';

/// Layar hasil menggambar/anyaman premium — menampilkan scanning juri AI & hasil apresiasi mewah.
class DrawingResultScreen extends StatefulWidget {
  final String kategori;
  final int level;
  final int nyawaDigunakan;
  final int waktuPengerjaan; // dalam detik
  final int strokeCount;
  final Uint8List? imageBytes;
  final String? templateId;

  const DrawingResultScreen({
    super.key,
    required this.kategori,
    required this.level,
    required this.nyawaDigunakan,
    required this.waktuPengerjaan,
    required this.strokeCount,
    this.imageBytes,
    this.templateId,
  });

  @override
  State<DrawingResultScreen> createState() => _DrawingResultScreenState();
}

class _DrawingResultScreenState extends State<DrawingResultScreen>
    with TickerProviderStateMixin {
  
  // Animation controllers
  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  // Scanline animation controller
  late AnimationController _scanCtrl;
  late Animation<double> _scanPosition;

  // Confetti controller for celebrations
  late ConfettiController _confettiCtrl;

  // State variables
  bool _isEvaluating = true;
  final bool _isSubmitting = false;
  bool _isSubmitted = false;
  bool _isPending = false; // True jika kena error 429 atau error lainnya
  String _pendingReason = 'Limit penggunaan token AI saat ini sedang habis. Karya kamu telah berhasil disimpan dengan aman ke Galeri.\n\nSistem akan otomatis memberikan skor nanti saat limit token AI kembali tersedia. Jangan khawatir, kerjamu tidak sia-sia!';
  
  int _poinDapat = 0;
  int _skorFinal = 0;
  String _aiFeedback = '';
  String _aiGrade = 'C';
  String _modelUsed = '';

  // AI Loading status message animation
  Timer? _statusTimer;
  int _statusIndex = 0;
  final List<String> _statusMessages = [
    'Mengirimkan hasil karya ke Juri AI...',
    'Juri AI sedang mengamati detail goresan...',
    'Memeriksa kecocokan konsep matematika dasar...',
    'Menganalisis nilai budaya Madura yang terkandung...',
    'Juri AI merumuskan ulasan dan skor akhir...',
  ];

  // Repository
  final UserRepository _userRepo = UserRepository();
  final ArtworkRepository _artworkRepo = ArtworkRepository();

  @override
  void initState() {
    super.initState();

    // Setup Confetti
    _confettiCtrl = ConfettiController(duration: const Duration(seconds: 4));

    // Setup result animations
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _scaleAnim = CurvedAnimation(
      parent: _animCtrl, 
      curve: Curves.elasticOut,
    );
    _fadeAnim = CurvedAnimation(
      parent: _animCtrl, 
      curve: Curves.easeIn,
    );

    // Setup Scanning laser line animation
    _scanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _scanPosition = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanCtrl, curve: Curves.easeInOut),
    );

    // Start cycling loading status messages
    _statusTimer = Timer.periodic(const Duration(milliseconds: 1600), (timer) {
      if (mounted && _isEvaluating) {
        setState(() {
          _statusIndex = (_statusIndex + 1) % _statusMessages.length;
        });
      } else {
        timer.cancel();
      }
    });

    // Run AI scoring asynchronously
    _jalankanPenilaian();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _scanCtrl.dispose();
    _confettiCtrl.dispose();
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<String?> _savePendingArtwork(String uid) async {
    if (widget.imageBytes == null) return null;
    try {
      final session = Get.find<SessionController>();
      String? activeKelasId;
      try {
        final activeClasses = (await KelasRepository().getKelasByMurid(uid))
            .where((k) => k.status == 'aktif')
            .toList();
        if (activeClasses.isNotEmpty) {
          final savedId = session.activeKelasId.value;
          if (savedId.isNotEmpty && activeClasses.any((k) => k.kelasId == savedId)) {
            activeKelasId = savedId;
          }
        }
      } catch (kelasErr) {
        debugPrint('⚠️ Gagal memetakan kelasId aktif: $kelasErr');
      }

      final artwork = await _artworkRepo.saveArtwork(
        uid: uid,
        judul: 'Karya ${widget.kategori.capitalizeFirst} Level ${widget.level}',
        kategori: widget.kategori,
        level: widget.level,
        imageBytes: widget.imageBytes!,
        waktuPengerjaan: widget.waktuPengerjaan,
        nyawaDigunakan: widget.nyawaDigunakan,
        templateId: widget.templateId,
        kelasId: activeKelasId,
        status: 'pending',
      );
      return artwork.idKarya;
    } catch (e) {
      debugPrint('Gagal menyimpan pending artwork: $e');
      return null;
    }
  }

  Future<void> _jalankanPenilaian() async {
    final session = Get.find<SessionController>();
    final user = session.currentUser.value;
    if (user == null) return;

    // 1. Trigger save to Firestore/Storage AS PENDING immediately (berjalan di background)
    final pendingSaveFuture = _savePendingArtwork(user.uid);

    final aiService = Get.find<AIScoringService>();
    final Uint8List imgData = widget.imageBytes ?? Uint8List(0);
    
    final startTime = DateTime.now();

    try {
      // 2. Evaluasi menggunakan Gemini API
      final result = await aiService.evaluateArtwork(
        imageBytes: imgData,
        kategori: widget.kategori,
        level: widget.level,
        strokeCount: widget.strokeCount,
        waktuPengerjaan: widget.waktuPengerjaan,
      );

      final elapsedMs = DateTime.now().difference(startTime).inMilliseconds;
      if (elapsedMs < 3000) {
        await Future.delayed(Duration(milliseconds: 3000 - elapsedMs));
      }

      // Tunggu hingga save selesai sebelum lanjut update
      final savedId = await pendingSaveFuture;

      if (!mounted) return;
      
      setState(() {
        _skorFinal = result.skor;
        _aiFeedback = result.feedback;
        _aiGrade = result.grade;
        _modelUsed = result.modelUsed;
        _poinDapat = (_skorFinal * _getMultiplier(widget.level)).round();
        _isEvaluating = false;
        _isPending = false;
        _isSubmitted = true;
      });

      // 3. Update Artwork yang statusnya pending menjadi dinilai
      if (savedId != null) {
        try {
          await _artworkRepo.updateArtworkScore(
            idKarya: savedId,
            skorAI: _skorFinal,
            grade: _aiGrade,
            poinDapat: _poinDapat,
            feedback: _aiFeedback,
            detailPenilaian: {
              'modelUsed': _modelUsed,
            },
            modelAI: _modelUsed,
          );
        } catch (e) {
          debugPrint('⚠️ Gagal update artwork score: $e');
          // Lanjut ke draft deletion - jangan fail di sini
        }
      }

      // 4. Update point progress
      try {
        await _userRepo.simpanProgress(
          uid: user.uid,
          kategori: widget.kategori,
          level: widget.level,
          skorBaru: _skorFinal,
          poinBaru: _poinDapat,
        );
      } catch (e) {
        debugPrint('⚠️ Gagal simpan progress: $e');
      }

      // 5. Hapus draft (cleanup - non-critical, jangan stop flow jika gagal)
      try {
        final draftService = Get.find<DraftService>();
        await draftService.deleteDraft(user.uid, widget.kategori, widget.level);
        debugPrint('✅ Draft berhasil dihapus');
      } catch (e) {
        debugPrint('⚠️ Gagal hapus draft (akan dibersihkan kemudian): $e');
        // Non-critical error - don't interrupt flow
      }

      // Trigger daily missions update
      try {
        final repo = MisiHarianRepository();
        await repo.incrementByType(uid: user.uid, tipe: 'play_game');
        await repo.incrementByType(uid: user.uid, tipe: 'submit_artwork');
        await repo.incrementByType(uid: user.uid, tipe: 'earn_points', amount: _poinDapat);
        if (_aiGrade == 'S') {
          await repo.incrementByType(uid: user.uid, tipe: 'achieve_grade_s');
        }
      } catch (e) {
        debugPrint('⚠️ Gagal increment misi harian: $e');
      }

      await session.refreshUser();

      // Trigger animations
      _animCtrl.forward();
      if (Get.isRegistered<AudioService>()) {
        Get.find<AudioService>().playSfx('audio/sfx_reward.wav');
      }
      if (_aiGrade == 'S' || _aiGrade == 'A') {
        _confettiCtrl.play();
        Future.delayed(const Duration(milliseconds: 200), () {
          if (Get.isRegistered<AudioService>()) {
            Get.find<AudioService>().playSfx('audio/sfx_unlock.wav');
          }
        });
      }

    } on QuotaExhaustedException {
      // Tunggu hingga save selesai
      await pendingSaveFuture;
      
      // Hapus draft (cleanup - non-critical)
      try {
        final draftService = Get.find<DraftService>();
        await draftService.deleteDraft(user.uid, widget.kategori, widget.level);
        debugPrint('✅ Draft berhasil dihapus (quota error case)');
      } catch (e) {
        debugPrint('⚠️ Gagal hapus draft: $e');
      }

      // Trigger daily missions update (quota/pending case)
      try {
        final repo = MisiHarianRepository();
        await repo.incrementByType(uid: user.uid, tipe: 'play_game');
        await repo.incrementByType(uid: user.uid, tipe: 'submit_artwork');
      } catch (e) {
        debugPrint('⚠️ Gagal increment misi harian (quota): $e');
      }
      
      if (!mounted) return;
      setState(() {
        _isEvaluating = false;
        _isPending = true;
        _aiGrade = '-';
        _isSubmitted = true;
        _pendingReason = 'Limit penggunaan token AI saat ini sedang habis. Karya kamu telah berhasil disimpan dengan aman ke Galeri.\n\nSistem akan otomatis memberikan skor nanti saat limit token AI kembali tersedia. Jangan khawatir, kerjamu tidak sia-sia!';
      });
      _animCtrl.forward();
      
      // Friendly message untuk user
      Get.snackbar(
        'AI Sedang Padat',
        'Juri AI lagi sibuk. Karyamu akan diproses nanti saat AI siap.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
      );
      
    } catch (e) {
      // Error lainnya - wrap dengan user-friendly message
      await pendingSaveFuture;
      
      // Hapus draft (cleanup - non-critical)
      try {
        final draftService = Get.find<DraftService>();
        await draftService.deleteDraft(user.uid, widget.kategori, widget.level);
        debugPrint('✅ Draft berhasil dihapus (error case)');
      } catch (draftErr) {
        debugPrint('⚠️ Gagal hapus draft: $draftErr');
      }
      
      if (!mounted) return;
      
      String userMessage = 'Ada masalah saat penilaian. Coba lagi nanti.';
      if (e.toString().contains('timeout')) {
        userMessage = 'Koneksi lambat. Pastikan internet stabil, coba lagi.';
      } else if (e.toString().contains('token')) {
        userMessage = 'Perlu login ulang untuk penilaian.';
      }
      
      setState(() {
        _isEvaluating = false;
        _isPending = true; // Anggap pending jika error
        _pendingReason = '$userMessage\n\nKarya kamu telah berhasil disimpan di Galeri dan akan dinilai ulang otomatis nanti, atau dapat dinilai manual oleh Admin.';
      });
      _animCtrl.forward();
      
      Get.snackbar(
        'Penilaian Tertunda',
        userMessage,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
      );
    }
  }

  /// Ambil multiplier poin berdasarkan kategori dan level.
  /// Prioritas: AppConfigService dari admin panel → fallback hardcoded.
  double _getMultiplier(int level) {
    if (Get.isRegistered<AppConfigService>()) {
      return Get.find<AppConfigService>().getMultiplier(widget.kategori, level);
    }
    // Fallback jika AppConfigService belum tersedia
    switch (level) {
      case 1: return 1.0;
      case 2: return 1.2;
      case 3: return 1.5;
      case 4: return 2.0;
      default: return 1.0;
    }
  }

  // --- Grade Visual Themes (Mewah HSL Tailored) ---
  Color get _themeColor {
    switch (_aiGrade) {
      case 'S': return const Color(0xFFFFB800); // Royal Gold
      case 'A': return const Color(0xFF10B981); // Emerald Green
      case 'B': return const Color(0xFF3B82F6); // Cyber Blue
      case 'C': return const Color(0xFFF97316); // Sunset Orange
      case 'D': return const Color(0xFFEF4444); // Scarlet Red
      default: return const Color(0xFF6B7280);  // Slate Gray
    }
  }

  LinearGradient get _gradeGradient {
    switch (_aiGrade) {
      case 'S':
        return const LinearGradient(
          colors: [Color(0xFFFACC15), Color(0xFFFF8A00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'A':
        return const LinearGradient(
          colors: [Color(0xFF34D399), Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'B':
        return const LinearGradient(
          colors: [Color(0xFF60A5FA), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'C':
        return const LinearGradient(
          colors: [Color(0xFFFB923C), Color(0xFFEA580C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      default:
        return const LinearGradient(
          colors: [Color(0xFF9CA3AF), Color(0xFF4B5563)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  String get _celebrationTitle {
    switch (_aiGrade) {
      case 'S': return 'KARYA LEGENDA! 👑';
      case 'A': return 'LUAR BIASA HEBAT! 🌟';
      case 'B': return 'KARYA INDAH! 👍';
      case 'C': return 'CUKUP BAGUS! 😊';
      case 'D': return 'USAHA YANG BAIK! 💪';
      default: return 'MARI COBA LAGI! 🔄';
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Get.offAllNamed('/home');
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF090D1A), // Deep cyber dark background
        body: Stack(
          children: [
            // Dynamic Ecocultural Batik Silhouette Glow Background
            Positioned.fill(
              child: CustomPaint(
                painter: _BatikNebulaPainter(
                  themeColor: _themeColor,
                  pulseValue: _scanCtrl.value,
                ),
              ),
            ),

            // Beautiful Animated Switcher for Seamless Scanning -> Result transition
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 1000),
              switchInCurve: Curves.easeInOutCubic,
              switchOutCurve: Curves.easeInOutCubic,
              child: _isEvaluating ? _buildScanningView() : _buildResultView(),
            ),

            // Confetti Widget Overlay
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiCtrl,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                numberOfParticles: 35,
                emissionFrequency: 0.05,
                colors: const [
                  Color(0xFFFFD700),
                  Color(0xFFFF8A00),
                  Color(0xFF10B981),
                  Color(0xFF3B82F6),
                  Colors.white
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // ── 1. SCANNING SCAN VIEW (ANIMASI JURI AI MEMERIKSA KARYA) ────────────────
  // ===========================================================================
  Widget _buildScanningView() {
    return Container(
      key: const ValueKey('scanning_view'),
      width: double.infinity,
      height: double.infinity,
      color: Colors.transparent,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              // Holographic scanner title
              Text(
                'APRESIASI JURI AI',
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 3,
                  shadows: [
                    Shadow(color: const Color(0xFF00FFCC).withValues(alpha: 0.3), blurRadius: 15),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF00FFCC), 
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Color(0xFF00FFCC), blurRadius: 8, spreadRadius: 1),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'PROSES ANALISIS KARYA SENI',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF00FFCC),
                      letterSpacing: 2.0,
                    ),
                  ),
                ],
              ),
              const Spacer(),

              // Image Scanner Canvas Container (Mewah, Bercahaya, Glassmorphic)
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer neon glowing borders
                    Container(
                      width: 260,
                      height: 360,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00FFCC).withValues(alpha: 0.2),
                            blurRadius: 40,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    
                    // Glassmorphic Artwork Frame
                    Container(
                      width: 250,
                      height: 350,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFF00FFCC).withValues(alpha: 0.4), width: 1.5),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: widget.imageBytes != null
                            ? Image.memory(widget.imageBytes!, fit: BoxFit.cover)
                            : Container(color: Colors.white10),
                      ),
                    ),

                    // Holographic Moving Scanline (Sweep Laser Animation)
                    AnimatedBuilder(
                      animation: _scanPosition,
                      builder: (context, child) {
                        return Positioned(
                          top: 12 + (_scanPosition.value * 326),
                          left: 12,
                          right: 12,
                          child: child!,
                        );
                      },
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFF00FFCC),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00FFCC).withValues(alpha: 0.9),
                              blurRadius: 18,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Inner holographic grid background overlay
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          margin: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white.withValues(alpha: 0.03), width: 1),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Animated Glassmorphic Status Message
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 600),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(animation),
                    child: child,
                  ),
                ),
                child: Container(
                  key: ValueKey<int>(_statusIndex),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 15),
                    ],
                  ),
                  child: Text(
                    _statusMessages[_statusIndex],
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withValues(alpha: 0.95),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Bottom status loader with pulsing neon glow
              const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 3.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00FFCC)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // ── 2. REDESIGNED PREMIUM RESULT VIEW (HALAMAN PENILAIAN MEWAH) ─────────────
  // ===========================================================================
  Widget _buildResultView() {
    final themeColor = _themeColor;
    final minutes = widget.waktuPengerjaan ~/ 60;
    final seconds = widget.waktuPengerjaan % 60;
    final timeStr = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Container(
      key: const ValueKey('result_view'),
      width: double.infinity,
      height: double.infinity,
      color: Colors.transparent,
      child: SafeArea(
        child: Column(
          children: [
            // ── Top Glassmorphic Header Bar ──
            _buildResultHeader(themeColor),

            // ── Main Content Area ──
            Expanded(
              child: _isPending ? _buildPendingContent(themeColor) : _buildResultContent(themeColor, timeStr),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultContent(Color themeColor, String timeStr) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          // Celebratory Banner Title with elite outfit typography
          FadeTransition(
            opacity: _fadeAnim,
            child: Text(
              _celebrationTitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: themeColor,
                letterSpacing: 2.0,
                shadows: [
                  Shadow(color: themeColor.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 4)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Rotating Glowing Orbit Grade Circle Badge
          _buildAnimatedGradeBadge(themeColor),
          const SizedBox(height: 32),

          // Horizontal glassmorphic stats cards
          Row(
            children: [
              Expanded(child: _buildResultMiniStat('Skor AI', '$_skorFinal', Icons.psychology_rounded, Colors.cyan)),
              const SizedBox(width: 10),
              Expanded(child: _buildResultMiniStat('Waktu', timeStr, Icons.timer_rounded, const Color(0xFF10B981))),
              const SizedBox(width: 10),
              Expanded(child: _buildResultMiniStat('Goresan', '${widget.strokeCount}', Icons.brush_rounded, Colors.purpleAccent)),
            ],
          ),
          const SizedBox(height: 24),

          // Mystical Golden Chest Card (Glowing & Shining)
          _buildGoldenRewardCard(),
          const SizedBox(height: 24),

          // Luxury Parchment Scroll "Komentar Juri AI" Panel
          _buildAIFeedbackPanel(themeColor),
          const SizedBox(height: 36),

          // Gorgeous bottom action buttons
          _buildResultActionButtons(themeColor),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildPendingContent(Color themeColor) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Icon(Icons.hourglass_empty_rounded, size: 80, color: Colors.orange.shade300),
          const SizedBox(height: 24),
          Text(
            'PENILAIAN TERTUNDA',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Colors.orange.shade300,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Text(
              _pendingReason,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 16,
                color: Colors.white70,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 40),
          _buildResultActionButtons(themeColor),
        ],
      ),
    );
  }

  Widget _buildResultHeader(Color themeColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.01),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: themeColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: themeColor.withValues(alpha: 0.3), width: 1.5),
              boxShadow: [
                BoxShadow(color: themeColor.withValues(alpha: 0.15), blurRadius: 10),
              ],
            ),
            child: Text(
              Helpers.getKategoriEmoji(widget.kategori),
              style: const TextStyle(fontSize: 22),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Apresiasi Selesai! 🎉',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${Helpers.getKategoriLabel(widget.kategori)} • ${Helpers.getLevelLabel(widget.kategori, widget.level)}',
                  style: GoogleFonts.nunito(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedGradeBadge(Color themeColor) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Rotating Neon Ring Mandala (Double ring)
              AnimatedBuilder(
                animation: _scanCtrl,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _scanCtrl.value * math.pi * 2,
                    child: Container(
                      width: 170,
                      height: 170,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: themeColor.withValues(alpha: 0.25),
                          width: 2.0,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Stack(
                        children: List.generate(4, (i) {
                          double angle = i * (math.pi / 2);
                          return Positioned(
                            left: 85 + 75 * math.cos(angle) - 6,
                            top: 85 + 75 * math.sin(angle) - 6,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: themeColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(color: themeColor, blurRadius: 8, spreadRadius: 1),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  );
                },
              ),

              // Glowing inner circle border
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: themeColor.withValues(alpha: 0.3), width: 6),
                  boxShadow: [
                    BoxShadow(
                      color: themeColor.withValues(alpha: 0.25),
                      blurRadius: 25,
                      spreadRadius: 4,
                    ),
                  ],
                ),
              ),

              // Grade badge container (Luxury Glassmorphic Radial Gradient)
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _gradeGradient,
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 15,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _aiGrade,
                    style: GoogleFonts.outfit(
                      fontSize: 64,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      shadows: [
                        const Shadow(color: Colors.black45, offset: Offset(0, 5), blurRadius: 10),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultMiniStat(String label, String value, IconData icon, Color statColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: statColor, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoldenRewardCard() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF854D0E), Color(0xFF451A03)], // Deep Golden amber chest gradients
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFEAB308), width: 1.5), // Rich Gold Border
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEAB308).withValues(alpha: 0.2),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          children: [
            // Shimmering Golden stars icon sphere
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFDE047), Color(0xFFCA8A04)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Color(0xFFCA8A04), blurRadius: 10, spreadRadius: 1),
                ],
              ),
              child: const Center(
                child: Icon(Icons.stars_rounded, color: Colors.white, size: 32),
              ),
            ),
            const SizedBox(width: 18),

            // Reward Poin Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'POIN APRESIASI',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFFDE047),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '+$_poinDapat',
                        style: GoogleFonts.outfit(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFFEF08A),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_isSubmitting)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Color(0xFFEAB308),
                          ),
                        )
                      else if (_isSubmitted)
                        const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    _isSubmitted
                        ? 'Berhasil mendaftarkan poin ke profilmu!'
                        : 'Mendaftarkan poin ke papan peringkat...',
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _isSubmitted ? const Color(0xFF34D399) : Colors.white60,
                    ),
                  ),
                ],
              ),
            ),

            if (widget.nyawaDigunakan > 0)
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: List.generate(
                      widget.nyawaDigunakan,
                      (_) => const Padding(
                        padding: EdgeInsets.only(left: 2.0),
                        child: Icon(Icons.favorite_rounded, color: Color(0xFFEF4444), size: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${widget.nyawaDigunakan}❤️ terpakai',
                    style: GoogleFonts.nunito(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFEF4444),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIFeedbackPanel(Color themeColor) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 15, offset: Offset(0, 6)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.chat_bubble_outline_rounded, color: Colors.cyanAccent, size: 18),
                const SizedBox(width: 10),
                Text(
                  'CATATAN APRESIASI JURI AI',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Colors.cyanAccent,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Stack(
              children: [
                // Stylized huge transculent quotes background mark
                Positioned(
                  right: -10,
                  bottom: -15,
                  child: Text(
                    '“',
                    style: TextStyle(
                      fontFamily: 'FredokaOne',
                      fontSize: 90,
                      color: Colors.white.withValues(alpha: 0.03),
                      height: 0.8,
                    ),
                  ),
                ),
                Text(
                  _aiFeedback.isNotEmpty ? _aiFeedback : 'Sedang merumuskan ulasan lukisan...',
                  style: GoogleFonts.nunito(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    height: 1.7,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultActionButtons(Color themeColor) {
    return Column(
      children: [
        // Level berikutnya button
        if (widget.level < 4 && _skorFinal >= 60)
          Container(
            width: double.infinity,
            height: 54,
            margin: const EdgeInsets.only(bottom: 14),
            child: ElevatedButton.icon(
              onPressed: () {
                Get.back(); // Pop DrawingResultScreen
                Get.back(); // Pop DrawingScreen
              },
              icon: const Icon(Icons.arrow_forward_rounded, size: 20),
              label: Text(
                'LANJUT LEVEL ${widget.level + 1}',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.5),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 5,
                shadowColor: themeColor.withValues(alpha: 0.3),
              ),
            ),
          ),

        // Coba Lagi button
        SizedBox(
          width: double.infinity,
          height: 54,
          child: OutlinedButton.icon(
            onPressed: () {
              Get.back(); // Pop DrawingResultScreen
              Get.back(); // Pop DrawingScreen
            },
            icon: const Icon(Icons.refresh_rounded, size: 20),
            label: Text(
              'COBA LAGI LEVEL INI',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.5),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.15), width: 1.5),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Home button with premium styling
        InkWell(
          onTap: () => Get.offAllNamed('/home'),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'KEMBALI KE BERANDA',
              style: GoogleFonts.outfit(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: Colors.white38,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A breathtaking background custom painter to draw glowing concentric batik vector silhouettes.
class _BatikNebulaPainter extends CustomPainter {
  final Color themeColor;
  final double pulseValue;

  _BatikNebulaPainter({required this.themeColor, required this.pulseValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = themeColor.withValues(alpha: 0.02 + 0.015 * math.sin(pulseValue * math.pi))
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = themeColor.withValues(alpha: 0.04 + 0.02 * math.cos(pulseValue * math.pi))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final center = Offset(size.width / 2, size.height * 0.35);

    // Draw multiple mystical growing curves (Batik and keris silhouettes)
    for (int r = 1; r <= 5; r++) {
      double radius = r * 80.0;
      canvas.drawCircle(center, radius, linePaint);
      
      // Draw small batik leaf ornaments on the curves
      for (int i = 0; i < 8; i++) {
        double angle = i * (math.pi / 4) + (pulseValue * 0.05);
        double leafX = center.dx + radius * math.cos(angle);
        double leafY = center.dy + radius * math.sin(angle);
        
        canvas.drawCircle(Offset(leafX, leafY), 3.0 + r, paint);
        canvas.drawCircle(Offset(leafX, leafY), 2.0, linePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BatikNebulaPainter oldDelegate) {
    return oldDelegate.pulseValue != pulseValue || oldDelegate.themeColor != themeColor;
  }
}

