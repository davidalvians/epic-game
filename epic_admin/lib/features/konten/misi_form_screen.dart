import 'package:epic_admin/core/theme/admin_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MisiFormScreen extends StatefulWidget {
  final String? id;
  const MisiFormScreen({super.key, this.id});

  @override
  State<MisiFormScreen> createState() => _MisiFormScreenState();
}

class _MisiFormScreenState extends State<MisiFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _targetController;
  late TextEditingController _rewardController;
  late String _selectedType;
  late bool _isActive;
  bool _isLoading = false;

  bool get isEditMode => widget.id != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _titleController.addListener(() => setState(() {}));
    _targetController = TextEditingController();
    _targetController.addListener(() => setState(() {}));
    _rewardController = TextEditingController();
    _rewardController.addListener(() => setState(() {}));
    _selectedType = 'play_game';
    _isActive = true;

    if (isEditMode) {
      _loadMissionData();
    }
  }

  void _loadMissionData() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('misi_templates')
          .doc(widget.id)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          _titleController.text = data['judul'] ?? '';
          _targetController.text = '${data['target'] ?? 1}';
          _rewardController.text = '${data['poinReward'] ?? 0}';
          _selectedType = data['tipe'] ?? 'play_game';
          _isActive = data['isActive'] ?? true;
        });
      }
    } catch (e) {
      debugPrint('Error loading mission: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _targetController.dispose();
    _rewardController.dispose();
    super.dispose();
  }

  void _showDeleteConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Hapus Misi Harian?',
            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          content: Text(
            'Apakah Anda yakin ingin menghapus misi "${_titleController.text}"? Tindakan ini bersifat destruktif dan tidak dapat dibatalkan.',
            style: const TextStyle(color: Color(0xFF475569), fontSize: 13, height: 1.5),
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
                  await FirebaseFirestore.instance
                      .collection('misi_templates')
                      .doc(widget.id!)
                      .delete();

                  if (!mounted) return;
                  setState(() => _isLoading = false);
                  // Navigasi langsung kembali ke tab Misi Harian setelah hapus
                  context.go('/konten?tab=3');
                } catch (e) {
                  debugPrint('Error deleting mission: $e');
                  if (!mounted) return;
                  setState(() => _isLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Gagal menghapus misi: $e'),
                      backgroundColor: AdminColors.error,
                      behavior: SnackBarBehavior.floating,
                      width: 420,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: const Text('Ya, Hapus', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // Tampilkan success overlay lalu navigasi kembali
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
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
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
                    'Kembali ke Misi Harian...',
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
    if (mounted) context.go('/konten?tab=3');
  }

  void _showSaveConfirmDialog() {
    if (!_formKey.currentState!.validate()) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            isEditMode ? 'Simpan Perubahan Misi?' : 'Tambah Misi Baru?',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          content: Text(
            isEditMode 
                ? 'Apakah Anda yakin ingin menyimpan perubahan pada misi harian ini?'
                : 'Apakah Anda yakin ingin menambahkan misi harian baru ini?',
            style: const TextStyle(color: Color(0xFF475569), fontSize: 13, height: 1.5),
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
                  final String title = _titleController.text.trim();
                  final int target = int.tryParse(_targetController.text.trim()) ?? 1;
                  final int reward = int.tryParse(_rewardController.text.trim()) ?? 0;

                  final data = {
                    'judul': title,
                    'target': target,
                    'poinReward': reward,
                    'tipe': _selectedType,
                    'isActive': _isActive,
                  };

                  if (isEditMode) {
                    await FirebaseFirestore.instance
                        .collection('misi_templates')
                        .doc(widget.id!)
                        .update(data);
                  } else {
                    await FirebaseFirestore.instance
                        .collection('misi_templates')
                        .add(data);
                  }

                  if (!mounted) return;
                  setState(() => _isLoading = false);
                  await _showSuccessAndNavigate(
                    isEditMode
                        ? 'Misi "$title" berhasil diperbarui.'
                        : 'Misi baru "$title" berhasil ditambahkan!',
                  );
                } catch (e) {
                  debugPrint('Error saving mission: $e');
                  if (!mounted) return;
                  setState(() => _isLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Gagal menyimpan misi: $e'),
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
              child: Text(isEditMode ? 'Simpan' : 'Tambah', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
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
          onPressed: () => context.go('/konten?tab=3'),
        ),
        title: Text(
          isEditMode ? 'Edit Misi Harian' : 'Tambah Misi Harian Baru',
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
    final title = _titleController.text.trim().isEmpty ? 'Judul Misi Harian' : _titleController.text.trim();
    final target = _targetController.text.trim().isEmpty ? '0' : _targetController.text.trim();
    final reward = _rewardController.text.trim().isEmpty ? '0' : _rewardController.text.trim();

    return Container(
      margin: const EdgeInsets.all(32),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'LIVE MISSION CARD PREVIEW',
            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5, fontSize: 11),
          ),
          const SizedBox(height: 24),
          Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.emoji_events_rounded, color: Color(0xFF2563EB), size: 28),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A)),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildMiniTag(Icons.radar_rounded, 'Target: $target Kali'),
                            _buildMiniTag(Icons.monetization_on_rounded, '+$reward Poin', textColor: const Color(0xFFB45309), bgColor: const Color(0xFFFEF3C7)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _isActive ? const Color(0xFFD1FAE5) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _isActive ? 'Aktif' : 'Nonaktif',
                                style: TextStyle(
                                  color: _isActive ? const Color(0xFF065F46) : const Color(0xFF64748B),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
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

  Widget _buildMiniTag(IconData icon, String text, {Color? textColor, Color? bgColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor ?? const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: textColor ?? const Color(0xFF64748B)),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: textColor ?? const Color(0xFF475569),
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
              'FORM MISSION CONFIGURATION',
              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5, fontSize: 11),
            ),
            const SizedBox(height: 24),
            
            // Title input
            const Text('Judul Misi Harian', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A), fontSize: 13)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _titleController,
              style: const TextStyle(fontSize: 14),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Judul misi wajib diisi';
                return null;
              },
              decoration: InputDecoration(
                hintText: 'Contoh: Mainkan 2 game hari ini',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
              ),
            ),
            const SizedBox(height: 24),

            // Target and Reward inputs
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Target Kuantitas', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A), fontSize: 13)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _targetController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 14),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Wajib diisi';
                          if (int.tryParse(val) == null) return 'Harus angka';
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: 'Contoh: 2',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Reward (Poin)', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A), fontSize: 13)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _rewardController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 14),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Wajib diisi';
                          if (int.tryParse(val) == null) return 'Harus angka';
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: 'Contoh: 20',
                          suffixText: 'Poin',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Type Dropdown
            const Text('Tipe Misi Harian', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A), fontSize: 13)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFCBD5E1)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedType,
                  isExpanded: true,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 13),
                  items: const [
                    DropdownMenuItem(value: 'play_game', child: Text('play_game (Bermain Game)')),
                    DropdownMenuItem(value: 'submit_artwork', child: Text('submit_artwork (Kirim Gambar Karya)')),
                    DropdownMenuItem(value: 'achieve_grade_s', child: Text('achieve_grade_s (Dapat Nilai Grade S)')),
                    DropdownMenuItem(value: 'login_streak', child: Text('login_streak (Presensi Berurutan)')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedType = val;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Active toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Status Aktif Misi', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A), fontSize: 13)),
                    SizedBox(height: 4),
                    Text('Aktifkan agar misi harian bisa ditarik secara acak oleh murid', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                  ],
                ),
                Switch(
                  value: _isActive,
                  onChanged: (val) => setState(() => _isActive = val),
                  activeColor: const Color(0xFF2563EB),
                ),
              ],
            ),
            const SizedBox(height: 48),

            // Action Row Buttons
            Row(
              mainAxisAlignment: isEditMode ? MainAxisAlignment.spaceBetween : MainAxisAlignment.end,
              children: [
                if (isEditMode)
                  OutlinedButton.icon(
                    onPressed: _showDeleteConfirmDialog,
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: const Text('Hapus Misi', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AdminColors.error,
                      side: const BorderSide(color: Color(0xFFFECACA)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => context.go('/konten?tab=3'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                      child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _showSaveConfirmDialog,
                      icon: Icon(isEditMode ? Icons.save_rounded : Icons.add_rounded, size: 16),
                      label: Text(isEditMode ? 'Simpan Perubahan' : 'Tambah Misi', style: const TextStyle(fontWeight: FontWeight.bold)),
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
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.02, end: 0, curve: Curves.easeOutQuad);
  }
}
