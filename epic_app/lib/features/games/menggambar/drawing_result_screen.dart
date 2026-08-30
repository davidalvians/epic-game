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

/// Layar hasil menggambar/anyaman premium sekelas game arcade/gacha kelas dunia.
/// Menampilkan scanning juri AI futuristik & hasil apresiasi mewah beranimasi penuh.
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
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  late Animation<double> _slideAnim;

  // Scanning animation controllers (Ultra-smooth 60fps)
  late AnimationController _scanCtrl;
  late Animation<double> _scanPosition;

  // Grade emblem rotation controller
  late AnimationController _auraRotateCtrl;

  // Score rolling counter controller
  late AnimationController _scoreCounterCtrl;
  late Animation<double> _scoreCounterAnim;

  // Shimmer button controller
  late AnimationController _shimmerCtrl;

  // Confetti controller for celebrations
  late ConfettiController _confettiCtrl;

  // State variables
  bool _isEvaluating = true;
  final bool _isSubmitting = false;
  bool _isSubmitted = false;
  bool _isPending = false;
  String _pendingReason =
      'Limit penggunaan token AI saat ini sedang habis. Karya kamu telah berhasil disimpan dengan aman ke Galeri.\n\nSistem akan otomatis memberikan skor nanti saat limit token AI kembali tersedia. Jangan khawatir, kerjamu tidak sia-sia!';
  
  int _poinDapat = 0;
  int _skorFinal = 0;
  String _aiFeedback = '';
  String _aiGrade = 'C';
  String _modelUsed = '';

  // Scanning diagnostic stage steps
  int _currentDiagnosticStep = 0;
  Timer? _diagnosticTimer;

  // Loading status message animation
  Timer? _statusTimer;
  int _statusIndex = 0;
  final List<String> _statusMessages = [
    'Mengirimkan hasil karya ke Juri...',
    'Juri sedang mengamati detail goresan...',
    'Memeriksa kecocokan konsep matematika & geometri...',
    'Menganalisis nilai budaya Madura yang terkandung...',
    'Juri merumuskan ulasan dan skor akhir...',
  ];

  // Repository
  final UserRepository _userRepo = UserRepository();
  final ArtworkRepository _artworkRepo = ArtworkRepository();

  @override
  void initState() {
    super.initState();

    // 1. Setup Confetti
    _confettiCtrl = ConfettiController(duration: const Duration(seconds: 4));

    // 2. Setup Result Animations
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn);
    _scaleAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.elasticOut);
    _slideAnim = Tween<double>(begin: 40.0, end: 0.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic),
    );

    // 3. Setup Ultra-Smooth Scanning Laser & HUD Animation (easeInOutSine for zero jitter)
    _scanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _scanPosition = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanCtrl, curve: Curves.easeInOutSine),
    );

    // 4. Setup Aura / Ray Rotation
    _auraRotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    // 5. Setup Score Counter Animation
    _scoreCounterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _scoreCounterAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scoreCounterCtrl, curve: Curves.easeOutExpo),
    );

    // 6. Setup Shimmer Button Animation
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    // 🧹 Hapus draft segera begitu layar hasil muncul
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Get.find<SessionController>().currentUser.value;
      if (user != null) {
        Get.find<DraftService>().clearDraftImmediately(user.uid, widget.kategori, widget.level);
      }
    });

    // Mulai suara pemindaian AI jika tersedia
    if (Get.isRegistered<AudioService>()) {
      Get.find<AudioService>().startScanHum();
    }

    // Step cycle timer untuk live diagnostic steps
    _diagnosticTimer = Timer.periodic(const Duration(milliseconds: 700), (timer) {
      if (mounted && _isEvaluating) {
        setState(() {
          if (_currentDiagnosticStep < 3) {
            _currentDiagnosticStep++;
          }
        });
      } else {
        timer.cancel();
      }
    });

    // Status message cycling
    _statusTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (mounted && _isEvaluating) {
        setState(() {
          _statusIndex = (_statusIndex + 1) % _statusMessages.length;
        });
      } else {
        timer.cancel();
      }
    });

    // Jalankan proses penilaian AI
    _jalankanPenilaian();
  }

  @override
  void dispose() {
    if (Get.isRegistered<AudioService>()) {
      Get.find<AudioService>().stopScanHum();
    }
    _animCtrl.dispose();
    _scanCtrl.dispose();
    _auraRotateCtrl.dispose();
    _scoreCounterCtrl.dispose();
    _shimmerCtrl.dispose();
    _confettiCtrl.dispose();
    _diagnosticTimer?.cancel();
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

    final pendingSaveFuture = _savePendingArtwork(user.uid);
    final aiService = Get.find<AIScoringService>();
    final Uint8List imgData = widget.imageBytes ?? Uint8List(0);
    final startTime = DateTime.now();

    try {
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

      final savedId = await pendingSaveFuture;

      if (!mounted) return;

      // Hentikan suara scan
      if (Get.isRegistered<AudioService>()) {
        Get.find<AudioService>().stopScanHum();
        Get.find<AudioService>().playWhoosh();
      }

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

      // Update Artwork score di background
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
        }
      }

      // Update progress poin
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

      // Hapus draft
      try {
        final draftService = Get.find<DraftService>();
        await draftService.deleteDraft(user.uid, widget.kategori, widget.level);
      } catch (e) {
        debugPrint('⚠️ Gagal hapus draft: $e');
      }

      // Daily missions update
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

      // ── Sequence Animasi Pembukaan Hasil (Grand Arcade Reveal) ──
      _playRevealSequence();

    } on QuotaExhaustedException {
      await pendingSaveFuture;
      try {
        final draftService = Get.find<DraftService>();
        await draftService.deleteDraft(user.uid, widget.kategori, widget.level);
      } catch (_) {}

      if (!mounted) return;
      if (Get.isRegistered<AudioService>()) {
        Get.find<AudioService>().stopScanHum();
      }

      setState(() {
        _isEvaluating = false;
        _isPending = true;
        _aiGrade = '-';
        _isSubmitted = true;
        _pendingReason =
            'Limit penggunaan token AI saat ini sedang habis. Karya kamu telah berhasil disimpan dengan aman ke Galeri.\n\nSistem akan otomatis memberikan skor nanti saat limit token AI kembali tersedia. Jangan khawatir, kerjamu tidak sia-sia!';
      });
      _animCtrl.forward();

      Get.snackbar(
        'AI Sedang Padat',
        'Juri AI lagi sibuk. Karyamu akan diproses nanti saat AI siap.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
      );
    } catch (e) {
      await pendingSaveFuture;
      try {
        final draftService = Get.find<DraftService>();
        await draftService.deleteDraft(user.uid, widget.kategori, widget.level);
      } catch (_) {}

      if (!mounted) return;
      if (Get.isRegistered<AudioService>()) {
        Get.find<AudioService>().stopScanHum();
      }

      String userMessage = 'Ada masalah saat penilaian. Coba lagi nanti.';
      if (e.toString().contains('timeout')) {
        userMessage = 'Koneksi lambat. Pastikan internet stabil, coba lagi.';
      } else if (e.toString().contains('token')) {
        userMessage = 'Perlu login ulang untuk penilaian.';
      }

      setState(() {
        _isEvaluating = false;
        _isPending = true;
        _pendingReason =
            '$userMessage\n\nKarya kamu telah berhasil disimpan di Galeri dan akan dinilai ulang otomatis nanti, atau dapat dinilai manual oleh Admin.';
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

  /// Sequence animasi beruntun yang dramatis (Staggered Arcade Experience)
  void _playRevealSequence() {
    _animCtrl.forward();

    // 1. Suara impact dentuman lencana
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted && Get.isRegistered<AudioService>()) {
        Get.find<AudioService>().playRevealImpact();
      }
    });

    // 2. Fanfare apresiasi & Confetti
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      if (Get.isRegistered<AudioService>()) {
        Get.find<AudioService>().playGradeReveal(_aiGrade);
      }
      if (_aiGrade == 'S' || _aiGrade == 'A') {
        _confettiCtrl.play();
      }
    });

    // 3. Roll-up angka skor AI dengan suara ticking
    Future.delayed(const Duration(milliseconds: 550), () {
      if (!mounted) return;
      _scoreCounterCtrl.forward();

      int tickCount = 0;
      Timer.periodic(const Duration(milliseconds: 90), (timer) {
        if (!mounted || tickCount >= 10 || _scoreCounterCtrl.isCompleted) {
          timer.cancel();
        } else {
          tickCount++;
          if (Get.isRegistered<AudioService>()) {
            Get.find<AudioService>().playScoreCounter();
          }
        }
      });
    });

    // 4. Suara koin saat peti emas poin diaktifkan
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      if (Get.isRegistered<AudioService>()) {
        Get.find<AudioService>().playCoinReward();
      }
    });
  }

  double _getMultiplier(int level) {
    if (Get.isRegistered<AppConfigService>()) {
      return Get.find<AppConfigService>().getMultiplier(widget.kategori, level);
    }
    switch (level) {
      case 1: return 1.0;
      case 2: return 1.2;
      case 3: return 1.5;
      case 4: return 2.0;
      default: return 1.0;
    }
  }

  // --- Grade Visual Themes (Mewah HSL & Cyber-Glow) ---
  Color get _themeColor {
    switch (_aiGrade) {
      case 'S': return const Color(0xFFFFB800); // Royal Gold
      case 'A': return const Color(0xFF10B981); // Emerald Green
      case 'B': return const Color(0xFF38BDF8); // Cyber Cyan
      case 'C': return const Color(0xFFFB923C); // Sunset Amber
      case 'D': return const Color(0xFFF87171); // Soft Coral Red
      default: return const Color(0xFF94A3B8);  // Slate Gray
    }
  }

  LinearGradient get _gradeGradient {
    switch (_aiGrade) {
      case 'S':
        return const LinearGradient(
          colors: [Color(0xFFFFF078), Color(0xFFFFB800), Color(0xFFD97706)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'A':
        return const LinearGradient(
          colors: [Color(0xFF6EE7B7), Color(0xFF10B981), Color(0xFF047857)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'B':
        return const LinearGradient(
          colors: [Color(0xFF93C5FD), Color(0xFF38BDF8), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'C':
        return const LinearGradient(
          colors: [Color(0xFFFDBA74), Color(0xFFFB923C), Color(0xFFC2410C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      default:
        return const LinearGradient(
          colors: [Color(0xFFCBD5E1), Color(0xFF94A3B8), Color(0xFF475569)],
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
        backgroundColor: const Color(0xFF070B16), // Deep Cyber Midnight Background
        body: Stack(
          children: [
            // 1. Dynamic Nebula & Madura Batik Glow Background
            Positioned.fill(
              child: CustomPaint(
                painter: _BatikNebulaPainter(
                  themeColor: _isEvaluating ? const Color(0xFF00F0FF) : _themeColor,
                  pulseValue: _scanCtrl.value,
                ),
              ),
            ),

            // 2. Animated Switcher between Scanning View and Result View
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 900),
              switchInCurve: Curves.easeInOutCubic,
              switchOutCurve: Curves.easeInOutCubic,
              child: _isEvaluating ? _buildScanningView() : _buildResultView(),
            ),

            // 3. Confetti Particle Explosion
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiCtrl,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                numberOfParticles: 45,
                emissionFrequency: 0.08,
                colors: const [
                  Color(0xFFFFD700),
                  Color(0xFFFF8A00),
                  Color(0xFF10B981),
                  Color(0xFF38BDF8),
                  Color(0xFFEC4899),
                  Colors.white,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // ── 1. HOLOGRAPHIC SCANNING VIEW (PROSES PEMINDAIAN KARYA) ─────────────────
  // ===========================================================================
  Widget _buildScanningView() {
    return Container(
      key: const ValueKey('scanning_view'),
      width: double.infinity,
      height: double.infinity,
      color: Colors.transparent,
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14),
          child: Column(
            children: [
              // Top Holographic Scanner Header
              _buildScanningHeader(),
              const SizedBox(height: 18),

              // Central Cyber Holographic Scanner Box (A4 Proportion)
              _buildHologramArtworkScanner(),
              const SizedBox(height: 20),

              // Live Diagnostic 4-Step Checklist Cards
              _buildDiagnosticStepChecklist(),
              const SizedBox(height: 18),

              // Dynamic Mascot / Thought Speech Bubble
              _buildMascotThoughtBubble(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScanningHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF00F0FF).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xFF00F0FF).withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00F0FF).withValues(alpha: 0.2),
                blurRadius: 12,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF00F0FF),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Color(0xFF00F0FF), blurRadius: 6, spreadRadius: 1),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'PEMINDAIAN KARYA SENI',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF00F0FF),
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'ANALISIS KARYA SISWA',
          style: GoogleFonts.outfit(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 2.5,
            shadows: [
              Shadow(color: const Color(0xFF00F0FF).withValues(alpha: 0.4), blurRadius: 18),
            ],
          ),
        ),
      ],
    );
  }

  /// Kotak scanner dengan rasio kertas A4 (210 : 297) yang bersih, presisi, dan stabil
  Widget _buildHologramArtworkScanner() {
    // Rasio standar A4 portrait (210:297)
    const double a4Width = 235.0;
    const double a4Height = a4Width * (297.0 / 210.0); // ~332.4

    return Center(
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // 1. Outer Neon Ambient Glow
          Container(
            width: a4Width + 14,
            height: a4Height + 14,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00F0FF).withValues(alpha: 0.3),
                  blurRadius: 36,
                  spreadRadius: 6,
                ),
              ],
            ),
          ),

          // 2. Main Scanner Box (Fixed A4 Container with Local Coordinates)
          SizedBox(
            width: a4Width,
            height: a4Height,
            child: Stack(
              children: [
                // 2a. Artwork Image inside Dark Canvas
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      color: const Color(0xFF0B132B),
                      child: widget.imageBytes != null
                          ? Image.memory(
                              widget.imageBytes!,
                              fit: BoxFit.contain,
                              alignment: Alignment.center,
                            )
                          : const SizedBox(),
                    ),
                  ),
                ),

                // 2b. Holographic Cyber Scanlines Grid
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CustomPaint(
                      painter: _HologramMatrixPainter(pulse: _scanCtrl.value),
                    ),
                  ),
                ),

                // 2c. Ultra-Smooth Volumetric Laser Beam Sweep (Scanning 100% of the Canvas)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedBuilder(
                      animation: _scanPosition,
                      builder: (context, child) {
                        // laser sweeps from y = 0 to y = a4Height - 4
                        final beamY = _scanPosition.value * (a4Height - 4);
                        final isMovingDown = _scanCtrl.status == AnimationStatus.forward;
                        
                        return Stack(
                          children: [
                            // Volumetric Directional Trail
                            Positioned(
                              top: isMovingDown ? beamY - 40 : beamY,
                              left: 0,
                              right: 0,
                              height: 40,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: isMovingDown ? Alignment.topCenter : Alignment.bottomCenter,
                                    end: isMovingDown ? Alignment.bottomCenter : Alignment.topCenter,
                                    colors: [
                                      const Color(0xFF00F0FF).withValues(alpha: 0.0),
                                      const Color(0xFF00F0FF).withValues(alpha: 0.35),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Crisp Glowing Laser Core Line
                            Positioned(
                              top: beamY,
                              left: 2,
                              right: 2,
                              height: 3.5,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0xFF00F0FF),
                                      blurRadius: 14,
                                      spreadRadius: 3,
                                    ),
                                    BoxShadow(
                                      color: Colors.white,
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Left Glowing Node Beacon
                            Positioned(
                              top: beamY - 2.5,
                              left: 2,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF00F0FF),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(color: Color(0xFF00F0FF), blurRadius: 8, spreadRadius: 2),
                                    BoxShadow(color: Colors.white, blurRadius: 3),
                                  ],
                                ),
                              ),
                            ),

                            // Right Glowing Node Beacon
                            Positioned(
                              top: beamY - 2.5,
                              right: 2,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF00F0FF),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(color: Color(0xFF00F0FF), blurRadius: 8, spreadRadius: 2),
                                    BoxShadow(color: Colors.white, blurRadius: 3),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),

                // 2d. Clean Glassmorphic Border Frame
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF00F0FF).withValues(alpha: 0.45),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),

                // 2e. Precision HUD Corner Brackets
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _HoloHudPainter(
                        pulse: _scanCtrl.value,
                        hudColor: const Color(0xFF00F0FF),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticStepChecklist() {
    final steps = [
      {'title': 'Pemindaian Goresan Kanvas', 'icon': Icons.brush_rounded},
      {'title': 'Analisis Simetri & Etnomatematika', 'icon': Icons.square_foot_rounded},
      {'title': 'Harmonisasi Warna & Ragam Budaya', 'icon': Icons.palette_rounded},
      {'title': 'Perumusan Skor & Apresiasi Juri', 'icon': Icons.auto_awesome_rounded},
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hub_rounded, size: 16, color: Color(0xFF00F0FF)),
              const SizedBox(width: 8),
              Text(
                'TAHAPAN DIAGNOSTIK',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF00F0FF),
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            children: List.generate(steps.length, (index) {
              final isDone = _currentDiagnosticStep > index;
              final isCurrent = _currentDiagnosticStep == index;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDone
                            ? const Color(0xFF10B981)
                            : isCurrent
                                ? const Color(0xFF00F0FF).withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.05),
                        border: Border.all(
                          color: isDone
                              ? const Color(0xFF10B981)
                              : isCurrent
                                  ? const Color(0xFF00F0FF)
                                  : Colors.white24,
                        ),
                      ),
                      child: Center(
                        child: isDone
                            ? const Icon(Icons.check, size: 14, color: Colors.white)
                            : isCurrent
                                ? const SizedBox(
                                    width: 10,
                                    height: 10,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00F0FF)),
                                    ),
                                  )
                                : Text(
                                    '${index + 1}',
                                    style: const TextStyle(fontSize: 10, color: Colors.white38),
                                  ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        steps[index]['title'] as String,
                        style: GoogleFonts.nunito(
                          fontSize: 12.5,
                          fontWeight: isCurrent || isDone ? FontWeight.w800 : FontWeight.w600,
                          color: isDone
                              ? Colors.white
                              : isCurrent
                                  ? const Color(0xFF00F0FF)
                                  : Colors.white38,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildMascotThoughtBubble() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF00F0FF).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00F0FF).withValues(alpha: 0.2)),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF00F0FF).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.psychology_rounded, color: Color(0xFF00F0FF), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: Text(
                _statusMessages[_statusIndex],
                key: ValueKey<int>(_statusIndex),
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white.withValues(alpha: 0.95),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // ── 2. GRAND GACHA / ARCADE RESULT VIEW (TAMPILAN PENILAIAN MEWAH & BERSIH) ─
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
            // Top Bar (Tanpa label Model AI di kanan)
            _buildResultHeader(themeColor),

            // Scrollable Content (Bersih & Fokus)
            Expanded(
              child: _isPending
                  ? _buildPendingContent(themeColor)
                  : _buildResultContent(themeColor, timeStr),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultContent(Color themeColor, String timeStr) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      child: AnimatedBuilder(
        animation: _animCtrl,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _slideAnim.value),
            child: Opacity(
              opacity: _fadeAnim.value,
              child: Column(
                children: [
                  // 1. Celebratory Title
                  Text(
                    _celebrationTitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                      color: themeColor,
                      letterSpacing: 1.5,
                      shadows: [
                        Shadow(
                          color: themeColor.withValues(alpha: 0.45),
                          blurRadius: 22,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2. Majestic Radiant Grade Emblem
                  _buildRadiantGradeEmblem(themeColor),
                  const SizedBox(height: 24),

                  // 3. Rolling Score Counter & Stats Row ("SKOR")
                  _buildScoreAndStatsGrid(themeColor, timeStr),
                  const SizedBox(height: 20),

                  // 4. Mystical Golden Rewards Chest Card (+Poin Burst)
                  _buildGoldenRewardCard(),
                  const SizedBox(height: 20),

                  // 5. Curator Feedback Panel ("CATATAN APRESIASI")
                  _buildAIFeedbackPanel(themeColor),
                  const SizedBox(height: 32),

                  // 6. Shimmering Action Buttons
                  _buildResultActionButtons(themeColor),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Header Bersih (Tanpa label Model AI di kanan)
  Widget _buildResultHeader(Color themeColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06), width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: themeColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: themeColor.withValues(alpha: 0.35), width: 1.5),
              boxShadow: [
                BoxShadow(color: themeColor.withValues(alpha: 0.2), blurRadius: 8),
              ],
            ),
            child: Text(
              Helpers.getKategoriEmoji(widget.kategori),
              style: const TextStyle(fontSize: 20),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Apresiasi Selesai! 🎉',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  '${Helpers.getKategoriLabel(widget.kategori)} • ${Helpers.getLevelLabel(widget.kategori, widget.level)}',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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

  /// Lencana Grade Megah dengan Sunburst Light Rays & Glassmorphic Shield
  Widget _buildRadiantGradeEmblem(Color themeColor) {
    return ScaleTransition(
      scale: _scaleAnim,
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 1. Rotating Sunburst Rays (Rotating Mandala Lights)
            AnimatedBuilder(
              animation: _auraRotateCtrl,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _auraRotateCtrl.value * math.pi * 2,
                  child: CustomPaint(
                    size: const Size(190, 190),
                    painter: _GradeSunburstPainter(
                      themeColor: themeColor,
                      grade: _aiGrade,
                    ),
                  ),
                );
              },
            ),

            // 2. Outer Pulsing Glow Ring
            Container(
              width: 146,
              height: 146,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: themeColor.withValues(alpha: 0.4), width: 3.0),
                boxShadow: [
                  BoxShadow(
                    color: themeColor.withValues(alpha: 0.35),
                    blurRadius: 30,
                    spreadRadius: 4,
                  ),
                ],
              ),
            ),

            // 3. Luxury Radial Gradient Grade Circle Shield
            Container(
              width: 122,
              height: 122,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _gradeGradient,
                border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 3),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Glossy Specular Light Reflection
                  Positioned(
                    top: 6,
                    left: 20,
                    right: 20,
                    height: 48,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(50)),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.45),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Grade Letter
                  Text(
                    _aiGrade,
                    style: GoogleFonts.outfit(
                      fontSize: 66,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      shadows: [
                        const Shadow(
                          color: Colors.black54,
                          offset: Offset(0, 4),
                          blurRadius: 10,
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
    );
  }

  /// Rolling Score Counter & Stats Card Grid (Diubah jadi "SKOR")
  Widget _buildScoreAndStatsGrid(Color themeColor, String timeStr) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 12),
        ],
      ),
      child: Column(
        children: [
          // Huge Rolling Score Number
          AnimatedBuilder(
            animation: _scoreCounterAnim,
            builder: (context, child) {
              final currentScore = (_scoreCounterAnim.value * _skorFinal).round();
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$currentScore',
                    style: GoogleFonts.outfit(
                      fontSize: 52,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      shadows: [
                        Shadow(color: themeColor.withValues(alpha: 0.5), blurRadius: 18),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '/ 100',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white38,
                    ),
                  ),
                ],
              );
            },
          ),
          Text(
            'SKOR',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: themeColor,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 14),

          // Mini Stats (Waktu, Goresan, Nyawa)
          Row(
            children: [
              Expanded(
                child: _buildMiniStatItem(
                  'Waktu Pengerjaan',
                  timeStr,
                  Icons.timer_rounded,
                  const Color(0xFF38BDF8),
                ),
              ),
              Container(width: 1, height: 32, color: Colors.white10),
              Expanded(
                child: _buildMiniStatItem(
                  'Total Goresan',
                  '${widget.strokeCount}',
                  Icons.gesture_rounded,
                  const Color(0xFFA855F7),
                ),
              ),
              if (widget.nyawaDigunakan > 0) ...[
                Container(width: 1, height: 32, color: Colors.white10),
                Expanded(
                  child: _buildMiniStatItem(
                    'Nyawa Terpakai',
                    '${widget.nyawaDigunakan}❤️',
                    Icons.favorite_rounded,
                    const Color(0xFFEF4444),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.white38,
          ),
        ),
      ],
    );
  }

  /// Mystical Golden Rewards Chest Card (+Poin Burst)
  Widget _buildGoldenRewardCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF78350F), Color(0xFF451A03)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFFBBF24), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFBBF24).withValues(alpha: 0.25),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          // Shimmering Golden Stars Icon Sphere
          Container(
            width: 54,
            height: 54,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFDE047), Color(0xFFD97706)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Color(0xFFD97706), blurRadius: 12, spreadRadius: 2),
              ],
            ),
            child: const Center(
              child: Icon(Icons.stars_rounded, color: Colors.white, size: 32),
            ),
          ),
          const SizedBox(width: 16),

          // Points Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
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
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF08A).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Bonus ${(_getMultiplier(widget.level))}x',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFFEF08A),
                        ),
                      ),
                    ),
                  ],
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
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF34D399), size: 20),
                  ],
                ),
                Text(
                  _isSubmitted
                      ? 'Poin telah ditambahkan ke profil & ranking!'
                      : 'Menyimpan poin ke profil kamu...',
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _isSubmitted ? const Color(0xFF34D399) : Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Luxury Curator Feedback Panel (Diubah jadi "CATATAN APRESIASI")
  Widget _buildAIFeedbackPanel(Color themeColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 15),
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
                'CATATAN APRESIASI',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Colors.cyanAccent,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Stack(
            children: [
              Positioned(
                right: -10,
                bottom: -20,
                child: Text(
                  '“',
                  style: TextStyle(
                    fontFamily: 'FredokaOne',
                    fontSize: 90,
                    color: Colors.white.withValues(alpha: 0.04),
                    height: 0.8,
                  ),
                ),
              ),
              Text(
                _aiFeedback.isNotEmpty
                    ? _aiFeedback
                    : 'Karya yang sangat menarik dengan perpaduan warna dan konsep etnomatematika yang baik!',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  height: 1.6,
                  color: Colors.white.withValues(alpha: 0.95),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Pending State Content
  Widget _buildPendingContent(Color themeColor) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Icon(Icons.hourglass_empty_rounded, size: 80, color: Colors.orange.shade300),
          const SizedBox(height: 20),
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
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Text(
              _pendingReason,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 15,
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

  /// Shimmering Action Buttons
  Widget _buildResultActionButtons(Color themeColor) {
    return Column(
      children: [
        // Level Berikutnya (dengan Shimmer Light Sweep)
        if (widget.level < 4 && _skorFinal >= 60)
          AnimatedBuilder(
            animation: _shimmerCtrl,
            builder: (context, child) {
              return Container(
                width: double.infinity,
                height: 56,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: themeColor.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (Get.isRegistered<AudioService>()) {
                      Get.find<AudioService>().playButtonClick();
                    }
                    Get.back(); // Pop DrawingResultScreen
                    Get.back(); // Pop DrawingScreen
                  },
                  icon: const Icon(Icons.arrow_forward_rounded, size: 22),
                  label: Text(
                    'LANJUT LEVEL ${widget.level + 1}',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      letterSpacing: 1.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 0,
                  ),
                ),
              );
            },
          ),

        // Coba Lagi Button
        SizedBox(
          width: double.infinity,
          height: 54,
          child: OutlinedButton.icon(
            onPressed: () {
              if (Get.isRegistered<AudioService>()) {
                Get.find<AudioService>().playButtonClick();
              }
              Get.back();
              Get.back();
            },
            icon: const Icon(Icons.refresh_rounded, size: 20),
            label: Text(
              'COBA LAGI LEVEL INI',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 1.5,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.18), width: 1.5),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Kembali ke Beranda
        InkWell(
          onTap: () {
            if (Get.isRegistered<AudioService>()) {
              Get.find<AudioService>().playButtonClick();
            }
            Get.offAllNamed('/home');
          },
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

/// Custom painter untuk efek cahaya Sunburst & Orbiting particle nodes di belakang lencana Grade
class _GradeSunburstPainter extends CustomPainter {
  final Color themeColor;
  final String grade;

  _GradeSunburstPainter({required this.themeColor, required this.grade});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rayPaint = Paint()
      ..color = themeColor.withValues(alpha: grade == 'S' ? 0.18 : 0.10)
      ..style = PaintingStyle.fill;

    const numRays = 12;
    const rayAngle = (math.pi * 2) / numRays;

    for (int i = 0; i < numRays; i++) {
      final angle = i * rayAngle;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(
          center.dx + (size.width * 0.5) * math.cos(angle - 0.12),
          center.dy + (size.height * 0.5) * math.sin(angle - 0.12),
        )
        ..lineTo(
          center.dx + (size.width * 0.5) * math.cos(angle + 0.12),
          center.dy + (size.height * 0.5) * math.sin(angle + 0.12),
        )
        ..close();

      canvas.drawPath(path, rayPaint);
    }

    // Small orbiting sparkle beads
    final beadPaint = Paint()
      ..color = themeColor.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 6; i++) {
      final angle = i * (math.pi / 3);
      final beadPos = Offset(
        center.dx + 82 * math.cos(angle),
        center.dy + 82 * math.sin(angle),
      );
      canvas.drawCircle(beadPos, 3.5, beadPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GradeSunburstPainter oldDelegate) {
    return oldDelegate.themeColor != themeColor || oldDelegate.grade != grade;
  }
}

/// Custom painter untuk grid holografis lembut di dalam kanvas
class _HologramMatrixPainter extends CustomPainter {
  final double pulse;

  _HologramMatrixPainter({required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFF00F0FF).withValues(alpha: 0.035)
      ..strokeWidth = 1.0;

    // Horizontal scanlines
    for (double y = 0; y < size.height; y += 14) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
    // Vertical grid lines
    for (double x = 0; x < size.width; x += 14) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HologramMatrixPainter oldDelegate) {
    return false;
  }
}

/// Custom painter untuk HUD Futuristic Crosshairs & Corner Target Brackets (Pas sudut)
class _HoloHudPainter extends CustomPainter {
  final double pulse;
  final Color hudColor;

  _HoloHudPainter({required this.pulse, required this.hudColor});

  @override
  void paint(Canvas canvas, Size size) {
    final bracketPaint = Paint()
      ..color = hudColor.withValues(alpha: 0.8 + 0.2 * math.sin(pulse * math.pi))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    const bracketLen = 22.0;
    const offset = 0.0;

    // Top-Left
    canvas.drawLine(const Offset(offset, offset + bracketLen), const Offset(offset, offset), bracketPaint);
    canvas.drawLine(const Offset(offset, offset), const Offset(offset + bracketLen, offset), bracketPaint);

    // Top-Right
    canvas.drawLine(Offset(size.width - offset - bracketLen, offset), Offset(size.width - offset, offset), bracketPaint);
    canvas.drawLine(Offset(size.width - offset, offset), Offset(size.width - offset, offset + bracketLen), bracketPaint);

    // Bottom-Left
    canvas.drawLine(Offset(offset, size.height - offset - bracketLen), Offset(offset, size.height - offset), bracketPaint);
    canvas.drawLine(Offset(offset, size.height - offset), Offset(offset + bracketLen, size.height - offset), bracketPaint);

    // Bottom-Right
    canvas.drawLine(Offset(size.width - offset - bracketLen, size.height - offset), Offset(size.width - offset, size.height - offset), bracketPaint);
    canvas.drawLine(Offset(size.width - offset, size.height - offset), Offset(size.width - offset, size.height - offset - bracketLen), bracketPaint);
  }

  @override
  bool shouldRepaint(covariant _HoloHudPainter oldDelegate) {
    return oldDelegate.pulse != pulse;
  }
}

/// Dynamic Batik & Nebula Vector Silhouette Background Painter
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

    for (int r = 1; r <= 5; r++) {
      double radius = r * 80.0;
      canvas.drawCircle(center, radius, linePaint);

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
