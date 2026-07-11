import 'package:epic_admin/core/theme/admin_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'dart:convert';

class InstrumentFormScreen extends StatefulWidget {
  final String id;
  const InstrumentFormScreen({super.key, required this.id});

  @override
  State<InstrumentFormScreen> createState() => _InstrumentFormScreenState();
}

class _InstrumentFormScreenState extends State<InstrumentFormScreen> {
  String _selectedModel = 'gemini-2.5-flash-lite';
  late TextEditingController _promptController;
  bool _isLoading = true;
  
  final List<Map<String, dynamic>> _criteriaList = [];
  final List<TextEditingController> _nameControllers = [];
  final List<TextEditingController> _weightControllers = [];

  bool _showSandbox = false;
  XFile? _sandboxFile;
  Uint8List? _sandboxBytes;
  bool _isTestingSandbox = false;
  Map<String, dynamic>? _sandboxResult;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _promptController = TextEditingController();
    _loadInstrumentData();
  }

  void _syncControllers() {
    for (var c in _nameControllers) {
      c.dispose();
    }
    for (var c in _weightControllers) {
      c.dispose();
    }
    _nameControllers.clear();
    _weightControllers.clear();

    for (var c in _criteriaList) {
      final nameCtrl = TextEditingController(text: c['name']);
      // Mengonversi bobot/weight ke int murni agar tidak memiliki desimal desimal (misal: 40.0 -> 40)
      final int weightVal = c['weight'] is num ? (c['weight'] as num).toInt() : (double.tryParse(c['weight']?.toString() ?? '0') ?? 0).round();
      final weightCtrl = TextEditingController(text: '$weightVal');
      
      nameCtrl.addListener(() {
        final index = _nameControllers.indexOf(nameCtrl);
        if (index != -1) {
          _criteriaList[index]['name'] = nameCtrl.text;
          setState(() {});
        }
      });

      weightCtrl.addListener(() {
        final index = _weightControllers.indexOf(weightCtrl);
        if (index != -1) {
          _criteriaList[index]['weight'] = (double.tryParse(weightCtrl.text) ?? 0).round();
          setState(() {});
        }
      });

      _nameControllers.add(nameCtrl);
      _weightControllers.add(weightCtrl);
    }
  }

  Future<void> _loadInstrumentData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('game_settings')
          .collection('instruments')
          .doc(widget.id)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          _selectedModel = data['modelAI'] ?? 'gemini-2.5-flash-lite';
          _promptController.text = data['systemInstruction'] ?? '';
          _criteriaList.clear();
          
          if (data['criteria'] != null && data['criteria'] is List) {
            final list = data['criteria'] as List;
            for (var item in list) {
              if (item is Map) {
                _criteriaList.add({
                  'name': item['name'] ?? '',
                  'weight': item['weight'] is num ? (item['weight'] as num).toInt() : (double.tryParse(item['weight']?.toString() ?? '0') ?? 0).round(),
                });
              }
            }
          }
          
          if (_criteriaList.isEmpty) {
            if (data['kriteria1'] != null && data['kriteria1'].toString().isNotEmpty) {
              _criteriaList.add({'name': data['kriteria1'], 'weight': data['bobot1'] is num ? (data['bobot1'] as num).toInt() : 40});
            }
            if (data['kriteria2'] != null && data['kriteria2'].toString().isNotEmpty) {
              _criteriaList.add({'name': data['kriteria2'], 'weight': data['bobot2'] is num ? (data['bobot2'] as num).toInt() : 30});
            }
            if (data['kriteria3'] != null && data['kriteria3'].toString().isNotEmpty) {
              _criteriaList.add({'name': data['kriteria3'], 'weight': data['bobot3'] is num ? (data['bobot3'] as num).toInt() : 30});
            }
          }
          
          // If no criteria, fill defaults
          if (_criteriaList.isEmpty) {
            _criteriaList.addAll([
              {'name': 'Pola & Motif', 'weight': 40},
              {'name': 'Simetri', 'weight': 30},
              {'name': 'Kreativitas Warna', 'weight': 30},
            ]);
          }
          _syncControllers();
          _isLoading = false;
        });
      } else {
        final parts = widget.id.split('_');
        final categoryName = parts.isNotEmpty ? parts[0] : 'Karya';
        setState(() {
          _promptController.text = 'Anda adalah juri ahli $categoryName tradisional Indonesia. Tugas Anda adalah menilai karya mewarnai anak SD berdasarkan pola, simetri, dan kreativitas perpaduan warna.';
          _criteriaList.addAll([
            {'name': 'Pola & Motif', 'weight': 40},
            {'name': 'Simetri', 'weight': 30},
            {'name': 'Kreativitas Warna', 'weight': 30},
          ]);
          _syncControllers();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading instrument: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    for (var c in _nameControllers) {
      c.dispose();
    }
    for (var c in _weightControllers) {
      c.dispose();
    }
    super.dispose();
  }

  int get _totalWeight {
    return _criteriaList.fold(0, (sum, item) => sum + (item['weight'] as int));
  }

  bool get _isValid => _totalWeight == 100;

  void _addCriteria() {
    setState(() {
      _criteriaList.add({'name': 'Kriteria Baru', 'weight': 10});
      final nameCtrl = TextEditingController(text: 'Kriteria Baru');
      final weightCtrl = TextEditingController(text: '10');
      
      nameCtrl.addListener(() {
        final index = _nameControllers.indexOf(nameCtrl);
        if (index != -1) {
          _criteriaList[index]['name'] = nameCtrl.text;
          setState(() {});
        }
      });

      weightCtrl.addListener(() {
        final index = _weightControllers.indexOf(weightCtrl);
        if (index != -1) {
          _criteriaList[index]['weight'] = (double.tryParse(weightCtrl.text) ?? 0).round();
          setState(() {});
        }
      });

      _nameControllers.add(nameCtrl);
      _weightControllers.add(weightCtrl);
    });
  }

  void _removeCriteria(int index) {
    if (_criteriaList.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Minimal harus memiliki 1 kriteria penilaian!'),
            ],
          ),
          backgroundColor: AdminColors.error,
          behavior: SnackBarBehavior.floating,
          width: 380,
        ),
      );
      return;
    }
    setState(() {
      _criteriaList.removeAt(index);
      _nameControllers[index].dispose();
      _weightControllers[index].dispose();
      _nameControllers.removeAt(index);
      _weightControllers.removeAt(index);
    });
  }

  void _showSaveConfirmDialog() {
    if (!_isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('Total bobot kriteria harus bernilai 100% (Saat ini: $_totalWeight%)!'),
            ],
          ),
          backgroundColor: AdminColors.error,
          behavior: SnackBarBehavior.floating,
          width: 420,
        ),
      );
      return;
    }

    if (_promptController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.warning, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Prompt dasar tidak boleh kosong!'),
            ],
          ),
          backgroundColor: AdminColors.error,
          behavior: SnackBarBehavior.floating,
          width: 380,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Simpan Perubahan Instrumen?',
            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          content: const Text(
            'Apakah Anda yakin ingin memperbarui system instruction dan pembobotan kriteria untuk model AI Gemini ini?',
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
                try {
                  final parts = widget.id.split('_');
                  final String kategori = parts.isNotEmpty ? parts[0] : '';
                  final int level = parts.length > 1 ? int.tryParse(parts[1]) ?? 1 : 1;

                  final data = {
                    'modelAI': _selectedModel,
                    'systemInstruction': _promptController.text.trim(),
                    'kategori': kategori,
                    'level': level,
                    'criteria': _criteriaList,
                    'kriteria1': _criteriaList.isNotEmpty ? _criteriaList[0]['name'] : '',
                    'bobot1': _criteriaList.isNotEmpty ? _criteriaList[0]['weight'] : 0,
                    'kriteria2': _criteriaList.length > 1 ? _criteriaList[1]['name'] : '',
                    'bobot2': _criteriaList.length > 1 ? _criteriaList[1]['weight'] : 0,
                    'kriteria3': _criteriaList.length > 2 ? _criteriaList[2]['name'] : '',
                    'bobot3': _criteriaList.length > 2 ? _criteriaList[2]['weight'] : 0,
                  };

                  await FirebaseFirestore.instance
                      .collection('app_config')
                      .doc('game_settings')
                      .collection('instruments')
                      .doc(widget.id)
                      .set(data, SetOptions(merge: true));

                  if (!mounted) return;
                  Navigator.pop(context); // Close dialog
                  await _showSuccessAndNavigate('Konfigurasi instrumen AI berhasil disimpan.');
                } catch (e) {
                  debugPrint('Error saving instrument: $e');
                  if (mounted) Navigator.pop(context);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Gagal menyimpan instrumen: $e'),
                        backgroundColor: AdminColors.error,
                        behavior: SnackBarBehavior.floating,
                        width: 420,
                      ),
                    );
                  }
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

  // Tampilkan success overlay lalu navigasi kembali ke Instrumen AI tab
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
                    'Kembali ke Instrumen AI...',
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
    if (mounted) context.go('/konten?tab=0');
  }

  String _generateJsonPreview() {
    final criteriaJson = _criteriaList
        .map((c) => '    {"name": "${c['name']}", "weight": ${c['weight']}}')
        .join(',\n');
    
    return '{\n'
        '  "model": "$_selectedModel",\n'
        '  "system_instruction": "${_promptController.text.replaceAll('\n', ' ')}",\n'
        '  "criteria": [\n'
        '$criteriaJson\n'
        '  ]\n'
        '}';
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
          onPressed: () => context.go('/konten?tab=0'),
        ),
        title: Text(
          'Edit Instrumen AI: ${widget.id.replaceAll('_', ' ')}',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
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
    return Container(
      margin: const EdgeInsets.all(32),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // Midnight Dark Code View
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _buildPanelTabButton('JSON PREVIEW', !_showSandbox),
                  const SizedBox(width: 8),
                  _buildPanelTabButton('TEST SANDBOX', _showSandbox),
                ],
              ),
              const Text(
                'INSTRUMEN AI',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(color: Color(0xFF1E293B), height: 1),
          const SizedBox(height: 24),
          _showSandbox ? _buildSandboxView() : _buildJsonPreviewView(),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.02, end: 0, curve: Curves.easeOutQuad);
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
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          const Text(
            'KONFIGURASI PARAMETER MODEL AI',
            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5, fontSize: 11),
          ),
          const SizedBox(height: 24),
          
          // AI Model dropdown
          const Text('Model AI Utama', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A), fontSize: 13)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFCBD5E1)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedModel,
                isExpanded: true,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 14),
                items: const [
                  DropdownMenuItem(value: 'gemini-2.5-flash-lite', child: Text('gemini-2.5-flash-lite (Rekomendasi)')),
                  DropdownMenuItem(value: 'gemini-2.5-flash', child: Text('gemini-2.5-flash (Standar)')),
                  DropdownMenuItem(value: 'gemini-2.5-pro', child: Text('gemini-2.5-pro (Akurasi Tinggi)')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedModel = val);
                },
              ),
            ),
          ),
          const SizedBox(height: 24),

          // System Instructions
          const Text('Prompt Dasar (System Instruction)', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A), fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _promptController,
            maxLines: 4,
            style: const TextStyle(fontSize: 14),
            onChanged: (val) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Tuliskan instruksi sistem penilaian...',
              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
            ),
          ),
          const SizedBox(height: 32),

          // Criteria & Weights
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Kriteria Penilaian & Pembobotan', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F172A), fontSize: 14)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _isValid ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isValid ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      size: 14,
                      color: _isValid ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Total: $_totalWeight% / 100%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _isValid ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          SizedBox(
            height: 180,
            child: ListView.builder(
              itemCount: _criteriaList.length,
              itemBuilder: (context, index) {
                final criteriaNameCtrl = _nameControllers[index];
                final weightCtrl = _weightControllers[index];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: criteriaNameCtrl,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Bobot:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: weightCtrl,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            isDense: true,
                            suffixText: '%',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _removeCriteria(index),
                        icon: const Icon(Icons.remove_circle_outline_rounded, color: Color(0xFFEF4444)),
                        tooltip: 'Hapus Kriteria',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          
          TextButton.icon(
            onPressed: _addCriteria,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Tambah Kriteria Penilaian', style: TextStyle(fontWeight: FontWeight.bold)),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF2563EB)),
          ),
          const SizedBox(height: 24),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => context.go('/konten?tab=0'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
                child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: _showSaveConfirmDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: const Text('Simpan Perubahan', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.02, end: 0, curve: Curves.easeOutQuad);
  }

  Widget _buildPanelTabButton(String label, bool isSelected) {
    return InkWell(
      onTap: () {
        setState(() {
          _showSandbox = label == 'TEST SANDBOX';
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E293B) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF64748B),
            fontWeight: FontWeight.bold,
            fontSize: 10,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }

  Widget _buildJsonPreviewView() {
    return SizedBox(
      height: 380,
      child: SingleChildScrollView(
        child: SelectableText(
          _generateJsonPreview(),
          style: const TextStyle(
            fontFamily: 'monospace',
            color: Color(0xFF38BDF8),
            fontSize: 13,
            height: 1.6,
          ),
        ),
      ),
    );
  }

  Widget _buildSandboxView() {
    return SizedBox(
      height: 380,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Uji Coba Penilaian AI (Sandbox)',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 6),
            const Text(
              'Unggah gambar sample dan jalankan uji coba untuk memvalidasi performa instruksi serta pembobotan kriteria AI Anda.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
            ),
            const SizedBox(height: 20),
            if (_sandboxFile == null)
              InkWell(
                onTap: _pickSandboxFile,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF334155), width: 1.5, style: BorderStyle.solid),
                  ),
                  child: Column(
                    children: const [
                      Icon(Icons.cloud_upload_outlined, size: 36, color: Color(0xFF38BDF8)),
                      SizedBox(height: 12),
                      Text(
                        'Klik untuk memilih gambar sample',
                        style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Format PNG/JPG. File tidak disimpan ke server.',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 10),
                      ),
                    ],
                  ),
                ),
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.memory(_sandboxBytes!, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _sandboxFile!.name,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ukuran: ${(_sandboxBytes!.length / 1024).toStringAsFixed(1)} KB',
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: _pickSandboxFile,
                              icon: const Icon(Icons.refresh_rounded, size: 12),
                              label: const Text('Ganti', style: TextStyle(fontSize: 11)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF94A3B8),
                                side: const BorderSide(color: Color(0xFF334155)),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _sandboxFile = null;
                                  _sandboxBytes = null;
                                  _sandboxResult = null;
                                });
                              },
                              icon: const Icon(Icons.delete_outline_rounded, size: 12, color: Color(0xFFEF4444)),
                              label: const Text('Hapus', style: TextStyle(fontSize: 11, color: Color(0xFFEF4444))),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 24),
            if (_sandboxFile != null && !_isTestingSandbox && _sandboxResult == null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _runSandboxTest,
                  icon: const Icon(Icons.play_arrow_rounded, size: 16),
                  label: const Text('Jalankan Uji Coba AI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            if (_isTestingSandbox)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: const [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                      ),
                    ),
                    SizedBox(width: 16),
                    Text(
                      'Menilai gambar sample dengan AI Gemini...',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            if (_sandboxResult != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Hasil Uji Coba AI',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _sandboxResult!['grade'] == 'S' || _sandboxResult!['grade'] == 'A'
                                ? const Color(0xFF064E3B)
                                : const Color(0xFF78350F),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Grade ${_sandboxResult!['grade']}',
                            style: TextStyle(
                              color: _sandboxResult!['grade'] == 'S' || _sandboxResult!['grade'] == 'A'
                                  ? const Color(0xFF34D399)
                                  : const Color(0xFFFBBF24),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Color(0xFF334155), height: 1),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.analytics_outlined, color: Color(0xFF38BDF8), size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Skor AI: ${_sandboxResult!['skor']} / 100',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const Spacer(),
                        if (_sandboxResult!['modelUsed'] != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF1E293B)),
                            ),
                            child: Text(
                              '${_sandboxResult!['modelUsed']}',
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontFamily: 'monospace',
                                fontSize: 9,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Umpan Balik AI (Feedback):',
                      style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _sandboxResult!['feedback'] ?? 'Tidak ada feedback.',
                      style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12, height: 1.55),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _sandboxResult = null;
                    });
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 14),
                  label: const Text('Uji Coba Ulang', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF38BDF8),
                    side: const BorderSide(color: Color(0xFF334155)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickSandboxFile() async {
    try {
      final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _sandboxFile = file;
        _sandboxBytes = bytes;
        _sandboxResult = null;
      });
    } catch (e) {
      debugPrint('Error picking sandbox file: $e');
    }
  }

  /// Jalankan uji coba penilaian AI menggunakan Cloud Function testSandboxScoring.
  /// Gambar dikirim sebagai base64, hasilnya adalah skor/grade/feedback NYATA dari Gemini.
  void _runSandboxTest() async {
    if (_sandboxBytes == null || _isTestingSandbox) return;
    setState(() {
      _isTestingSandbox = true;
      _sandboxResult = null;
    });

    try {
      // Encode gambar ke base64
      final imageBase64 = base64Encode(_sandboxBytes!);

      // Panggil Cloud Function testSandboxScoring
      final callable = FirebaseFunctions.instance.httpsCallable('testSandboxScoring');
      final result = await callable.call({
        'imageBase64': imageBase64,
        'instrumentId': widget.id,
        'criteriaList': _criteriaList,
        'systemInstruction': _promptController.text.trim(),
        'modelAI': _selectedModel,
      });

      if (!mounted) return;

      final data = Map<String, dynamic>.from(result.data as Map);
      setState(() {
        _isTestingSandbox = false;
        _sandboxResult = {
          'skor': data['skor'] ?? 0,
          'grade': data['grade'] ?? 'E',
          'feedback': data['feedback'] ?? 'Tidak ada feedback.',
          'modelUsed': data['modelUsed'] ?? _selectedModel,
        };
      });
    } catch (e) {
      debugPrint('Error sandbox test: $e');
      if (!mounted) return;
      setState(() {
        _isTestingSandbox = false;
        _sandboxResult = null;
      });

      String errorMsg = 'Uji coba gagal.';
      if (e.toString().contains('resource-exhausted') || e.toString().contains('QUOTA')) {
        errorMsg = 'Limit penggunaan Gemini API habis. Coba lagi besok atau gunakan model lain.';
      } else if (e.toString().contains('unauthenticated')) {
        errorMsg = 'Sesi admin telah berakhir. Silakan login ulang.';
      } else if (e.toString().contains('API key')) {
        errorMsg = 'Gemini API Key belum dikonfigurasi di Cloud Functions. Hubungi administrator.';
      } else {
        errorMsg = 'Gagal: ${e.toString().replaceAll('[firebase_functions/internal]', '').trim()}';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 10),
              Expanded(child: Text(errorMsg, style: const TextStyle(fontSize: 12))),
            ],
          ),
          backgroundColor: AdminColors.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
          width: 480,
        ),
      );
    }
  }
}
