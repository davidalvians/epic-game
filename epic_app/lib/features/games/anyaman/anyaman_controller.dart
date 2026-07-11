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
import 'package:epic_app/data/models/drawing_session_model.dart';
import 'package:epic_app/data/models/scoring_instrument_model.dart';
import 'package:epic_app/shared/controllers/session_controller.dart';
import 'package:epic_app/features/games/menggambar/drawing_result_screen.dart';
import 'package:epic_app/shared/widgets/epic_transition_overlay.dart';

/// Controller untuk game Anyaman — berbasis grid pattern
class AnyamanController extends GetxController with WidgetsBindingObserver {
  DrawingSessionModel? _session;
  final int level;
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
        instrument = ScoringInstrumentModel.fromJson(doc.data()!);
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

  // Ukuran grid per level (makin besar makin kompleks)
  static const _gridSizes = {1: 8, 2: 10, 3: 12, 4: 14};

  late final RxInt currentGridSize;
  int get gridSize => currentGridSize.value;

  // Grid warna — setiap sel punya warna (null = kosong/putih)
  late RxList<RxList<Rx<Color?>>> grid;

  // ─── Timer ───────────────────────────────────────────────────────────────

  /// Fallback default durasi timer (15 menit) jika AppConfigService belum tersedia
  static const int _timerDurasiDetik = 15 * 60;

  /// Durasi timer aktual — dari AppConfigService jika tersedia, fallback ke 15 menit
  int get _timerDurasi {
    if (Get.isRegistered<AppConfigService>()) {
      return Get.find<AppConfigService>().timerDurasiDetik.value;
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
      _persistState();
    } else if (state == AppLifecycleState.resumed) {
      _loadTimerState();
    }
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _persistState();
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
      Get.snackbar('Ups!', e.toString().replaceAll('Exception: ', ''),
          snackPosition: SnackPosition.TOP);
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
        Get.snackbar(
          'Warna Disalin',
          'Berhasil mengambil warna dari anyaman!',
          snackPosition: SnackPosition.TOP,
          backgroundColor: const Color(0xFF10B981),
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
        );
      } else {
        Get.snackbar(
          'Sel Kosong',
          'Kotak yang disentuh tidak memiliki warna!',
          snackPosition: SnackPosition.TOP,
          backgroundColor: const Color(0xFFEF4444),
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
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

    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        Color? selectedColor;
        switch (patternType) {
          case 'catur':
            selectedColor = ((row + col) % 2 == 0) ? color1 : color2;
            break;
          case 'vertikal':
            selectedColor = (col % 2 == 0) ? color3 : color4;
            break;
          case 'horizontal':
            selectedColor = (row % 2 == 0) ? color5 : color6;
            break;
          case 'zigzag':
            selectedColor = ((row + col) % 3 == 0) ? palette[1] : palette[7];
            break;
        }
        grid[row][col].value = selectedColor;
        update(['grid_${row}_$col']);
      }
    }
  }

  // Hitung jumlah sel yang terisi
  int get filledCells {
    int count = 0;
    for (final row in grid) {
      for (final cell in row) {
        if (cell.value != null) count++;
      }
    }
    return count;
  }

  int get totalCells => gridSize * gridSize;

  double get fillPercentage => totalCells == 0 ? 0 : filledCells / totalCells;

  // ─── Persist ─────────────────────────────────────────────────────────────

  Future<void> _persistState() async {
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
    final uid = Get.find<SessionController>().currentUser.value?.uid ?? '';
    
    try {
      await Get.find<DraftService>().deleteDraft(uid, 'anyaman', level);
      _session = null;
      debugPrint('✅ Draft anyaman berhasil dihapus: level $level');
    } catch (e) {
      debugPrint('Error deleting draft: $e');
    }

    final waktuPengerjaan = waktuTerpakai.value;
    final imageBytes = await captureCanvas();

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
        ),
        transition: Transition.fadeIn,
      );
    }
  }
}
