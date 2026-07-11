import 'package:epic_admin/core/theme/admin_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OnboardingFormScreen extends StatefulWidget {
  final String id;
  const OnboardingFormScreen({super.key, required this.id});

  @override
  State<OnboardingFormScreen> createState() => _OnboardingFormScreenState();
}

class _OnboardingFormScreenState extends State<OnboardingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _konteksBudayaController;
  late TextEditingController _materiMatematikaController;
  bool _isLoading = true;
  final List<Map<String, dynamic>> _criteriaList = [];

  @override
  void initState() {
    super.initState();
    _konteksBudayaController = TextEditingController();
    _konteksBudayaController.addListener(() => setState(() {}));
    _materiMatematikaController = TextEditingController();
    _materiMatematikaController.addListener(() => setState(() {}));
    _loadOnboardingData();
  }

  Map<String, String> _getDefaultValues(String id) {
    final parts = id.split('_');
    final String kategori = parts.isNotEmpty ? parts[0].toLowerCase() : '';
    final int level = parts.length > 1 ? int.tryParse(parts[1]) ?? 1 : 1;

    switch ('${kategori}_$level') {
      case 'batik_1':
        return {
          'konteksBudaya': 'Batik Madura memiliki motif khas dengan pola geometris berulang. Level ini mengajarkan pola garis berulang.',
          'materiMatematika': 'Pola bilangan, pengulangan, dan barisan sederhana.',
        };
      case 'batik_2':
        return {
          'konteksBudaya': 'Batik Madura memiliki sifat simetri cermin pada banyak motifnya. Level ini mengajarkan simetri.',
          'materiMatematika': 'Simetri cermin (refleksi), sumbu simetri, dan pencerminan bangun datar.',
        };
      case 'batik_3':
        return {
          'konteksBudaya': 'Motif geometri khas Madura: gentongan, tanjung bumi, bangkalan. Level ini menggunakan bangun datar.',
          'materiMatematika': 'Bangun datar: persegi, segitiga, lingkaran, belah ketupat. Minimal 3 jenis.',
        };
      case 'batik_4':
        return {
          'konteksBudaya': 'Batik Madura asli — siswa bebas berkreasi dengan identitas budaya Madura.',
          'materiMatematika': 'Gabungan semua konsep: pola, simetri, bangun datar, transformasi.',
        };
      case 'anyaman_1':
        return {
          'konteksBudaya': 'Anyaman tradisional Madura - Belajar menyusun kombinasi warna dasar.',
          'materiMatematika': 'Pengenalan pola warna. Warnai grid 8x8 secara bebas menggunakan minimal 2 warna berbeda untuk membentuk motif anyaman.',
        };
      case 'anyaman_2':
        return {
          'konteksBudaya': 'Anyaman Madura - Desain ornamen dengan variasi warna yang lebih kaya.',
          'materiMatematika': 'Kombinasi warna dan eksplorasi spasial. Warnai grid 10x10 secara bebas menggunakan minimal 3 warna berbeda.',
        };
      case 'anyaman_3':
        return {
          'konteksBudaya': 'Anyaman tradisional Madura dengan anyaman multi-warna yang kompleks.',
          'materiMatematika': 'Eksplorasi geometri dan warna. Warnai grid 12x12 secara bebas menggunakan minimal 4 warna berbeda.',
        };
      case 'anyaman_4':
        return {
          'konteksBudaya': 'Anyaman bebas Madura - Tingkat mahir dengan kreativitas tanpa batas.',
          'materiMatematika': 'Desain etnomatematika tingkat lanjut. Warnai grid 14x14 menggunakan multi-warna (lebih dari 3 warna berbeda).',
        };
      case 'keris_1':
        return {
          'konteksBudaya': 'Gagang keris Madura memiliki ukiran khas yang mencerminkan keberanian dan ketangguhan budaya Madura.',
          'materiMatematika': 'Geometri dasar: garis lurus, garis lengkung, dan pola sederhana.',
        };
      case 'keris_2':
        return {
          'konteksBudaya': 'Bilah keris Madura biasanya memiliki luk (kelok) berjumlah ganjil yang melambangkan filosofi kehidupan dan kesempurnaan.',
          'materiMatematika': 'Pola berulang, garis berkelok (luk), dan estetika keseimbangan.',
        };
      case 'keris_3':
        return {
          'konteksBudaya': 'Warangka keris berfungsi sebagai pelindung dan lambang status sosial dengan ukiran geometris yang khas.',
          'materiMatematika': 'Geometri & kombinasi minimal 3 jenis bangun datar berbeda.',
        };
      case 'keris_4':
        return {
          'konteksBudaya': 'Keris Madura lengkap (gagang, bilah, warangka) mencerminkan mahakarya budaya Madura yang bernilai tinggi.',
          'materiMatematika': 'Gabungan semua konsep matematika: pola, geometri, keselarasan proporsi.',
        };
      default:
        return {
          'konteksBudaya': 'Seni budaya Madura dan matematika.',
          'materiMatematika': 'Konsep matematika dasar.',
        };
    }
  }

  void _loadOnboardingData() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('game_settings')
          .collection('onboardings')
          .doc(widget.id)
          .get();

      final instrDoc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('game_settings')
          .collection('instruments')
          .doc(widget.id)
          .get();

      final defaults = _getDefaultValues(widget.id);

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          _konteksBudayaController.text = data['konteksBudaya'] ?? defaults['konteksBudaya'] ?? '';
          _materiMatematikaController.text = data['materiMatematika'] ?? defaults['materiMatematika'] ?? '';
        });
      } else {
        setState(() {
          _konteksBudayaController.text = defaults['konteksBudaya'] ?? '';
          _materiMatematikaController.text = defaults['materiMatematika'] ?? '';
        });
      }

      _criteriaList.clear();
      if (instrDoc.exists && instrDoc.data() != null) {
        final data = instrDoc.data()!;
        if (data['criteria'] != null && data['criteria'] is List) {
          final list = data['criteria'] as List;
          for (var item in list) {
            if (item is Map) {
              _criteriaList.add({
                'name': item['name'] ?? '',
                'weight': item['weight'] ?? 0,
              });
            }
          }
        }
      }

      if (_criteriaList.isEmpty) {
        _criteriaList.addAll([
          {'name': 'Kepatuhan Konsep', 'weight': 40},
          {'name': 'Kreativitas', 'weight': 30},
          {'name': 'Kerapihan', 'weight': 30},
        ]);
      }
    } catch (e) {
      debugPrint('Error loading onboarding config: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _konteksBudayaController.dispose();
    _materiMatematikaController.dispose();
    super.dispose();
  }

  void _showSaveConfirmDialog() {
    if (!_formKey.currentState!.validate()) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Simpan Panduan Onboarding?',
            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          content: const Text(
            'Apakah Anda yakin ingin menyimpan perubahan teks panduan level ini? Siswa di mobile client akan melihat perubahan ini secara real-time.',
            style: TextStyle(color: Color(0xFF475569), fontSize: 13, height: 1.5),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context); // Close dialog
                setState(() => _isLoading = true);

                try {
                  final parts = widget.id.split('_');
                  final String kategori = parts.isNotEmpty ? parts[0] : '';
                  final int level = parts.length > 1 ? int.tryParse(parts[1]) ?? 1 : 1;

                  final data = {
                    'id': widget.id,
                    'kategori': kategori,
                    'level': level,
                    'konteksBudaya': _konteksBudayaController.text.trim(),
                    'materiMatematika': _materiMatematikaController.text.trim(),
                    'updatedAt': FieldValue.serverTimestamp(),
                  };

                  await FirebaseFirestore.instance
                      .collection('app_config')
                      .doc('game_settings')
                      .collection('onboardings')
                      .doc(widget.id)
                      .set(data, SetOptions(merge: true));

                  if (!mounted) return;
                  setState(() => _isLoading = false);
                  await _showSuccessAndNavigate('Panduan onboarding level berhasil disimpan.');
                } catch (e) {
                  debugPrint('Error saving onboarding: $e');
                  if (!mounted) return;
                  setState(() => _isLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Gagal menyimpan panduan: $e'),
                      backgroundColor: AdminColors.error,
                      behavior: SnackBarBehavior.floating,
                      width: 420,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // Tampilkan success overlay lalu navigasi kembali ke Panduan Onboarding tab
  Future<void> _showSuccessAndNavigate(String message) async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (ctx) {
        Future.delayed(const Duration(milliseconds: 1800), () {
          if (ctx.mounted) Navigator.of(ctx).pop();
        });
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0xFFDCFCE7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded, color: Color(0xFF16A34A), size: 36),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Berhasil Disimpan!',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Kembali ke Panduan Onboarding...',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    await Future.delayed(const Duration(milliseconds: 1800));
    if (mounted) context.go('/konten?tab=1');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => context.go('/konten?tab=1'),
        ),
        title: Text(
          'Edit Panduan Onboarding: ${widget.id.replaceAll('_', ' ').toUpperCase()}',
          style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AdminColors.primary)))
          : LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 950;
                return isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 4, child: _buildPreviewPanel()),
                          Expanded(flex: 5, child: _buildFormPanel()),
                        ],
                      )
                    : SingleChildScrollView(
                        child: Column(
                          children: [
                            _buildPreviewPanel(),
                            _buildFormPanel(),
                          ],
                        ),
                      );
              },
            ),
    );
  }

  Widget _buildPreviewPanel() {
    final budayaText = _konteksBudayaController.text.trim().isEmpty 
        ? 'Penjelasan konteks budaya Madura akan muncul di sini...' 
        : _konteksBudayaController.text.trim();
    final matematikaText = _materiMatematikaController.text.trim().isEmpty 
        ? 'Penjelasan materi matematika akan muncul di sini...' 
        : _materiMatematikaController.text.trim();

    final parts = widget.id.split('_');
    final level = parts.length > 1 ? parts[1] : '1';

    return Container(
      margin: const EdgeInsets.all(32),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // Midnight Dark Screen
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'LIVE MOBILE DIALOG PREVIEW',
            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5, fontSize: 11, fontFamily: 'monospace'),
          ),
          const SizedBox(height: 24),
          const Divider(color: Color(0xFF1E293B), height: 1),
          const SizedBox(height: 24),
          Center(
            child: Container(
              width: 320,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white, Color(0xFFF8FAFC)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
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
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Petunjuk Level $level',
                          style: const TextStyle(
                            fontFamily: 'FredokaOne',
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Budaya Card
                  _buildPreviewInfoCard(
                    title: 'Konteks Budaya',
                    icon: Icons.account_balance_rounded,
                    content: budayaText,
                    cardColor: const Color(0xFFFFF7ED),
                    iconColor: const Color(0xFFEA580C),
                    textColor: const Color(0xFF7C2D12),
                  ),
                  const SizedBox(height: 10),

                  // Matematika Card
                  _buildPreviewInfoCard(
                    title: 'Materi Matematika',
                    icon: Icons.calculate_rounded,
                    content: matematikaText,
                    cardColor: const Color(0xFFF0FDF4),
                    iconColor: const Color(0xFF16A34A),
                    textColor: const Color(0xFF14532D),
                  ),
                  const SizedBox(height: 10),

                  // Criteria Card
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.15), width: 1),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.stars_rounded, color: Color(0xFF2563EB), size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Kriteria Juri AI',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ..._criteriaList.map((c) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF2563EB), size: 14),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${c['name']} (${c['weight']}%)',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    height: 1.3,
                                    color: Color(0xFF1E3A8A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Button Mock
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF7A00),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Mulai Menggambar',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.02, end: 0, curve: Curves.easeOutQuad);
  }

  Widget _buildPreviewInfoCard({
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
        border: Border.all(color: iconColor.withOpacity(0.15), width: 1),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 16),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: iconColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: TextStyle(
              fontSize: 11,
              height: 1.35,
              color: textColor.withOpacity(0.85),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormPanel() {
    return Container(
      margin: const EdgeInsets.only(top: 32, right: 32, bottom: 32, left: 8),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'FORM ONBOARDING CONFIGURATION',
              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5, fontSize: 11),
            ),
            const SizedBox(height: 24),
            
            // Konteks Budaya input
            const Text('Penjelasan Konteks Budaya', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A), fontSize: 13)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _konteksBudayaController,
              maxLines: 5,
              style: const TextStyle(fontSize: 14),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Konteks Budaya wajib diisi';
                return null;
              },
              decoration: InputDecoration(
                hintText: 'Tuliskan penjelasan konteks budaya (Madura) untuk level ini...',
                contentPadding: const EdgeInsets.all(16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
              ),
            ),
            const SizedBox(height: 24),

            // Materi Matematika input
            const Text('Penjelasan Materi Matematika', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A), fontSize: 13)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _materiMatematikaController,
              maxLines: 5,
              style: const TextStyle(fontSize: 14),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Materi Matematika wajib diisi';
                return null;
              },
              decoration: InputDecoration(
                hintText: 'Tuliskan penjelasan materi matematika untuk level ini...',
                contentPadding: const EdgeInsets.all(16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
              ),
            ),
            const SizedBox(height: 48),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => context.go('/konten?tab=1'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                  child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _showSaveConfirmDialog,
                  icon: const Icon(Icons.save_rounded, size: 16),
                  label: const Text('Simpan Perubahan', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.02, end: 0, curve: Curves.easeOutQuad);
  }
}
