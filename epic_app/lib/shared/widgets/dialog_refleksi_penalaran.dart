import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:epic_app/core/constants/app_assets.dart';
import 'package:epic_app/core/services/student_evaluation_service.dart';
import 'package:epic_app/data/models/evaluation_config_model.dart';
import 'package:epic_app/data/models/student_evaluation_model.dart';
import 'package:epic_app/data/models/user_model.dart';

/// Dialog Refleksi Penalaran Murid (Modern Clean White Card).
/// Desain presisi sesuai mockup referensi (Gambar 1) & visualizer 4 kapsul (Gambar 2).
class DialogRefleksiPenalaran extends StatefulWidget {
  final EvaluationConfigModel config;
  final UserModel currentUser;
  final String categoryId;
  final int levelId;

  const DialogRefleksiPenalaran({
    super.key,
    required this.config,
    required this.currentUser,
    required this.categoryId,
    required this.levelId,
  });

  /// Menampilkan dialog.
  /// Return true jika siswa berhasil submit jawaban atau menekan Lewati.
  /// Return false atau null jika siswa menutup pop-up / batal kirim (kembali ke studio).
  static Future<bool?> show({
    required BuildContext context,
    required EvaluationConfigModel config,
    required UserModel currentUser,
    required String categoryId,
    required int levelId,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: config.isOptional,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) => DialogRefleksiPenalaran(
        config: config,
        currentUser: currentUser,
        categoryId: categoryId,
        levelId: levelId,
      ),
    );
    return result;
  }

  @override
  State<DialogRefleksiPenalaran> createState() =>
      _DialogRefleksiPenalaranState();
}

class _DialogRefleksiPenalaranState extends State<DialogRefleksiPenalaran>
    with TickerProviderStateMixin {
  // TTS (Text-to-Speech)
  late final FlutterTts _tts;
  bool _isTtsSpeaking = false;
  bool _isTtsReady = false;
  late final AnimationController _ttsAnimCtrl;

  // Live Transkrip via SpeechToText (Google on-device STT)
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;
  // Android mengirim status `done`/`notListening` dan error untuk sesi yang
  // sama. Tanpa penjadwalan tunggal, kedua callback dapat memulai recognizer
  // bersamaan dan memicu `error_busy` (kode Android 8).
  Timer? _restartTimer;
  bool _restartScheduled = false;
  bool _isStartingSpeech = false;
  bool _recognizerReportedStopped = false;
  int _restartAttempts = 0;
  int _speechSession = 0;
  double _soundLevel = 0.0;
  String _baseRecognizedText = '';
  String _sttLocaleId = 'id-ID'; // akan di-update saat init
  late final AnimationController _waveAnimCtrl;

  // State Soal & Jawaban
  int _currentStep = 0;
  late final List<String> _questions;
  final Map<int, String> _textAnswers = {};
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _emotionNoteController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();
  bool _isTextFocused = false;
  String _selectedEmotion = 'bangga';
  bool _isSubmitting = false;

  // Color Palette Modern Clean White (sesuai Gambar 1 & Gambar 2)
  static const Color _cardBg = Color(0xFFFFFFFF);
  static const Color _speechBubbleBg = Color(0xFFEEF5FF);
  static const Color _textPrimary = Color(0xFF1E293B);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _inputBorder = Color(0xFFE2E8F0);
  static const Color _inputBg = Color(0xFFF8FAFC);
  static const Color _primaryBlue = Color(0xFF3B82F6);
  static const Color _blueLight = Color(0xFFEFF6FF);

  @override
  void initState() {
    super.initState();
    _questions = widget.config.activeQuestions;
    _selectedEmotion = _emotionOptions.first.type;

    _ttsAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..repeat(reverse: true);

    _waveAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _initSpeech();
    _initTts();

    // Deteksi fokus textfield untuk efek border biru
    _textFocusNode.addListener(() {
      if (mounted) setState(() => _isTextFocused = _textFocusNode.hasFocus);
    });
  }

  Future<void> _initSpeech() async {
    try {
      // 1. Minta izin mikrofon secara eksplisit via permission_handler
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        debugPrint('[STT] mic permission not granted: $micStatus');
        if (mounted) {
          Get.snackbar(
            'Izin Mikrofon Diperlukan 🎙️',
            'Buka Pengaturan > Aplikasi > Epic > Izin > aktifkan Mikrofon',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.redAccent,
            colorText: Colors.white,
            duration: const Duration(seconds: 5),
          );
        }
        return;
      }

      // 2. Inisialisasi STT engine
      _speechAvailable = await _speech.initialize(
        debugLogging: true,
        onStatus: (status) {
          debugPrint('[STT] status: $status');
          if (status == stt.SpeechToText.listeningStatus) {
            // Sesi baru benar-benar sudah aktif, pulihkan penghitung retry.
            _restartAttempts = 0;
            _recognizerReportedStopped = false;
          }
          if (mounted &&
              _isListening &&
              (status == stt.SpeechToText.doneStatus ||
                  status == stt.SpeechToText.notListeningStatus)) {
            _recognizerReportedStopped = true;
            _commitLiveTranscript();
            _scheduleListeningRestart();
          }
        },
        onError: (err) {
          debugPrint('[STT] error: ${err.errorMsg} permanent:${err.permanent}');
          if (!mounted) return;
          if (_isListening) {
            _commitLiveTranscript();
            if (err.errorMsg == 'error_speech_timeout' ||
                err.errorMsg == 'error_no_match') {
              // Timeout biasa: restart otomatis
              _scheduleListeningRestart();
            } else if (err.errorMsg == 'error_busy') {
              // Beri Android waktu untuk melepas recognizer lama sebelum retry.
              _scheduleListeningRestart(
                delay: const Duration(milliseconds: 1200),
              );
            } else {
              // Error permanen: hentikan sesi
              if (mounted) {
                setState(() {
                  _isListening = false;
                  _soundLevel = 0.0;
                });
                _waveAnimCtrl.stop();
              }
            }
          }
        },
      );
      debugPrint('[STT] available: $_speechAvailable');

      // 3. Deteksi locale Bahasa Indonesia yang tersedia di device
      if (_speechAvailable) {
        final locales = await _speech.locales();
        debugPrint(
            '[STT] locales: ${locales.map((l) => l.localeId).join(', ')}');
        // Cari id-ID, id_ID, atau apapun yang diawali 'id'
        final idLocale = locales.firstWhere(
          (l) => l.localeId.toLowerCase().startsWith('id'),
          orElse: () => stt.LocaleName('', ''),
        );
        if (idLocale.localeId.isNotEmpty) {
          _sttLocaleId = idLocale.localeId;
          debugPrint('[STT] using locale: $_sttLocaleId');
        } else {
          // Fallback: gunakan locale default device
          _sttLocaleId = '';
          debugPrint('[STT] id locale not found, using device default');
        }
      }
    } catch (e) {
      debugPrint('[STT] init error: $e');
    }
  }

  // Menjadwalkan tepat satu restart setelah recognizer Android selesai bersih.
  // Callback status dan error sering tiba hampir bersamaan pada Android.
  void _scheduleListeningRestart({
    Duration delay = const Duration(milliseconds: 750),
  }) {
    if (!mounted || !_isListening || !_speechAvailable || _restartScheduled) {
      return;
    }

    final session = _speechSession;
    _restartScheduled = true;
    _restartTimer = Timer(delay, () {
      _restartScheduled = false;
      if (!mounted ||
          session != _speechSession ||
          !_isListening ||
          !_speechAvailable) {
        return;
      }

      // Pada sebagian perangkat Android, callback `notListening` datang lebih
      // dulu daripada pembaruan properti isListening. Jangan berhenti di sini:
      // coba lagi sampai recognizer benar-benar lepas.
      if (_speech.isListening || _isStartingSpeech) {
        _restartAttempts++;
        // `notListening` adalah sumber kebenaran; beberapa perangkat terlambat
        // memperbarui properti isListening sesudah callback tersebut.
        final shouldClearRecognizer = _recognizerReportedStopped
            ? _restartAttempts >= 2
            : _restartAttempts >= 3;
        if (shouldClearRecognizer) {
          debugPrint('[STT] recognizer stale, cancelling before restart');
          _speech.cancel();
        }
        _scheduleListeningRestart(
          delay: const Duration(milliseconds: 900),
        );
        return;
      }
      _startListeningSession(session);
    });
  }

  Future<void> _startListeningSession(int session) async {
    if (!mounted ||
        session != _speechSession ||
        !_isListening ||
        !_speechAvailable) {
      return;
    }
    if (_speech.isListening || _isStartingSpeech) {
      _scheduleListeningRestart(delay: const Duration(milliseconds: 900));
      return;
    }

    _isStartingSpeech = true;
    _recognizerReportedStopped = false;
    try {
      // Setiap sesi hanya menambahkan hasilnya ke teks yang sudah dikonfirmasi.
      // Jangan gunakan hasil parsial sesi sebelumnya sebagai hasil sesi baru.
      _baseRecognizedText = _activeTranscriptController.text.trim();
      await _speech.listen(
        onResult: (result) => _onSpeechResult(result, session),
        listenOptions: stt.SpeechListenOptions(
          localeId: _sttLocaleId,
          partialResults: true,
          listenMode: stt.ListenMode.dictation,
          cancelOnError: false,
          listenFor: const Duration(seconds: 60),
          pauseFor: const Duration(seconds: 6),
        ),
        onSoundLevelChange: (level) {
          if (mounted && session == _speechSession && _isListening) {
            setState(() => _soundLevel = (level + 2.0).clamp(0.0, 10.0));
          }
        },
      );
    } catch (e) {
      debugPrint('[STT] restart error: $e');
      _scheduleListeningRestart(
        delay: const Duration(milliseconds: 1200),
      );
    } finally {
      _isStartingSpeech = false;
    }
  }

  Future<void> _initTts() async {
    _tts = FlutterTts();
    try {
      await _tts.setLanguage('id-ID');
      await _tts.setSpeechRate(0.48);
      await _tts.setPitch(1.1);
      _tts.setStartHandler(() {
        if (mounted) setState(() => _isTtsSpeaking = true);
      });
      _tts.setCompletionHandler(() {
        if (mounted) setState(() => _isTtsSpeaking = false);
      });
      _tts.setErrorHandler((_) {
        if (mounted) setState(() => _isTtsSpeaking = false);
      });
      _isTtsReady = true;
      if (widget.config.enableTts) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _speakCurrentPromptAutomatically();
        });
      }
    } catch (e) {
      debugPrint('TTS Init Error: $e');
    }
  }

  @override
  void dispose() {
    _speechSession++;
    _restartTimer?.cancel();
    _ttsAnimCtrl.dispose();
    _waveAnimCtrl.dispose();
    _tts.stop();
    if (_speech.isListening) _speech.stop();
    _textController.dispose();
    _emotionNoteController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  bool get _isEmotionStep => _currentStep >= _questions.length;

  List<EvaluationEmotionOption> get _emotionOptions =>
      widget.config.emotionOptions;

  TextEditingController get _activeTranscriptController =>
      _isEmotionStep ? _emotionNoteController : _textController;

  void _saveActiveTranscript(String text) {
    if (!_isEmotionStep) {
      _textAnswers[_currentStep] = text;
    }
  }

  // ─── TTS Handler ──────────────────────────────────────────────────────────
  Future<void> _speakCurrentPrompt() async {
    if (!widget.config.enableTts || !_isTtsReady) return;
    if (_isTtsSpeaking) {
      await _tts.stop();
      if (mounted) setState(() => _isTtsSpeaking = false);
      return;
    }
    final text =
        _isEmotionStep ? widget.config.feelingPrompt : _questions[_currentStep];
    await _tts.speak(text);
  }

  Future<void> _speakCurrentPromptAutomatically() async {
    if (!mounted || !widget.config.enableTts || !_isTtsReady) return;
    final text =
        _isEmotionStep ? widget.config.feelingPrompt : _questions[_currentStep];
    await _tts.stop();
    if (mounted) await _tts.speak(text);
  }

  // ─── Live Transkrip via SpeechToText ───────────────────────────────────────
  Future<void> _toggleListening() async {
    if (_isListening) {
      await _stopListening();
      return;
    }

    if (!_speechAvailable) {
      // Coba init ulang jika belum siap
      await _initSpeech();
      if (!_speechAvailable) {
        Get.snackbar(
          'Mikrofon Tidak Tersedia 🎙️',
          'Aktifkan izin mikrofon di pengaturan HP ya!',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.redAccent,
          colorText: Colors.white,
          borderRadius: 14,
          margin: const EdgeInsets.all(16),
        );
        return;
      }
    }

    // Hentikan TTS jika sedang berputar
    await _tts.stop();
    // Saat rekam jawaban perasaan, keyboard tidak boleh menutupi indikator
    // kapsul suara maupun area transkrip.
    if (mounted) FocusScope.of(context).unfocus();

    _speechSession++;
    _restartTimer?.cancel();
    _restartScheduled = false;
    _isStartingSpeech = false;
    _recognizerReportedStopped = false;
    _restartAttempts = 0;
    setState(() {
      _isListening = true;
      _soundLevel = 0.0;
      // Simpan teks yang sudah ada sebagai base
      _baseRecognizedText = _activeTranscriptController.text.trim();
    });

    _waveAnimCtrl.repeat();

    try {
      await _startListeningSession(_speechSession);
      debugPrint('[STT] listening started, locale: $_sttLocaleId');
    } catch (e) {
      debugPrint('⚠️ [STT] listen error: $e');
      if (mounted) {
        setState(() {
          _isListening = false;
          _soundLevel = 0.0;
        });
        _waveAnimCtrl.stop();
      }
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result, int session) {
    // Abaikan callback terlambat dari sesi yang telah berhenti atau restart.
    if (!mounted || !_isListening || session != _speechSession) return;
    final words = result.recognizedWords.trim();
    if (words.isNotEmpty) {
      // Hasil parsial Android bisa berubah-ubah saat pengguna berhenti sejenak.
      // Gabungkan dengan teks yang sudah terkunci, jangan menggantikannya.
      final fullText = _mergeTranscript(_baseRecognizedText, words);
      setState(() {
        _activeTranscriptController.value = TextEditingValue(
          text: fullText,
          selection: TextSelection.collapsed(offset: fullText.length),
        );
        _saveActiveTranscript(fullText);
      });
      // Android dapat mengirim hasil parsial baru yang lebih pendek dari hasil
      // sebelumnya, bahkan tanpa status selesai. Karena itu, setiap hasil yang
      // sudah tampil langsung menjadi dasar permanen untuk hasil berikutnya.
      _baseRecognizedText = fullText;
      debugPrint('[STT] result final:${result.finalResult} text:$fullText');
    }
  }

  // Simpan hasil parsial sebelum Android menutup sesi karena jeda bicara.
  // Ini membuat kata-kata yang sudah muncul tetap ada saat sesi berikutnya mulai.
  void _commitLiveTranscript() {
    final transcript = _activeTranscriptController.text.trim();
    if (transcript.isEmpty) return;
    _baseRecognizedText = transcript;
    _saveActiveTranscript(transcript);
  }

  String _mergeTranscript(String savedText, String newText) {
    final saved = savedText.trim();
    final incoming = newText.trim();
    if (saved.isEmpty || incoming.isEmpty) {
      return saved.isEmpty ? incoming : saved;
    }

    final savedWords = saved.split(RegExp(r'\s+'));
    final incomingWords = incoming.split(RegExp(r'\s+'));
    bool sameWord(String left, String right) =>
        left.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '') ==
        right.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

    // Jika recognizer mengirim ulang keseluruhan kalimat atau bagian yang sudah
    // tersimpan, pertahankan versi yang lebih lengkap.
    if (incomingWords.length <= savedWords.length &&
        List.generate(incomingWords.length, (i) => i).every(
          (i) => sameWord(savedWords[i], incomingWords[i]),
        )) {
      return saved;
    }
    if (savedWords.length <= incomingWords.length &&
        List.generate(savedWords.length, (i) => i).every(
          (i) => sameWord(savedWords[i], incomingWords[i]),
        )) {
      return incoming;
    }

    // Jika sesi baru dimulai dari kata terakhir sesi lama, hilangkan bagian yang
    // tumpang tindih sebelum menambahkannya.
    final maxOverlap = math.min(savedWords.length, incomingWords.length);
    for (var overlap = maxOverlap; overlap > 0; overlap--) {
      final matches = List.generate(overlap, (i) => i).every(
        (i) => sameWord(
          savedWords[savedWords.length - overlap + i],
          incomingWords[i],
        ),
      );
      if (matches) {
        return '$saved ${incomingWords.skip(overlap).join(' ')}'.trim();
      }
    }

    return '$saved $incoming';
  }

  Future<void> _stopListening() async {
    // Ubah intent pengguna terlebih dahulu. `stop()` dapat memicu callback
    // notListening secara sinkron; callback itu tidak boleh menjadwalkan start.
    _speechSession++;
    _restartTimer?.cancel();
    _restartScheduled = false;
    _isStartingSpeech = false;
    _recognizerReportedStopped = false;
    _restartAttempts = 0;
    _commitLiveTranscript();
    if (mounted) {
      setState(() {
        _isListening = false;
        _soundLevel = 0.0;
      });
    }
    _waveAnimCtrl.stop();

    try {
      await _speech.stop();
    } catch (e) {
      debugPrint('[STT] stop error: $e');
    }
  }

  // ─── Step Navigation ───────────────────────────────────────────────────────
  void _saveCurrentText() {
    if (!_isEmotionStep) {
      _textAnswers[_currentStep] = _textController.text.trim();
    }
  }

  void _loadStep(int step) {
    _tts.stop();
    if (_isListening) _stopListening();
    if (step < _questions.length) {
      _textController.text = _textAnswers[step] ?? '';
    }
    if (widget.config.enableTts) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _speakCurrentPromptAutomatically();
      });
    }
  }

  void _handleCancelToCanvas() {
    _tts.stop();
    if (_isListening) _stopListening();
    Navigator.of(context).pop(false);
  }

  void _handleSkip() {
    _tts.stop();
    if (_isListening) _stopListening();
    Navigator.of(context).pop(true);
  }

  void _handleNextOrSubmit() {
    if (_isListening) _stopListening();
    _saveCurrentText();

    if (!_isEmotionStep) {
      // Validasi jika wajib diisi
      if (widget.config.isMandatory) {
        final answer = (_textAnswers[_currentStep] ?? '').trim();
        if (answer.isEmpty) {
          Get.snackbar(
            'Yuk Ceritakan! 🌟',
            'Ketik jawabanmu atau tekan tombol mic untuk berbicara ya!',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: _primaryBlue,
            colorText: Colors.white,
            borderRadius: 16,
            margin: const EdgeInsets.all(16),
          );
          return;
        }
      }

      setState(() {
        _currentStep++;
        _loadStep(_currentStep);
      });
    } else {
      _submitAllAnswers();
    }
  }

  // ─── Submit Answers ────────────────────────────────────────────────────────
  Future<void> _submitAllAnswers() async {
    _tts.stop();
    if (_isListening) await _stopListening();

    setState(() => _isSubmitting = true);

    try {
      final service = StudentEvaluationService();
      final items = <QuestionResponseItem>[];

      for (int i = 0; i < _questions.length; i++) {
        final text = _textAnswers[i] ?? '';
        items.add(QuestionResponseItem(
          questionIndex: i,
          questionText: _questions[i],
          audioUrl: null,
          transcript: text,
          manualText: text,
        ));
      }

      final em = _emotionOptions.firstWhere(
        (e) => e.type == _selectedEmotion,
        orElse: () => _emotionOptions.first,
      );

      final saved = await service.saveEvaluation(
        StudentEvaluationModel(
          id: '${widget.currentUser.uid}_${widget.categoryId.toLowerCase()}_${widget.levelId}',
          studentId: widget.currentUser.uid,
          studentName: widget.currentUser.namaLengkap,
          sekolah: widget.currentUser.sekolah,
          kelas: widget.currentUser.kelas,
          kelasIds: widget.currentUser.kelasIds,
          avatarGender: widget.currentUser.karakterAktif.contains('ipeh')
              ? 'perempuan'
              : 'laki-laki',
          categoryId: widget.categoryId,
          levelId: widget.levelId,
          submittedAt: DateTime.now(),
          emotion: StudentEmotionItem(
            type: em.type,
            icon: em.icon,
            label: em.label,
            note: _emotionNoteController.text.trim(),
          ),
          responses: items,
        ),
      );

      if (!saved) {
        throw StateError('Respons belum tersimpan ke server.');
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('❌ Submit Error: $e');
      if (mounted) {
        setState(() => _isSubmitting = false);
        Get.snackbar(
          'Gagal Menyimpan',
          'Periksa koneksi internetmu dan coba lagi ya!',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.redAccent,
          colorText: Colors.white,
        );
      }
    }
  }

  // ─── Build UI Utama (Persis Mockup Gambar 1 & 2) ──────────────────────────
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isKeyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
          // Struktur dialog selalu sama. Hanya batas tingginya yang berubah
          // secara alami saat keyboard muncul, sehingga perpindahannya tidak
          // terasa seperti layout diganti mendadak.
          final cardHeight = math.min(
            constraints.maxHeight * (isKeyboardVisible ? 0.88 : 0.92),
            620.0,
          );
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 410,
              maxHeight: cardHeight,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Container Utama Kartu Putih Bersih
                Container(
                  decoration: BoxDecoration(
                    color: _cardBg,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 28,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Flexible(
                        fit: FlexFit.loose,
                        child: SingleChildScrollView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildHeaderSection(),
                              _isEmotionStep
                                  ? _buildEmotionGrid()
                                  : _buildInputArea(),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildBottomActionBar(),
                    ],
                  ),
                ),

                // ── Tombol X – pojok kanan atas kartu di dalam padding yang aman ──
                Positioned(
                  top: 14,
                  right: 14,
                  child: GestureDetector(
                    onTap: _handleCancelToCanvas,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 17,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── Header: Karakter Besar Menempel Langsung ke Box Teks ──────────────────
  Widget _buildHeaderSection() {
    final titleText =
        _isEmotionStep ? widget.config.feelingPrompt : _questions[_currentStep];

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.end, // Karakter menempel di dasar header
      children: [
        // ── Karakter 3D Lebih Besar (evaluasi_mascot.png), menempel ke input box ──
        SizedBox(
          width: 120,
          height: 148,
          child: Image.asset(
            AppAssets.evaluasiMascot,
            fit: BoxFit.contain,
            alignment: Alignment.bottomCenter,
            errorBuilder: (_, __, ___) => Image.asset(
              AppAssets.epiStatic,
              fit: BoxFit.contain,
              alignment: Alignment.bottomCenter,
            ),
          ),
        ),

        // Ekor Segitiga & Balon Percakapan
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(
                bottom: 12, right: 28), // Beri ruang kanan untuk tombol X
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Ekor Segitiga menunjuk ke arah karakter
                CustomPaint(
                  size: const Size(8, 14),
                  painter: _LeftTriangleTailPainter(color: _speechBubbleBg),
                ),

                // Balon Soal
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                    decoration: const BoxDecoration(
                      color: _speechBubbleBg,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Teks soal dari admin panel SAJA
                        Expanded(
                          child: Text(
                            titleText,
                            style: GoogleFonts.nunito(
                              color: _textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              height: 1.35,
                            ),
                          ),
                        ),
                        if (widget.config.enableTts) ...[
                          const SizedBox(width: 8),

                          // Tombol Speaker TTS + Animasi Denyut
                          GestureDetector(
                            onTap: _speakCurrentPrompt,
                            child: AnimatedBuilder(
                              animation: _ttsAnimCtrl,
                              builder: (context, _) {
                                final scale = _isTtsSpeaking
                                    ? 1.0 +
                                        0.14 *
                                            math.sin(_ttsAnimCtrl.value *
                                                2 *
                                                math.pi)
                                    : 1.0;
                                return Transform.scale(
                                  scale: scale,
                                  child: Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: _isTtsSpeaking
                                          ? _primaryBlue
                                          : const Color(0xFFDBEAFE),
                                      shape: BoxShape.circle,
                                      boxShadow: _isTtsSpeaking
                                          ? [
                                              BoxShadow(
                                                color: _primaryBlue.withValues(
                                                    alpha: 0.45),
                                                blurRadius: 10,
                                                spreadRadius: 2,
                                              ),
                                            ]
                                          : [],
                                    ),
                                    child: Icon(
                                      _isTtsSpeaking
                                          ? Icons.volume_up_rounded
                                          : Icons.volume_up_outlined,
                                      color: _isTtsSpeaking
                                          ? Colors.white
                                          : _primaryBlue,
                                      size: 18,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Input Area: Single Clean Box (Tanpa Kotak Putih Kaku di Dalam) ────────
  Widget _buildInputArea() {
    final isBorderActive = _isListening || _isTextFocused;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      height: 150,
      decoration: BoxDecoration(
        color: isBorderActive ? const Color(0xFFF0F7FF) : _inputBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isBorderActive ? _primaryBlue : _inputBorder,
          width: isBorderActive ? 2.0 : 1.5,
        ),
        boxShadow: isBorderActive
            ? [
                BoxShadow(
                  color: _primaryBlue.withValues(alpha: 0.12),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : [],
      ),
      child: _isListening
          // ── Mode Merekam: 4 Kapsul Animatif Sesuai Gambar 2 + Live Transkrip ──
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                SizedBox(
                  height: 52,
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _waveAnimCtrl,
                      builder: (context, _) {
                        return _VoiceWaveWidget(
                          animValue: _waveAnimCtrl.value,
                          soundLevel: _soundLevel,
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      _textController.text.isNotEmpty
                          ? _textController.text
                          : 'Bicara sekarang... 🎙️',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        color: _textController.text.isNotEmpty
                            ? _textPrimary
                            : const Color(0xFF94A3B8),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            )
          // ── Mode Mengetik: Bersih, Transparan (Neutralize Theme filled: true) ──
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      focusNode: _textFocusNode,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      maxLength: 500,
                      onChanged: (val) {
                        setState(() => _textAnswers[_currentStep] = val);
                      },
                      style: GoogleFonts.nunito(
                        color: _textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.45,
                      ),
                      // Neutralize global theme filled: true agar tidak ada kotak putih kaku
                      decoration: InputDecoration(
                        filled: false,
                        fillColor: Colors.transparent,
                        hintText: 'Tulis jawabanmu di sini...',
                        hintStyle: GoogleFonts.nunito(
                          color: const Color(0xFF94A3B8),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                        counterText: '',
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),

                  // Counter karakter 0/500
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${_textController.text.length}/500',
                      style: GoogleFonts.nunito(
                        color: _textController.text.length > 450
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF94A3B8),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ─── Emotikon Grid (Langkah Terakhir) ──────────────────────────────────────
  Widget _buildEmotionGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.3,
          ),
          itemCount: _emotionOptions.length,
          itemBuilder: (ctx, i) {
            final opt = _emotionOptions[i];
            final isSelected = _selectedEmotion == opt.type;

            return GestureDetector(
              onTap: () => setState(() => _selectedEmotion = opt.type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isSelected ? _speechBubbleBg : _inputBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? _primaryBlue : _inputBorder,
                    width: isSelected ? 1.8 : 1.0,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Text(opt.icon, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        opt.label,
                        style: GoogleFonts.nunito(
                          color: isSelected ? _primaryBlue : _textPrimary,
                          fontWeight:
                              isSelected ? FontWeight.w800 : FontWeight.w600,
                          fontSize: 11,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 112,
          decoration: BoxDecoration(
            color: _isListening ? const Color(0xFFF0F7FF) : _inputBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isListening ? _primaryBlue : _inputBorder,
              width: _isListening ? 1.8 : 1,
            ),
          ),
          child: _isListening
              ? _buildEmotionListeningPreview()
              : Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ceritakan perasaanmu (opsional)',
                        style: GoogleFonts.nunito(
                          color: _textSecondary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: TextField(
                          controller: _emotionNoteController,
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          style: GoogleFonts.nunito(
                            color: _textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                          decoration: InputDecoration(
                            filled: false,
                            fillColor: Colors.transparent,
                            hintText:
                                'Tekan mikrofon lalu ceritakan perasaanmu...',
                            hintStyle: GoogleFonts.nunito(
                              color: const Color(0xFF94A3B8),
                              fontSize: 12,
                            ),
                            border: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildEmotionListeningPreview() {
    final transcript = _emotionNoteController.text.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 46,
            child: Center(
              child: AnimatedBuilder(
                animation: _waveAnimCtrl,
                builder: (context, _) => _VoiceWaveWidget(
                  animValue: _waveAnimCtrl.value,
                  soundLevel: _soundLevel,
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                transcript.isEmpty
                    ? 'Dengarkan, aku sedang mencatat...'
                    : transcript,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  color: transcript.isEmpty
                      ? const Color(0xFF64748B)
                      : _textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Bottom Action Bar (Mic, Lewati jika opsional, Kirim) ─────────────────
  Widget _buildBottomActionBar() {
    if (_isSubmitting) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(_primaryBlue),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        // 1. Tombol Mikrofon Bulat di Kiri (Gambar 1)
        GestureDetector(
          onTap: _toggleListening,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _isListening ? _primaryBlue : _blueLight,
              shape: BoxShape.circle,
              border: Border.all(
                color: _isListening ? _primaryBlue : const Color(0xFFDBEAFE),
                width: 1.2,
              ),
              boxShadow: _isListening
                  ? [
                      BoxShadow(
                        color: _primaryBlue.withValues(alpha: 0.45),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ]
                  : [],
            ),
            child: Icon(
              _isListening ? Icons.stop_rounded : Icons.mic_rounded,
              color: _isListening ? Colors.white : _primaryBlue,
              size: 22,
            ),
          ),
        ),

        const Spacer(),

        // 2. Tombol "Lewati" di Tengah (HANYA MUNCUL JIKA config.isOptional)
        if (widget.config.isOptional) ...[
          GestureDetector(
            onTap: _handleSkip,
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _inputBorder, width: 1.4),
              ),
              alignment: Alignment.center,
              child: Text(
                'Lewati',
                style: GoogleFonts.nunito(
                  color: _textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],

        // 3. Tombol "Kirim" / "Lanjut" Biru di Kanan (Gambar 1)
        GestureDetector(
          onTap: _handleNextOrSubmit,
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_primaryBlue, Color(0xFF2563EB)],
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: _primaryBlue.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isEmotionStep
                      ? Icons.rocket_launch_rounded
                      : Icons.send_rounded,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  _isEmotionStep
                      ? 'Kirim'
                      : (_currentStep < _questions.length - 1
                          ? 'Lanjut'
                          : 'Kirim'),
                  style: GoogleFonts.nunito(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Visualizer 4 Kapsul Gelombang Suara (Sesuai Gambar 2) ───────────────────
class _VoiceWaveWidget extends StatelessWidget {
  final double animValue;
  final double soundLevel;

  const _VoiceWaveWidget({
    required this.animValue,
    required this.soundLevel,
  });

  @override
  Widget build(BuildContext context) {
    final multipliers = [1.1, 2.2, 1.9, 1.3];
    final phaseOffsets = [0.0, 0.5, 1.0, 1.5];

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        // Dinamika gelombang harmonik
        final wave = math.sin((animValue * 2 * math.pi) + phaseOffsets[i]);
        final normalizedLevel = soundLevel.clamp(0.0, 12.0);
        final isQuiet = normalizedLevel < 0.3;

        // Saat hening: ritme nafas lembut (15px - 18px).
        // Saat ada suara: meliuk dan memantul proporsional terhadap amplitudo suara anak!
        final double baseH = isQuiet ? 15.0 + 3.0 * wave : 18.0;
        // Sejumlah perangkat mengirim nilai level yang datar saat merekam.
        // Denyut kecil ini membuat indikator tetap terasa aktif tanpa
        // mengubah area teks atau status rekam pengguna.
        final pulse = isQuiet ? 0.0 : 4.0 * wave * multipliers[i];
        final double targetHeight = isQuiet
            ? baseH
            : (baseH + normalizedLevel * 2.35 * multipliers[i] + pulse)
                .clamp(15.0, 52.0);

        return Container(
          width: 15,
          height: targetHeight,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF60A5FA), Color(0xFF2563EB)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3B82F6)
                    .withValues(alpha: isQuiet ? 0.25 : 0.45),
                blurRadius: isQuiet ? 6 : 10,
                spreadRadius: isQuiet ? 0 : 1,
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ─── Ekor Balon Segitiga Menunjuk ke Kiri (ke arah Karakter) ─────────────────
class _LeftTriangleTailPainter extends CustomPainter {
  final Color color;

  _LeftTriangleTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paintFill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    // Segitiga mengarah ke kiri
    path.moveTo(size.width, 0);
    path.lineTo(0, size.height / 2);
    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paintFill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
