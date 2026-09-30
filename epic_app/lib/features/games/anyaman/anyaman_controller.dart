import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:epic_app/core/services/draft_service.dart';
import 'package:epic_app/core/services/app_config_service.dart';
import 'package:epic_app/core/utils/epic_notification.dart';
import 'package:epic_app/data/models/drawing_session_model.dart';
import 'package:epic_app/data/models/scoring_instrument_model.dart';
import 'package:epic_app/shared/controllers/session_controller.dart';
import 'package:epic_app/features/games/menggambar/drawing_result_screen.dart';
import 'package:epic_app/shared/widgets/epic_transition_overlay.dart';
import 'package:epic_app/core/services/student_evaluation_service.dart';
import 'package:epic_app/shared/widgets/dialog_refleksi_penalaran.dart';
import 'package:epic_app/features/games/anyaman/level4_bunga_api_pattern.dart';

/// Controller untuk game Anyaman — berbasis grid pattern
class AnyamanController extends GetxController with WidgetsBindingObserver {
  DrawingSessionModel? _session;
  final int level;
  
  // Flag to prevent saving draft after submission
  bool _isSubmitted = false;
  
  AnyamanController({required this.level});

  // ─── Onboarding / Instrument ─────────────────────────────────────────────
  final RxBool isLoadingInstrument = true.obs;
  ScoringInstrumentModel? instrument;
  String? onboardingKonteksBudaya;
  String? onboardingMateriMatematika;

  Future<void> _loadInstrument() async {
    isLoadingInstrument.value = true;
    try {
      final docId = 'anyaman_$level';
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('game_settings')
          .collection('instruments')
          .doc(docId)
          .get();

      if (doc.exists && doc.data() != null) {
        final loadedInstrument = ScoringInstrumentModel.fromJson({
          ...doc.data()!,
          'kategori': 'anyaman',
          'level': level,
        });
        instrument = _isLegacyAnyamanInstrument(loadedInstrument)
            ? ScoringInstrumentModel.getDefault('anyaman', level)
            : loadedInstrument;
      } else {
        instrument = ScoringInstrumentModel.getDefault('anyaman', level);
      }

      final onboardingDoc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('game_settings')
          .collection('onboardings')
          .doc(docId)
          .get();

      if (onboardingDoc.exists && onboardingDoc.data() != null) {
        final data = onboardingDoc.data()!;
        onboardingKonteksBudaya = data['konteksBudaya']?.toString();
        onboardingMateriMatematika = data['materiMatematika']?.toString();
      }

      final localDefault = ScoringInstrumentModel.getDefault('anyaman', level);
      if (_containsLegacyAnyamanText(
            '$onboardingKonteksBudaya $onboardingMateriMatematika',
          )) {
        onboardingKonteksBudaya = localDefault.konteksBudaya;
        onboardingMateriMatematika = localDefault.materiMatematika;
      }
      onboardingKonteksBudaya ??= localDefault.konteksBudaya;
      onboardingMateriMatematika ??= localDefault.materiMatematika;
    } catch (e) {
      debugPrint('Error loading instrument & onboarding: $e');
      instrument = ScoringInstrumentModel.getDefault('anyaman', level);
      final localDefault = ScoringInstrumentModel.getDefault('anyaman', level);
      onboardingKonteksBudaya = localDefault.konteksBudaya;
      onboardingMateriMatematika = localDefault.materiMatematika;
    } finally {
      isLoadingInstrument.value = false;
    }
  }

  Future<void> _showLevelInstructionsDialog() async {
    pauseTimer();
    final inst = instrument ?? ScoringInstrumentModel.getDefault('anyaman', level);

    await Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Color(0xFFF8FAFC)],
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.auto_stories_rounded,
                    color: Color(0xFFFF7A00),
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'Petunjuk Level $level',
                      style: const TextStyle(
                        fontFamily: 'FredokaOne',
                        fontSize: 20,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Scrollable Content
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Konteks Budaya
                      _buildInfoCard(
                        title: 'Konteks Budaya',
                        icon: Icons.account_balance_rounded,
                        content: onboardingKonteksBudaya ?? inst.konteksBudaya,
                        cardColor: const Color(0xFFFFF7ED),
                        iconColor: const Color(0xFFEA580C),
                        textColor: const Color(0xFF7C2D12),
                      ),
                      const SizedBox(height: 12),

                      // Materi Matematika
                      _buildInfoCard(
                        title: 'Materi Matematika',
                        icon: Icons.calculate_rounded,
                        content: onboardingMateriMatematika ?? inst.materiMatematika,
                        cardColor: const Color(0xFFF0FDF4),
                        iconColor: const Color(0xFF16A34A),
                        textColor: const Color(0xFF14532D),
                      ),
                      const SizedBox(height: 12),

                      // Kriteria Juri AI
                      _buildCriteriaCard(
                        criteria: inst.criteria,
                        cardColor: const Color(0xFFEFF6FF),
                        iconColor: const Color(0xFF2563EB),
                        textColor: const Color(0xFF1E3A8A),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Button
              ElevatedButton(
                onPressed: () => Get.back(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF7A00),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  'Mulai Menganyam',
                  style: TextStyle(
                    fontFamily: 'FredokaOne',
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );

    startTimer();
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required String content,
    required Color cardColor,
    required Color iconColor,
    required Color textColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withValues(alpha: 0.15), width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'FredokaOne',
                  fontSize: 14,
                  color: iconColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 13,
              height: 1.4,
              color: textColor.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCriteriaCard({
    required List<ScoringCriteria> criteria,
    required Color cardColor,
    required Color iconColor,
    required Color textColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withValues(alpha: 0.15), width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.stars_rounded, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Kriteria Juri AI',
                style: TextStyle(
                  fontFamily: 'FredokaOne',
                  fontSize: 14,
                  color: iconColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...criteria.map((c) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle_outline_rounded, color: iconColor, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${c.name} (${c.weight}%)',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 13,
                      height: 1.4,
                      color: textColor.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  // ─── Grid Config ─────────────────────────────────────────────────────────

  // Level 2 memakai 6 x 6 blok. Setiap blok terdiri dari 4 bilah yang
  // masing-masing menutupi 4 sel logis, sehingga backing grid-nya 24 x 24.
  static const _gridSizes = {
    1: 8,
    2: 24,
    3: 20,
    4: level4BungaApiSize,
  };

  static const int level2BlockCount = 6;
  static const int level2StripsPerBlock = 4;
  static const int level3TileCount = 5;
  static const int level3RingsPerTile = 3;
  static const int level3SegmentsPerTile = 13;
  static const int level3SlotsPerTile = 4;

  late final RxInt currentGridSize;
  int get gridSize => currentGridSize.value;

  // Grid warna — setiap sel punya warna (null = kosong/putih)
  late RxList<RxList<Rx<Color?>>> grid;

  // ─── Timer ───────────────────────────────────────────────────────────────

  /// Fallback default durasi timer (15 menit) jika AppConfigService belum tersedia
  static const int _timerDurasiDetik = 15 * 60;

  /// Durasi timer aktual - dari AppConfigService jika tersedia, fallback ke 15 menit
  int get _timerDurasi {
    if (Get.isRegistered<AppConfigService>()) {
      final configValue = Get.find<AppConfigService>().timerDurasiDetik.value;
      if (configValue > 0) return configValue;
    }
    return _timerDurasiDetik;
  }

  Timer? _timer;
  final RxInt sisaWaktu = _timerDurasiDetik.obs;
  final RxInt waktuTerpakai = 0.obs;
  final RxBool isPaused = true.obs;
  final RxBool isTimeUp = false.obs;
  final RxInt nyawaDigunakan = 0.obs;

  String get waktuFormatted {
    final m = sisaWaktu.value ~/ 60;
    final s = sisaWaktu.value % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double get timerProgress =>
      sisaWaktu.value / (_timerDurasi * (1 + nyawaDigunakan.value));

  Color get timerColor {
    if (sisaWaktu.value > 120) return const Color(0xFF22C55E);
    if (sisaWaktu.value > 60) return const Color(0xFFFBBF24);
    return const Color(0xFFEF4444);
  }

  // ─── Tool State ──────────────────────────────────────────────────────────

  final Rx<Color> activeColor = const Color(0xFFEF4444).obs;
  final RxBool isEraser = false.obs;
  final RxBool isEyedropper = false.obs;
  final RxString activeSymmetry = 'none'.obs; // 'none' | 'vertical' | 'horizontal' | 'both'

  // Palet warna strip anyaman
  static const List<Color> palette = [
    Color(0xFFEF4444), // Merah
    Color(0xFFF97316), // Oranye
    Color(0xFFEAB308), // Kuning
    Color(0xFF22C55E), // Hijau
    Color(0xFF3B82F6), // Biru
    Color(0xFF8B5CF6), // Ungu
    Color(0xFFEC4899), // Pink
    Color(0xFF92400E), // Coklat
    Color(0xFF1E293B), // Hitam
    Color(0xFFFFFFFF), // Putih
    Color(0xFF6B7280), // Abu
    Color(0xFFFBBF24), // Kuning Emas
  ];

  // ─── Canvas Key (untuk export) ────────────────────────────────────────────

  final GlobalKey canvasKey = GlobalKey();

  // ─── Drag painting ───────────────────────────────────────────────────────

  final RxBool isDragging = false.obs;

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    currentGridSize = (_gridSizes[level] ?? 8).obs;
    _initGrid();
  }

  @override
  void onReady() {
    super.onReady();
    _initSession();
  }

  bool _wasPausedByLifecycle = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (!isPaused.value) {
        _wasPausedByLifecycle = true;
        pauseTimer();
      }
      if (!_isSubmitted) {
        _persistState();
      }
    } else if (state == AppLifecycleState.resumed) {
      _loadTimerState();
    }
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    if (!_isSubmitted) {
      _persistState();
    }
    super.onClose();
  }

  // ─── Grid Init ────────────────────────────────────────────────────────────

  void _initGrid() {
    final size = gridSize;
    grid = List.generate(
      size,
      (_) => List.generate(size, (_) => Rx<Color?>(null)).obs,
    ).obs;
  }

  void changeGridSize(int newSize) {
    if (level == 4 && newSize != level4BungaApiSize) return;
    if (currentGridSize.value == newSize) return;
    currentGridSize.value = newSize;
    _initGrid();
  }

  // ─── Session ─────────────────────────────────────────────────────────────

  Future<void> _initSession() async {
    await _loadInstrument();
    final sessionController = Get.find<SessionController>();
    final uid = sessionController.currentUser.value?.uid ?? '';
    final isLanjutkan = Get.arguments?['isLanjutkan'] ?? false;
    
    final draftService = Get.find<DraftService>();
    final existingDraft = draftService.drafts.firstWhereOrNull(
      (d) => d.kategori == 'anyaman' && d.level == level
    );

    if (existingDraft != null && existingDraft.remainingSeconds < _timerDurasi) {
      _session = existingDraft;
      sisaWaktu.value = existingDraft.remainingSeconds;
      waktuTerpakai.value = existingDraft.waktuTerpakai;
      
      // Load grid
      if (existingDraft.anyamanData != null) {
        _loadGridFromJson(existingDraft.anyamanData!);
      }

      if (isLanjutkan) {
        startTimer();
      } else {
        await _showContinueDialog();
      }
    } else {
      // Mulai baru
      sisaWaktu.value = _timerDurasi;
      waktuTerpakai.value = 0;
      final sessionId = 'drawing_session_${uid}_anyaman_$level';
      _session = DrawingSessionModel(
        id: sessionId,
        uid: uid,
        kategori: 'anyaman',
        level: level,
        remainingSeconds: _timerDurasi,
        status: DrawingSessionStatus.draft,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      draftService.saveDraft(_session!);
      startTimer();
      _showLevelInstructionsDialog();
    }
  }

  Future<void> _showContinueDialog() async {
    final result = await Get.dialog<String>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Lanjutkan Anyaman?',
          style: TextStyle(fontFamily: 'FredokaOne', fontSize: 18),
        ),
        content: const Text(
          'Kamu punya draft sebelumnya dengan sisa waktu . '
          'Mau lanjutkan atau mulai baru?',
          style: TextStyle(fontFamily: 'Nunito', fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Get.back(result: 'new');
            },
            child: const Text('Mulai Baru',
                style: TextStyle(color: Colors.grey, fontFamily: 'Nunito')),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back(result: 'continue');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF7A00),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Lanjutkan',
                style: TextStyle(fontFamily: 'FredokaOne')),
          ),
        ],
      ),
      barrierDismissible: false,
    );

    if (result == null) {
      Get.back(); // Pop the parent screen
      return;
    }

    if (result == 'new') {
      clearGrid();
      sisaWaktu.value = _timerDurasi;
      waktuTerpakai.value = 0;
      final uid2 = Get.find<SessionController>().currentUser.value?.uid ?? '';
      final sessionId2 = 'drawing_session_${uid2}_anyaman_$level';
      _session = DrawingSessionModel(
        id: sessionId2,
        uid: uid2,
        kategori: 'anyaman',
        level: level,
        remainingSeconds: _timerDurasi,
        status: DrawingSessionStatus.draft,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      Get.find<DraftService>().saveDraft(_session!);
      startTimer();
      _showLevelInstructionsDialog();
    } else if (result == 'continue') {
      startTimer();
    }
  }

    void startTimer() {
    isPaused.value = false;
    isTimeUp.value = false;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (sisaWaktu.value <= 0) {
        t.cancel();
        _onTimeUp();
      } else {
        sisaWaktu.value--;
        waktuTerpakai.value++;
        if (sisaWaktu.value % 30 == 0) _persistState();
      }
    });
  }

  void pauseTimer() {
    _timer?.cancel();
    isPaused.value = true;
  }

  void resumeTimer() {
    if (isTimeUp.value) return;
    startTimer();
  }

  void _onTimeUp() {
    isTimeUp.value = true;
    isPaused.value = true;
    _showTimeUpDialog();
  }

  void _showTimeUpDialog() {
    final user = Get.find<SessionController>().currentUser.value;
    final nyawaSisa = user?.nyawaEfektif ?? 0;

    // Ambil maxNyawa & durasi timer dari AppConfigService jika tersedia
    final configService = Get.isRegistered<AppConfigService>()
        ? Get.find<AppConfigService>()
        : null;
    final maxNyawaDisplay = configService?.maxNyawa.value ?? 3;
    final timerMenit = ((configService?.timerDurasiDetik.value ?? _timerDurasiDetik) / 60).round();

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Waktu Habis! ⏰',
            style: TextStyle(fontFamily: 'FredokaOne', fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Waktu $timerMenit menit sudah habis. Mau tambah waktu dengan nyawa?',
              style: const TextStyle(fontFamily: 'Nunito', fontSize: 14),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(maxNyawaDisplay, (i) {
                return Icon(
                  i < nyawaSisa
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: i < nyawaSisa
                      ? const Color(0xFFEF4444)
                      : const Color(0xFFCBD5E1),
                  size: 24,
                );
              }),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
              submitWork();
            },
            child: const Text('Kumpulkan Sekarang',
                style: TextStyle(color: Colors.grey, fontFamily: 'Nunito')),
          ),
          if (nyawaSisa > 0)
            ElevatedButton(
              onPressed: () async {
                Get.back();
                await _gunakanNyawa();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Pakai ❤️ +$timerMenit menit',
                  style: const TextStyle(fontFamily: 'FredokaOne', fontSize: 13)),
            ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  Future<void> _gunakanNyawa() async {
    try {
      await Get.find<SessionController>().gunakanNyawa();
      nyawaDigunakan.value++;
      sisaWaktu.value = _timerDurasi;
      isTimeUp.value = false;
      startTimer();
    } catch (e) {
      EpicNotification.error('Ups!', e.toString().replaceAll('Exception: ', ''));
    }
  }

  // ─── Grid Actions ─────────────────────────────────────────────────────────

  void paintCell(int row, int col) {
    if (isPaused.value || isTimeUp.value) return;
    if (row < 0 || col < 0 || row >= gridSize || col >= gridSize) return;

    if (isEyedropper.value) {
      final cellColor = grid[row][col].value;
      if (cellColor != null) {
        activeColor.value = cellColor;
        isEraser.value = false;
        EpicNotification.custom(
          'Warna Disalin',
          'Berhasil mengambil warna dari anyaman!',
          color: cellColor,
          icon: Icons.colorize_rounded,
          duration: const Duration(seconds: 2),
        );
      } else {
        EpicNotification.warning(
          'Sel Kosong',
          'Kotak yang disentuh tidak memiliki warna!',
        );
      }
      isEyedropper.value = false;
      return;
    }

    final targetColor = isEraser.value ? null : activeColor.value;

    // Warnai sel utama
    _setCellColor(row, col, targetColor);

    // Pencerminan simetri khusus di Level 4
    if (level == 4 && activeSymmetry.value != 'none') {
      final sym = activeSymmetry.value;
      if (sym == 'vertical' || sym == 'both') {
        // Cermin vertikal (kiri-kanan)
        _setCellColor(row, gridSize - 1 - col, targetColor);
      }
      if (sym == 'horizontal' || sym == 'both') {
        // Cermin horizontal (atas-bawah)
        _setCellColor(gridSize - 1 - row, col, targetColor);
      }
      if (sym == 'both') {
        // Cermin kedua sumbu (diagonal silang)
        _setCellColor(gridSize - 1 - row, gridSize - 1 - col, targetColor);
      }
    }
  }

  bool _isLegacyAnyamanInstrument(ScoringInstrumentModel value) {
    return _containsLegacyAnyamanText([
      value.konteksBudaya,
      value.materiMatematika,
      value.systemInstruction,
      ...value.criteria.map((criterion) => criterion.name),
    ].join(' '));
  }

  bool _containsLegacyAnyamanText(String value) {
    final normalized = value.toLowerCase();
    if (level == 3) {
      return normalized.contains('grid 12x12') ||
          normalized.contains('minimal 4 warna') ||
          normalized.contains('minimal menggunakan 4 warna');
    }
    if (level == 4) {
      return normalized.contains('grid 14x14') ||
          normalized.contains('lebih dari 3 warna') ||
          normalized.contains('anyaman bebas') ||
          normalized.contains('asisten simetri');
    }
    return false;
  }

  /// Mewarnai satu bilah persegi panjang pada pola khusus Level 2.
  ///
  /// Blok dengan indeks genap berisi bilah vertikal, sedangkan blok ganjil
  /// berisi bilah horizontal. Keempat sel logis di bawah satu bilah selalu
  /// diberi warna yang sama agar penyimpanan draft tetap memakai format grid.
  void paintLevel2Strip(int blockRow, int blockCol, int stripIndex) {
    if (level != 2 || isPaused.value || isTimeUp.value) return;
    if (blockRow < 0 ||
        blockRow >= level2BlockCount ||
        blockCol < 0 ||
        blockCol >= level2BlockCount ||
        stripIndex < 0 ||
        stripIndex >= level2StripsPerBlock) {
      return;
    }

    final isVertical = (blockRow + blockCol).isEven;
    final startRow = blockRow * level2StripsPerBlock;
    final startCol = blockCol * level2StripsPerBlock;
    final sampleRow = startRow + (isVertical ? 0 : stripIndex);
    final sampleCol = startCol + (isVertical ? stripIndex : 0);

    if (isEyedropper.value) {
      final stripColor = grid[sampleRow][sampleCol].value;
      if (stripColor != null) {
        activeColor.value = stripColor;
        isEraser.value = false;
        EpicNotification.custom(
          'Warna Disalin',
          'Berhasil mengambil warna dari bilah anyaman!',
          color: stripColor,
          icon: Icons.colorize_rounded,
          duration: const Duration(seconds: 2),
        );
      } else {
        EpicNotification.warning(
          'Bilah Kosong',
          'Bilah yang disentuh belum memiliki warna!',
        );
      }
      isEyedropper.value = false;
      return;
    }

    final targetColor = isEraser.value ? null : activeColor.value;
    for (int offset = 0; offset < level2StripsPerBlock; offset++) {
      final row = startRow + (isVertical ? offset : stripIndex);
      final col = startCol + (isVertical ? stripIndex : offset);
      _setCellColor(row, col, targetColor);
    }
  }

  /// Mewarnai satu bilah pada motif spiral diagonal khusus Level 3.
  void paintLevel3Segment(int tileRow, int tileCol, int segmentIndex) {
    if (level != 3 || isPaused.value || isTimeUp.value) return;
    if (tileRow < 0 ||
        tileRow >= level3TileCount ||
        tileCol < 0 ||
        tileCol >= level3TileCount ||
        segmentIndex < 0 ||
        segmentIndex >= level3SegmentsPerTile) {
      return;
    }

    final isCenter = segmentIndex == level3SegmentsPerTile - 1;
    final row = tileRow * level3SlotsPerTile +
        (isCenter ? level3SlotsPerTile - 1 : segmentIndex ~/ 4);
    final col = tileCol * level3SlotsPerTile +
        (isCenter ? level3SlotsPerTile - 1 : segmentIndex % 4);
    if (row >= grid.length || col >= grid[row].length) return;

    if (isEyedropper.value) {
      final segmentColor = grid[row][col].value;
      if (segmentColor != null) {
        activeColor.value = segmentColor;
        isEraser.value = false;
        EpicNotification.custom(
          'Warna Disalin',
          'Berhasil mengambil warna dari bilah anyaman!',
          color: segmentColor,
          icon: Icons.colorize_rounded,
          duration: const Duration(seconds: 2),
        );
      } else {
        EpicNotification.warning(
          'Bilah Kosong',
          'Bilah yang disentuh belum memiliki warna!',
        );
      }
      isEyedropper.value = false;
      return;
    }

    _setCellColor(row, col, isEraser.value ? null : activeColor.value);
    update(['level3_grid']);
  }

  /// Mewarnai satu bidang persegi panjang pada motif Kelarai Bunga Api.
  void paintLevel4Region(int row, int col) {
    if (level != 4 || isPaused.value || isTimeUp.value) return;
    if (row < 0 ||
        row >= level4BungaApiSize ||
        col < 0 ||
        col >= level4BungaApiSize) {
      return;
    }

    if (isEyedropper.value) {
      final regionColor = grid[row][col].value;
      if (regionColor != null) {
        activeColor.value = regionColor;
        isEraser.value = false;
        EpicNotification.custom(
          'Warna Disalin',
          'Berhasil mengambil warna dari bilah anyaman!',
          color: regionColor,
          icon: Icons.colorize_rounded,
          duration: const Duration(seconds: 2),
        );
      } else {
        EpicNotification.warning(
          'Bilah Kosong',
          'Bilah yang disentuh belum memiliki warna!',
        );
      }
      isEyedropper.value = false;
      return;
    }

    final targetColor = isEraser.value ? null : activeColor.value;
    final targets = <Point<int>>{Point(col, row)};
    final symmetry = activeSymmetry.value;
    if (symmetry == 'vertical' || symmetry == 'both') {
      targets.add(Point(level4BungaApiSize - 1 - col, row));
    }
    if (symmetry == 'horizontal' || symmetry == 'both') {
      targets.add(Point(col, level4BungaApiSize - 1 - row));
    }
    if (symmetry == 'both') {
      targets.add(Point(
        level4BungaApiSize - 1 - col,
        level4BungaApiSize - 1 - row,
      ));
    }

    final paintedCells = <int>{};
    for (final target in targets) {
      for (final cell in level4BungaApiRegionForCell(target.y, target.x)) {
        final key = cell.y * level4BungaApiSize + cell.x;
        if (paintedCells.add(key)) {
          _setCellColor(cell.y, cell.x, targetColor);
        }
      }
    }
    update(['level4_grid']);
  }

  void _setCellColor(int r, int c, Color? color) {
    if (r >= 0 && r < gridSize && c >= 0 && c < gridSize) {
      grid[r][c].value = color;
      update(['grid_${r}_$c']);
    }
  }

  void setColor(Color color) {
    activeColor.value = color;
    isEraser.value = false;
  }

  void toggleEraser() {
    isEraser.value = !isEraser.value;
  }

  void clearGrid() {
    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        grid[row][col].value = null;
        update(['grid_${row}_$col']);
      }
    }
    if (level == 3) update(['level3_grid']);
    if (level == 4) update(['level4_grid']);
  }

  // --- Fitur Pola (Pattern) ---
  void applyPattern(String patternType) {
    clearGrid();
    if (patternType == 'clear') return;

    final color1 = palette[0]; // Merah
    final color2 = palette[4]; // Biru
    final color3 = palette[3]; // Hijau
    final color4 = palette[2]; // Kuning
    final color5 = palette[5]; // Ungu
    final color6 = palette[6]; // Pink

    Color? colorForCell(int row, int col) {
      switch (patternType) {
        case 'catur':
          return ((row + col) % 2 == 0) ? color1 : color2;
        case 'vertikal':
          return (col % 2 == 0) ? color3 : color4;
        case 'horizontal':
          return (row % 2 == 0) ? color5 : color6;
        case 'zigzag':
          return ((row + col) % 3 == 0) ? palette[1] : palette[7];
      }
      return null;
    }

    if (level == 4) {
      final visited = <int>{};
      for (int row = 0; row < level4BungaApiSize; row++) {
        for (int col = 0; col < level4BungaApiSize; col++) {
          final key = row * level4BungaApiSize + col;
          if (visited.contains(key)) continue;
          final color = colorForCell(row, col);
          for (final cell in level4BungaApiRegionForCell(row, col)) {
            visited.add(cell.y * level4BungaApiSize + cell.x);
            grid[cell.y][cell.x].value = color;
          }
        }
      }
      update(['level4_grid']);
      return;
    }

    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        final selectedColor = colorForCell(row, col);
        grid[row][col].value = selectedColor;
        update(['grid_${row}_$col']);
      }
    }
  }

  // Hitung jumlah sel yang terisi
  int get filledCells {
    if (level == 4) {
      return _level4RegionColors.whereType<Color>().length;
    }

    if (level == 3) {
      int count = 0;
      for (int tileRow = 0; tileRow < level3TileCount; tileRow++) {
        for (int tileCol = 0; tileCol < level3TileCount; tileCol++) {
          for (int segment = 0;
              segment < level3SegmentsPerTile;
              segment++) {
            if (!_isLevel3SegmentVisible(tileRow, tileCol, segment)) {
              continue;
            }
            if (_level3SegmentColor(tileRow, tileCol, segment) != null) {
              count++;
            }
          }
        }
      }
      return count;
    }

    int count = 0;
    for (final row in grid) {
      for (final cell in row) {
        if (cell.value != null) count++;
      }
    }
    return count;
  }

  int get totalCells {
    if (level == 4) return level4BungaApiRegions.length;

    if (level == 3) {
      int count = 0;
      for (int tileRow = 0; tileRow < level3TileCount; tileRow++) {
        for (int tileCol = 0; tileCol < level3TileCount; tileCol++) {
          for (int segment = 0;
              segment < level3SegmentsPerTile;
              segment++) {
            if (_isLevel3SegmentVisible(tileRow, tileCol, segment)) {
              count++;
            }
          }
        }
      }
      return count;
    }
    return gridSize * gridSize;
  }

  double get fillPercentage => totalCells == 0 ? 0 : filledCells / totalCells;

  int get usedColorCount {
    final colors = <int>{};
    if (level == 4) {
      for (final color in _level4RegionColors.whereType<Color>()) {
        colors.add(color.toARGB32());
      }
      return colors.length;
    }

    if (level == 3) {
      for (int tileRow = 0; tileRow < level3TileCount; tileRow++) {
        for (int tileCol = 0; tileCol < level3TileCount; tileCol++) {
          for (int segment = 0;
              segment < level3SegmentsPerTile;
              segment++) {
            if (!_isLevel3SegmentVisible(tileRow, tileCol, segment)) continue;
            final color = _level3SegmentColor(tileRow, tileCol, segment);
            if (color != null) colors.add(color.toARGB32());
          }
        }
      }
      return colors.length;
    }

    for (final row in grid) {
      for (final cell in row) {
        final color = cell.value;
        if (color != null) colors.add(color.toARGB32());
      }
    }
    return colors.length;
  }

  Map<String, dynamic> get scoringMetadata {
    final rows = _buildScoringRows();
    final colorsForStatistics = level == 4
        ? _level4RegionColors
        : <Color?>[for (final row in rows) ...row];
    final colorCounts = <int, int>{};
    int filled = 0;

    for (final color in colorsForStatistics) {
      if (color == null) continue;
      filled++;
      final value = color.toARGB32();
      colorCounts[value] = (colorCounts[value] ?? 0) + 1;
    }

    final uniqueColors = colorCounts.length;
    final dominantColorRatio = filled == 0
        ? 0.0
        : colorCounts.values.reduce(max) / filled;
    double colorBalance = 0;
    if (uniqueColors > 1 && filled > 0) {
      double entropy = 0;
      for (final count in colorCounts.values) {
        final probability = count / filled;
        entropy -= probability * log(probability);
      }
      colorBalance = (entropy / log(uniqueColors)).clamp(0.0, 1.0);
    }

    final offsets = switch (level) {
      2 => const <(int, int)>[(0, 1), (0, 2), (0, 4), (0, 8), (1, 0), (2, 0)],
      3 => const <(int, int)>[(0, 1), (0, 13), (0, 26), (1, 0), (2, 0)],
      _ => const <(int, int)>[(0, 1), (0, 2), (1, 0), (2, 0), (1, 1)],
    };
    final patternConsistency = level == 4
        ? _level4PatternConsistency(rows, uniqueColors)
        : _bestColorAgreement(rows, offsets);
    final transitionRatio = _colorTransitionRatio(rows);
    final colorRichness = uniqueColors <= 1
        ? 0.0
        : (0.65 + (uniqueColors - 2) * 0.10).clamp(0.0, 1.0);
    final patternScore = (100 *
            patternConsistency *
            (0.2 + 0.8 * colorBalance))
        .clamp(0.0, 100.0);
    final creativityScore = (100 *
            colorBalance *
            colorRichness *
            (0.3 + 0.7 * patternConsistency))
        .clamp(0.0, 100.0);
    final completenessScore = (fillPercentage * 100).clamp(0.0, 100.0);
    final weights = level == 1
        ? const [0.40, 0.30, 0.30]
        : const [0.35, 0.40, 0.25];
    final objectiveScore = (patternScore * weights[0] +
            creativityScore * weights[1] +
            completenessScore * weights[2])
        .clamp(0.0, 100.0);

    return {
      'scoringVersion': level == 4
          ? 'anyaman_level4_regions_v1'
          : 'anyaman_hybrid_v2',
      if (level == 4) 'filledRegions': filledCells,
      if (level == 4) 'totalRegions': totalCells,
      'uniqueColorCount': uniqueColors,
      'fillPercentage': fillPercentage,
      'dominantColorRatio': dominantColorRatio,
      'colorBalance': colorBalance,
      'colorRichness': colorRichness,
      'patternConsistency': patternConsistency,
      'transitionRatio': transitionRatio,
      'objectivePatternScore': patternScore.round(),
      'objectiveCreativityScore': creativityScore.round(),
      'objectiveCompletenessScore': completenessScore.round(),
      'objectiveScore': objectiveScore.round(),
    };
  }

  List<List<Color?>> _buildScoringRows() {
    if (level == 2) {
      return List.generate(level2BlockCount, (blockRow) {
        return <Color?>[
          for (int blockCol = 0;
              blockCol < level2BlockCount;
              blockCol++)
            for (int strip = 0; strip < level2StripsPerBlock; strip++)
              _level2StripColor(blockRow, blockCol, strip),
        ];
      });
    }

    if (level == 3) {
      return List.generate(level3TileCount, (tileRow) {
        return <Color?>[
          for (int tileCol = 0; tileCol < level3TileCount; tileCol++)
            for (int segment = 0;
                segment < level3SegmentsPerTile;
                segment++)
              _isLevel3SegmentVisible(tileRow, tileCol, segment)
                  ? _level3SegmentColor(tileRow, tileCol, segment)
                  : null,
        ];
      });
    }

    return [
      for (final row in grid) [for (final cell in row) cell.value],
    ];
  }

  List<Color?> get _level4RegionColors => [
        for (final region in level4BungaApiRegions)
          region.isEmpty ? null : grid[region.first.y][region.first.x].value,
      ];

  double _level4PatternConsistency(
    List<List<Color?>> rows,
    int uniqueColors,
  ) {
    if (uniqueColors <= 1 || rows.isEmpty) return 0;

    double agreementFor(Color? Function(int row, int col) counterpart) {
      int comparisons = 0;
      int matches = 0;
      for (int row = 0; row < rows.length; row++) {
        for (int col = 0; col < rows[row].length; col++) {
          final first = rows[row][col];
          final second = counterpart(row, col);
          if (first == null || second == null) continue;
          comparisons++;
          if (first.toARGB32() == second.toARGB32()) matches++;
        }
      }
      return comparisons == 0 ? 0 : matches / comparisons;
    }

    final lastRow = rows.length - 1;
    final lastColumn = rows.first.length - 1;
    final rawAgreement = [
      agreementFor((row, col) => rows[row][lastColumn - col]),
      agreementFor((row, col) => rows[lastRow - row][col]),
      agreementFor((row, col) => rows[lastRow - row][lastColumn - col]),
    ].reduce(max);
    final chanceAgreement = 1 / uniqueColors;
    return ((rawAgreement - chanceAgreement) / (1 - chanceAgreement))
        .clamp(0.0, 1.0);
  }

  Color? _level2StripColor(int blockRow, int blockCol, int stripIndex) {
    final isVertical = (blockRow + blockCol).isEven;
    final startRow = blockRow * level2StripsPerBlock;
    final startCol = blockCol * level2StripsPerBlock;
    final row = startRow + (isVertical ? 0 : stripIndex);
    final col = startCol + (isVertical ? stripIndex : 0);
    if (row >= grid.length || col >= grid[row].length) return null;
    return grid[row][col].value;
  }

  double _bestColorAgreement(
    List<List<Color?>> rows,
    List<(int, int)> offsets,
  ) {
    double best = 0;
    for (final (rowOffset, colOffset) in offsets) {
      int comparisons = 0;
      int matches = 0;
      for (int row = 0; row < rows.length; row++) {
        for (int col = 0; col < rows[row].length; col++) {
          final otherRow = row + rowOffset;
          final otherCol = col + colOffset;
          if (otherRow >= rows.length ||
              otherCol >= rows[otherRow].length) {
            continue;
          }
          final first = rows[row][col];
          final second = rows[otherRow][otherCol];
          if (first == null || second == null) continue;
          comparisons++;
          if (first.toARGB32() == second.toARGB32()) matches++;
        }
      }
      if (comparisons >= 4) {
        best = max(best, matches / comparisons);
      }
    }
    return best.clamp(0.0, 1.0);
  }

  double _colorTransitionRatio(List<List<Color?>> rows) {
    int comparisons = 0;
    int transitions = 0;
    for (int row = 0; row < rows.length; row++) {
      for (int col = 0; col < rows[row].length; col++) {
        final current = rows[row][col];
        if (current == null) continue;
        for (final (rowOffset, colOffset) in const [(0, 1), (1, 0)]) {
          final otherRow = row + rowOffset;
          final otherCol = col + colOffset;
          if (otherRow >= rows.length ||
              otherCol >= rows[otherRow].length) {
            continue;
          }
          final other = rows[otherRow][otherCol];
          if (other == null) continue;
          comparisons++;
          if (current.toARGB32() != other.toARGB32()) transitions++;
        }
      }
    }
    return comparisons == 0 ? 0 : transitions / comparisons;
  }

  Color? level3SegmentColor(int tileRow, int tileCol, int segmentIndex) {
    return _level3SegmentColor(tileRow, tileCol, segmentIndex);
  }

  Color? _level3SegmentColor(int tileRow, int tileCol, int segmentIndex) {
    final isCenter = segmentIndex == level3SegmentsPerTile - 1;
    final row = tileRow * level3SlotsPerTile +
        (isCenter ? level3SlotsPerTile - 1 : segmentIndex ~/ 4);
    final col = tileCol * level3SlotsPerTile +
        (isCenter ? level3SlotsPerTile - 1 : segmentIndex % 4);
    if (row >= grid.length || col >= grid[row].length) return null;
    return grid[row][col].value;
  }

  /// Hanya bilah yang beririsan dengan bingkai kanvas yang ikut dihitung.
  /// Kisi Level 3 diputar 45 derajat sehingga sebagian bilah di empat sudut
  /// backing grid terpotong dan tidak dapat disentuh oleh pemain.
  bool _isLevel3SegmentVisible(
    int tileRow,
    int tileCol,
    int segmentIndex,
  ) {
    final latticeExtent = sqrt(2.0);
    final tileSize = latticeExtent / level3TileCount;
    final band = tileSize / 8;
    final tileLeft = tileCol * tileSize;
    final tileTop = tileRow * tileSize;

    late final double left;
    late final double top;
    late final double right;
    late final double bottom;

    if (segmentIndex == level3SegmentsPerTile - 1) {
      final inset = level3RingsPerTile * band;
      left = tileLeft + inset;
      top = tileTop + inset;
      right = tileLeft + tileSize - inset;
      bottom = tileTop + tileSize - inset;
    } else {
      final ring = segmentIndex ~/ 4;
      final side = segmentIndex % 4;
      final inset = ring * band;
      final outerLeft = tileLeft + inset;
      final outerTop = tileTop + inset;
      final outerRight = tileLeft + tileSize - inset;
      final outerBottom = tileTop + tileSize - inset;

      switch (side) {
        case 0:
          left = outerLeft;
          top = outerTop;
          right = outerRight - band;
          bottom = outerTop + band;
        case 1:
          left = outerRight - band;
          top = outerTop;
          right = outerRight;
          bottom = outerBottom - band;
        case 2:
          left = outerLeft + band;
          top = outerBottom - band;
          right = outerRight;
          bottom = outerBottom;
        default:
          left = outerLeft;
          top = outerTop + band;
          right = outerLeft + band;
          bottom = outerBottom;
      }
    }

    // Setelah rotasi, area kanvas berbentuk belah ketupat pada koordinat
    // backing grid. Bilah harus mempunyai area nyata di dalam kanvas; delapan
    // bilah yang hanya bersinggungan tepat pada garis tepi tidak ikut dihitung
    // karena tidak memiliki area yang dapat disentuh pemain.
    final center = latticeExtent / 2;
    final dx = center < left
        ? left - center
        : center > right
            ? center - right
            : 0.0;
    final dy = center < top
        ? top - center
        : center > bottom
            ? center - bottom
            : 0.0;
    return dx + dy < center - 0.000000001;
  }

  // ─── Persist ─────────────────────────────────────────────────────────────

  /// Memaksa penyimpanan draft secara instan (digunakan saat exit)
  Future<void> forceSaveDraft() async {
    await _persistState();
  }

  Future<void> _persistState() async {
    if (_isSubmitted) return;
    if (_session == null) return;
    
    _session = _session!.copyWith(
      remainingSeconds: sisaWaktu.value,
      waktuTerpakai: waktuTerpakai.value,
      anyamanData: _gridToJson(),
      updatedAt: DateTime.now(),
    );
    
    await Get.find<DraftService>().saveDraft(_session!);
  }

    String _gridToJson() {
    final data = grid
        .map((row) => row.map((cell) => cell.value?.toARGB32()).toList())
        .toList();
    return jsonEncode(data);
  }

  void _loadGridFromJson(String jsonStr) {
    try {
      final data = jsonDecode(jsonStr) as List;
      final size = gridSize;
      for (int r = 0; r < min(data.length, size); r++) {
        final row = data[r] as List;
        for (int c = 0; c < min(row.length, size); c++) {
          final colorVal = row[c];
          if (colorVal != null) {
            grid[r][c].value = Color(colorVal as int);
            update(['grid_${r}_$c']);
          }
        }
      }
      if (level == 3) update(['level3_grid']);
      if (level == 4) update(['level4_grid']);
    } catch (_) {
      // Jika gagal load, biarkan grid kosong
    }
  }

  void _loadTimerState() {
    if (_wasPausedByLifecycle) {
      _wasPausedByLifecycle = false;
      startTimer();
    } else if (!isPaused.value && !isTimeUp.value) {
      startTimer();
    }
  }

  // ─── Submit ───────────────────────────────────────────────────────────────

  Future<Uint8List?> captureCanvas() async {
    try {
      final boundary =
          canvasKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      
      // Tunggu frame selesai di-paint (berfungsi di debug DAN release)
      await Future.delayed(const Duration(milliseconds: 200));

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> submitWork() async {
    pauseTimer();
    final waktuPengerjaan = waktuTerpakai.value;
    final imageBytes = await captureCanvas();

    // ── Pengecekan Evaluasi Penalaran Matematis Siswa (One-Time per Level) ──
    try {
      final sessionCtrl = Get.find<SessionController>();
      final user = sessionCtrl.currentUser.value;
      if (user != null && user.isMurid) {
        final evalService = StudentEvaluationService();
        final hasSubmitted = await evalService.hasStudentSubmitted(
          user.uid,
          'anyaman',
          level,
        );
        if (!hasSubmitted) {
          final config = await evalService.fetchConfig('anyaman', level);
          if (config != null && config.shouldShowEvaluation) {
            final activeCtx = Get.context;
            if (activeCtx != null && activeCtx.mounted) {
              final bool? didSubmitOrSkip = await DialogRefleksiPenalaran.show(
                context: activeCtx,
                config: config,
                currentUser: user,
                categoryId: 'anyaman',
                levelId: level,
              );
              // Jika siswa menekan tombol "Kembali" / X (membatalkan evaluasi),
              // batalkan proses pengumpulan agar siswa tetap di canvas studio dengan draft aman!
              if (didSubmitOrSkip != true) {
                debugPrint('🛑 [anyaman submit] Siswa membatalkan evaluasi. Pengumpulan dibatalkan, draft aman.');
                resumeTimer();
                return;
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ [anyaman submit] Pengecekan evaluasi dilewati: $e');
    }

    // ✅ Setelah evaluasi selesai / dilewati, tandai submit dan bersihkan draft
    _isSubmitted = true;
    final uid = Get.find<SessionController>().currentUser.value?.uid ?? '';
    try {
      Get.find<DraftService>().clearDraftImmediately(uid, 'anyaman', level);
      _session = null;
      debugPrint('✅ Draft anyaman berhasil dihapus: level $level');
    } catch (e) {
      debugPrint('Error deleting draft: $e');
    }

    final context = Get.context;
    if (context != null && context.mounted) {
      EpicTransitionOverlay.show(
        context: context,
        kategori: 'anyaman',
        onComplete: () {
          Get.to(
            () => DrawingResultScreen(
              kategori: 'anyaman',
              level: level,
              nyawaDigunakan: nyawaDigunakan.value,
              waktuPengerjaan: waktuPengerjaan.clamp(0, _timerDurasi * 4),
              strokeCount: filledCells,
              imageBytes: imageBytes,
              scoringMetadata: scoringMetadata,
            ),
            transition: Transition.fadeIn,
          );
        },
      );
    } else {
      Get.to(
        () => DrawingResultScreen(
          kategori: 'anyaman',
          level: level,
          nyawaDigunakan: nyawaDigunakan.value,
          waktuPengerjaan: waktuPengerjaan.clamp(0, _timerDurasiDetik * 4),
          strokeCount: filledCells,
          imageBytes: imageBytes,
          scoringMetadata: scoringMetadata,
        ),
        transition: Transition.fadeIn,
      );
    }
  }
}
