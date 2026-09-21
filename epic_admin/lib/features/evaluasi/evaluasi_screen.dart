import 'package:epic_admin/core/utils/evaluation_report.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:epic_admin/core/theme/admin_colors.dart';
import 'package:epic_admin/core/utils/file_download_helper.dart';
import 'package:flutter/material.dart';
import 'package:epic_admin/features/evaluasi/widgets/evaluasi_settings_tab.dart';
import 'package:epic_admin/features/evaluasi/widgets/student_responses_tab.dart';

class _EmotionOptionDraft {
  final String type;
  final TextEditingController iconController;
  final TextEditingController labelController;

  _EmotionOptionDraft({
    required this.type,
    required String icon,
    required String label,
  })  : iconController = TextEditingController(text: icon),
        labelController = TextEditingController(text: label);

  Map<String, String> toMap() => {
        'type': type,
        'icon': iconController.text.trim(),
        'label': labelController.text.trim(),
      };

  void dispose() {
    iconController.dispose();
    labelController.dispose();
  }
}

class EvaluasiScreen extends StatefulWidget {
  const EvaluasiScreen({super.key});

  @override
  State<EvaluasiScreen> createState() => _EvaluasiScreenState();
}

class _EvaluasiScreenState extends State<EvaluasiScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final TabController _tabController;

  // ─── TAB 1: PENGATURAN SOAL STATE ──────────────────────────────────────────
  String _selectedCategory = 'keris'; // 'keris', 'batik', 'anyaman'
  int _selectedLevel = 1; // 1, 2, 3, 4

  bool _isLoadingConfig = false;
  bool _isSavingConfig = false;

  String _status = 'disabled'; // 'mandatory', 'optional', 'disabled'
  bool _enableTts = true;
  final TextEditingController _feelingPromptCtrl = TextEditingController(
    text: 'Bagaimana perasaanmu selama membuat karya ini tadi?',
  );
  final List<TextEditingController> _questionControllers = [];
  final List<_EmotionOptionDraft> _emotionOptionDrafts = [];

  static const _defaultEmotionOptions = [
    {'type': 'bangga', 'icon': '🤩', 'label': 'Bangga Banget!'},
    {'type': 'senang', 'icon': '😄', 'label': 'Senang Sekali'},
    {'type': 'mikir_keras', 'icon': '🤔', 'label': 'Mikir Keras'},
    {'type': 'pantang_menyerah', 'icon': '💪', 'label': 'Pantang Menyerah'},
  ];

  // ─── TAB 2: RESPONS & JAWABAN SISWA STATE ───────────────────────────────────
  bool _isLoadingResponses = false;
  List<Map<String, dynamic>> _allResponses = [];
  List<Map<String, dynamic>> _filteredResponses = [];

  String _searchQuery = '';
  String _filterCategory = 'Semua Kategori';
  String _filterLevel = 'Semua Level';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 &&
          _allResponses.isEmpty &&
          !_isLoadingResponses) {
        _loadStudentResponses();
      }
    });
    _loadConfig();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _feelingPromptCtrl.dispose();
    _searchCtrl.dispose();
    for (var c in _questionControllers) {
      c.dispose();
    }
    for (final option in _emotionOptionDrafts) {
      option.dispose();
    }
    super.dispose();
  }

  String get _currentDocId => '${_selectedCategory}_$_selectedLevel';

  // ─── TAB 1 LOGIC: LOAD & SAVE CONFIG ───────────────────────────────────────
  Future<void> _loadConfig() async {
    setState(() => _isLoadingConfig = true);

    try {
      final doc = await _firestore
          .collection('evaluation_configs')
          .doc(_currentDocId)
          .get();

      for (var c in _questionControllers) {
        c.dispose();
      }
      _questionControllers.clear();
      _clearEmotionOptionDrafts();

      if (doc.exists) {
        final data = doc.data() ?? {};
        _status = data['status']?.toString() ?? 'disabled';
        _enableTts = data['enableTts'] != false;
        _feelingPromptCtrl.text = data['feelingPrompt']?.toString() ??
            'Bagaimana perasaanmu selama membuat karya ini tadi?';

        final rawQuestions = data['questions'];
        if (rawQuestions is List && rawQuestions.isNotEmpty) {
          for (var q in rawQuestions) {
            _questionControllers.add(TextEditingController(text: q.toString()));
          }
        }
        _loadEmotionOptionDrafts(data['emotionOptions']);
      } else {
        _status = 'disabled';
        _enableTts = true;
        _feelingPromptCtrl.text =
            'Bagaimana perasaanmu selama membuat karya ini tadi?';
        _loadEmotionOptionDrafts(null);
      }
    } catch (e) {
      debugPrint('⚠️ Error loading config: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat konfigurasi: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingConfig = false);
      }
    }
  }

  void _addQuestionField() {
    setState(() {
      _questionControllers.add(TextEditingController());
    });
  }

  void _removeQuestionField(int index) {
    setState(() {
      _questionControllers[index].dispose();
      _questionControllers.removeAt(index);
    });
  }

  void _clearEmotionOptionDrafts() {
    for (final option in _emotionOptionDrafts) {
      option.dispose();
    }
    _emotionOptionDrafts.clear();
  }

  void _loadEmotionOptionDrafts(dynamic rawOptions) {
    final options = rawOptions is List && rawOptions.isNotEmpty
        ? rawOptions.whereType<Map>().map(Map<String, dynamic>.from).toList()
        : _defaultEmotionOptions;
    for (var i = 0; i < options.length; i++) {
      final option = options[i];
      _emotionOptionDrafts.add(_EmotionOptionDraft(
        type: option['type']?.toString().trim().isNotEmpty == true
            ? option['type'].toString()
            : 'emotion_$i',
        icon: option['icon']?.toString() ?? '😊',
        label: option['label']?.toString() ?? 'Perasaan',
      ));
    }
  }

  void _addEmotionOption() {
    setState(() {
      _emotionOptionDrafts.add(_EmotionOptionDraft(
        type: 'emotion_${DateTime.now().microsecondsSinceEpoch}',
        icon: '😊',
        label: 'Perasaan baru',
      ));
    });
  }

  void _removeEmotionOption(int index) {
    if (_emotionOptionDrafts.length == 1) return;
    setState(() {
      _emotionOptionDrafts.removeAt(index).dispose();
    });
  }

  Future<void> _saveConfig() async {
    setState(() => _isSavingConfig = true);

    try {
      final List<String> questions = _questionControllers
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      final emotionOptions = _emotionOptionDrafts
          .map((option) => option.toMap())
          .where((option) =>
              option['icon']!.isNotEmpty && option['label']!.isNotEmpty)
          .toList();

      if (emotionOptions.isEmpty) {
        throw StateError('Tambahkan minimal satu pilihan perasaan.');
      }

      final data = {
        'categoryId': _selectedCategory,
        'levelId': _selectedLevel,
        'status': _status,
        'enableTts': _enableTts,
        'feelingPrompt': _feelingPromptCtrl.text.trim(),
        'emotionOptions': emotionOptions,
        'questions': questions,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('evaluation_configs')
          .doc(_currentDocId)
          .set(data, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Text(
                  'Konfigurasi evaluasi ${_selectedCategory.toUpperCase()} Level $_selectedLevel berhasil disimpan!',
                ),
              ],
            ),
            backgroundColor: AdminColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Gagal simpan config: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingConfig = false);
      }
    }
  }

  // ─── TAB 2 LOGIC: LOAD & FILTER RESPONSES ──────────────────────────────────
  Future<void> _loadStudentResponses() async {
    setState(() => _isLoadingResponses = true);

    try {
      // 1. Fetch seluruh respons evaluasi
      final evalSnap = await _firestore.collection('student_evaluations').get();

      // 2. Fetch seluruh users untuk mendapatkan username & email lengkap
      final usersSnap = await _firestore.collection('users').get();
      final Map<String, Map<String, dynamic>> userMap = {};
      for (var u in usersSnap.docs) {
        final userData = u.data();
        userMap[u.id] = userData;
        final uid = userData['uid']?.toString().trim() ?? '';
        if (uid.isNotEmpty) userMap[uid] = userData;
      }

      String firstNonEmpty(Iterable<dynamic> values, String fallback) {
        for (final value in values) {
          final text = value?.toString().trim() ?? '';
          if (text.isNotEmpty) return text;
        }
        return fallback;
      }

      final List<Map<String, dynamic>> list = [];

      for (var doc in evalSnap.docs) {
        final data = doc.data();
        final studentId = data['studentId']?.toString() ?? '';
        final userData = userMap[studentId] ?? {};

        final username = firstNonEmpty(
          [userData['username'], data['username']],
          '-',
        );
        final email = firstNonEmpty(
          [userData['email'], data['email']],
          '-',
        );
        final nama = firstNonEmpty(
          [userData['namaLengkap'], userData['nama'], data['studentName']],
          'Tanpa Nama',
        );
        final sekolah = firstNonEmpty(
          [userData['sekolah'], data['sekolah']],
          '-',
        );
        // Kelas yang ditampilkan adalah tingkat kelas pada profil siswa
        // (contoh: 4 SD), bukan kelas belajar yang diikuti dari guru.
        final kelas = EvaluationReport.schoolGrade(userData, data);

        final cat = data['categoryId']?.toString() ?? '-';
        final lvl = data['levelId'] ?? 1;

        DateTime dt = DateTime.now();
        if (data['submittedAt'] is Timestamp) {
          dt = (data['submittedAt'] as Timestamp).toDate();
        } else if (data['submittedAt'] is String) {
          dt = DateTime.tryParse(data['submittedAt']) ?? dt;
        }

        // Emotion data
        final emoMap = data['emotion'] is Map<String, dynamic>
            ? data['emotion'] as Map<String, dynamic>
            : {};
        final icon = emoMap['icon']?.toString() ?? '🤩';
        final label = emoMap['label']?.toString() ?? 'Bangga';
        final note = emoMap['note']?.toString() ?? '';

        // Responses list
        final rawResp = data['responses'];
        List<Map<String, dynamic>> respList = [];
        if (rawResp is List) {
          for (var r in rawResp) {
            if (r is Map) {
              respList.add(Map<String, dynamic>.from(r));
            }
          }
        }

        list.add({
          'id': doc.id,
          'studentId': studentId,
          'nama': nama,
          'username': username,
          'email': email,
          'sekolah': sekolah,
          'kelas': kelas,
          'kategori': cat,
          'level': lvl,
          'kategori_level': '${cat.toUpperCase()} - Level $lvl',
          'tanggal':
              '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
          'submitted_dt': dt,
          'emotikon': '$icon $label',
          'emotikon_note': note,
          'responses': EvaluationReport.ordered(respList),
        });
      }

      // Sort newest first
      list.sort((a, b) => (b['submitted_dt'] as DateTime)
          .compareTo(a['submitted_dt'] as DateTime));

      _allResponses = list;
      _applyFilterResponses();
    } catch (e) {
      debugPrint('❌ Gagal memuat respons siswa: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingResponses = false);
      }
    }
  }

  void _applyFilterResponses() {
    List<Map<String, dynamic>> temp = List.from(_allResponses);

    // Filter Search
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      temp = temp.where((r) {
        final n = r['nama'].toString().toLowerCase();
        final u = r['username'].toString().toLowerCase();
        final em = r['email'].toString().toLowerCase();
        final s = r['sekolah'].toString().toLowerCase();
        return n.contains(q) ||
            u.contains(q) ||
            em.contains(q) ||
            s.contains(q);
      }).toList();
    }

    // Filter Kategori
    if (_filterCategory != 'Semua Kategori') {
      temp = temp
          .where((r) =>
              r['kategori'].toString().toLowerCase() ==
              _filterCategory.toLowerCase())
          .toList();
    }

    // Filter Level
    if (_filterLevel != 'Semua Level') {
      final lvlNum = int.tryParse(_filterLevel.replaceAll('Level ', ''));
      if (lvlNum != null) {
        temp = temp.where((r) => r['level'] == lvlNum).toList();
      }
    }

    setState(() {
      _filteredResponses = temp;
    });
  }

  void _exportResponsesToCsv() {
    if (_filteredResponses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada data respons untuk diekspor.')),
      );
      return;
    }

    final buffer = EvaluationReport.csv(_filteredResponses);

    final dateStr =
        '${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}';
    FileDownloadHelper.downloadFile(
      buffer.toString(),
      'respons_evaluasi_penalaran_$dateStr.csv',
    );
  }

  Future<void> _exportResponsesToPdf() async {
    if (_filteredResponses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada respons untuk diekspor.')),
      );
      return;
    }
    final bytes = await EvaluationReport.pdf(_filteredResponses,
        scope: 'Kategori: $_filterCategory - Level: $_filterLevel');
    final now = DateTime.now();
    final date =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    FileDownloadHelper.downloadBytes(
      bytes,
      'respons_evaluasi_siswa_$date.pdf',
      'application/pdf',
    );
  }

  // ─── MAIN BUILD ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.background,
      body: Padding(
        padding:
            EdgeInsets.all(MediaQuery.sizeOf(context).width < 700 ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPageHeader(context),
            const SizedBox(height: 20),

            // Modern Segmented Control Tabs
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2F7),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Row(
                children: [
                  _buildCustomTab(
                      0, Icons.tune_rounded, 'Pengaturan Soal & Level'),
                  const SizedBox(width: 5),
                  _buildCustomTab(
                      1, Icons.forum_rounded, 'Respons & Jawaban Siswa'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Tab View Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // Tab 1: Pengaturan Soal
                  EvaluasiSettingsTab(
                    selectedCategory: _selectedCategory,
                    selectedLevel: _selectedLevel,
                    isLoadingConfig: _isLoadingConfig,
                    status: _status,
                    enableTts: _enableTts,
                    feelingPromptCtrl: _feelingPromptCtrl,
                    questionControllers: _questionControllers,
                    emotionOptionDrafts: _emotionOptionDrafts,
                    onCategorySelected: (val) {
                      setState(() => _selectedCategory = val);
                      _loadConfig();
                    },
                    onLevelSelected: (val) {
                      setState(() => _selectedLevel = val);
                      _loadConfig();
                    },
                    onStatusChanged: (val) => setState(() => _status = val),
                    onTtsChanged: (val) => setState(() => _enableTts = val),
                    onAddQuestion: _addQuestionField,
                    onRemoveQuestion: _removeQuestionField,
                    onAddEmotion: _addEmotionOption,
                    onRemoveEmotion: _removeEmotionOption,
                  ),

                  // Tab 2: Respons & Jawaban Siswa
                  StudentResponsesTab(
                    isLoading: _isLoadingResponses,
                    filteredResponses: _filteredResponses,
                    searchQuery: _searchQuery,
                    filterCategory: _filterCategory,
                    filterLevel: _filterLevel,
                    onSearchChanged: (val) {
                      _searchQuery = val;
                      _applyFilterResponses();
                    },
                    onCategoryChanged: (val) {
                      if (val != null) {
                        _filterCategory = val;
                        _applyFilterResponses();
                      }
                    },
                    onLevelChanged: (val) {
                      if (val != null) {
                        _filterLevel = val;
                        _applyFilterResponses();
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageHeader(BuildContext context) {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sistem Evaluasi & Refleksi Siswa',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AdminColors.textPrimary,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Kelola instrumen refleksi dan pantau jawaban siswa dalam satu tempat.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AdminColors.textSecondary,
              ),
        ),
      ],
    );

    final actions = _tabController.index == 0
        ? ElevatedButton.icon(
            onPressed: _isSavingConfig ? null : _saveConfig,
            icon: _isSavingConfig
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_rounded, size: 18),
            label: Text(
              _isSavingConfig ? 'Menyimpan...' : 'Simpan Pengaturan',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          )
        : Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _loadStudentResponses,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Muat Ulang'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AdminColors.textPrimary,
                  side: BorderSide(color: AdminColors.border),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _exportResponsesToCsv,
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Ekspor CSV'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _exportResponsesToPdf,
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text('Ekspor PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              title,
              const SizedBox(height: 14),
              Align(alignment: Alignment.centerLeft, child: actions),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: title),
            const SizedBox(width: 20),
            actions,
          ],
        );
      },
    );
  }

  // ─── CUSTOM TAB WIDGET ──────────────────────────────────────────────────────
  Widget _buildCustomTab(int index, IconData icon, String label) {
    final isSelected = _tabController.index == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _tabController.animateTo(index));
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [
                      AdminColors.primary,
                      AdminColors.primary.withValues(alpha: 0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AdminColors.primary.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: EdgeInsets.all(isSelected ? 6 : 0),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF64748B),
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: MediaQuery.sizeOf(context).width < 600 ? 11 : 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
