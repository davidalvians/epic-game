import 'package:epic_admin/core/theme/admin_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

class TemplateUploadScreen extends StatefulWidget {
  const TemplateUploadScreen({super.key});

  @override
  State<TemplateUploadScreen> createState() => _TemplateUploadScreenState();
}

class _TemplateUploadScreenState extends State<TemplateUploadScreen> {
  final TextEditingController _nameController = TextEditingController();
  String _selectedCategory = 'keris';
  String _selectedLevel = 'Level 1';
  bool _isActive = true;
  
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedFile;
  Uint8List? _fileBytes;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
      if (file == null) return;
      
      final String name = file.name;
      if (!name.toLowerCase().endsWith('.png')) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.error_outline, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('File harus berformat PNG (Transparan)!'),
              ],
            ),
            backgroundColor: AdminColors.error,
            behavior: SnackBarBehavior.floating,
            width: 380,
          ),
        );
        return;
      }
      
      final bytes = await file.readAsBytes();
      setState(() {
        _selectedFile = file;
        _fileBytes = bytes;
      });
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.file_present_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Gambar PNG terpilih untuk diunggah.'),
            ],
          ),
          backgroundColor: const Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
          width: 380,
        ),
      );
    } catch (e) {
      debugPrint('Error picking file: $e');
    }
  }

  void _showUploadConfirmDialog() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.error_outline, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Nama template tidak boleh kosong!'),
            ],
          ),
          backgroundColor: AdminColors.error,
          behavior: SnackBarBehavior.floating,
          width: 380,
        ),
      );
      return;
    }

    if (_selectedFile == null || _fileBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Harap pilih file gambar PNG terlebih dahulu!'),
            ],
          ),
          backgroundColor: AdminColors.warning,
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
            'Unggah Template Baru?',
            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          content: Text(
            'Apakah Anda yakin ingin mengunggah template "${_nameController.text}" ke sistem?',
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
                setState(() => _isUploading = true);

                try {
                  final String fileName = '${DateTime.now().millisecondsSinceEpoch}_${_selectedFile!.name}';
                  final ref = FirebaseStorage.instance.ref().child('templates/$fileName');
                  
                  final uploadTask = ref.putData(
                    _fileBytes!,
                    SettableMetadata(contentType: 'image/png'),
                  );
                  
                  final snapshot = await uploadTask;
                  final String downloadUrl = await snapshot.ref.getDownloadURL();
                  
                  final docRef = FirebaseFirestore.instance.collection('drawing_templates').doc();
                  final parts = _selectedLevel.split(' ');
                  final int levelInt = parts.length > 1 ? int.tryParse(parts[1]) ?? 1 : 1;
                  
                  await docRef.set({
                    'nama': _nameController.text.trim(),
                    'kategori': _selectedCategory,
                    'level': levelInt,
                    'outlineUrl': downloadUrl,
                    'thumbnailUrl': downloadUrl,
                    'deskripsi': 'Template mewarnai motif ${_selectedCategory[0].toUpperCase() + _selectedCategory.substring(1)} Level $levelInt',
                    'isActive': _isActive,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  
                  if (!mounted) return;
                  setState(() => _isUploading = false);
                  await _showSuccessAndNavigate('Template "${_nameController.text}" berhasil diunggah!');
                } catch (e) {
                  debugPrint('Upload failed: $e');
                  if (!mounted) return;
                  setState(() => _isUploading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Gagal mengunggah template: $e'),
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
              child: const Text('Ya, Unggah', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // Tampilkan success overlay lalu navigasi kembali ke Template Gambar tab
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
                    'Berhasil Diunggah!',
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
                    'Kembali ke Template Gambar...',
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
    if (mounted) context.go('/konten?tab=2');
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
          onPressed: () => context.go('/konten?tab=2'),
        ),
        title: const Text(
          'Tambah / Upload Template Baru',
          style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
        ),
      ),
      body: _isUploading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AdminColors.primary)),
                  SizedBox(height: 16),
                  Text('Mengunggah berkas outline dan menyimpan data ke Firestore...', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                ],
              ),
            )
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
    Gradient categoryGradient;
    if (_selectedCategory.toLowerCase() == 'keris') {
      categoryGradient = const LinearGradient(colors: [Color(0xFFC084FC), Color(0xFF8B5CF6)]);
    } else if (_selectedCategory.toLowerCase() == 'batik') {
      categoryGradient = const LinearGradient(colors: [Color(0xFFFDBA74), Color(0xFFF97316)]);
    } else {
      categoryGradient = const LinearGradient(colors: [Color(0xFF6EE7B7), Color(0xFF059669)]);
    }

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
            'NEW TEMPLATE PREVIEW',
            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5, fontSize: 11),
          ),
          const SizedBox(height: 24),
          Center(
            child: Container(
              width: 250,
              height: 360,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          color: const Color(0xFFF8FAFC),
                          width: double.infinity,
                          child: Center(
                            child: _fileBytes != null
                                ? Image.memory(
                                    _fileBytes!,
                                    fit: BoxFit.contain,
                                  )
                                : const Icon(Icons.image_outlined, size: 52, color: Color(0xFF94A3B8)),
                          ),
                        ),
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: categoryGradient,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _selectedCategory[0].toUpperCase() + _selectedCategory.substring(1),
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _nameController.text.isEmpty ? 'Template Baru' : _nameController.text,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Level: $_selectedLevel',
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _isActive ? const Color(0xFFD1FAE5) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _isActive ? 'Aktif' : 'Nonaktif',
                                style: TextStyle(
                                  color: _isActive ? const Color(0xFF065F46) : const Color(0xFF64748B),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF2563EB)),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'FORM UPLOAD CONFIGURATION',
            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5, fontSize: 11),
          ),
          const SizedBox(height: 24),
          
          // Name Field
          const Text('Nama Template', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A), fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Contoh: Batik L2B',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
            ),
          ),
          const SizedBox(height: 24),

          // Dropdowns Category/Level
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Kategori', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A), fontSize: 13)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCategory,
                          isExpanded: true,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 13),
                          items: const [
                            DropdownMenuItem(value: 'keris', child: Text('Keris')),
                            DropdownMenuItem(value: 'batik', child: Text('Batik')),
                            DropdownMenuItem(value: 'anyaman', child: Text('Anyaman')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedCategory = val);
                          },
                        ),
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
                    const Text('Level Misi', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A), fontSize: 13)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedLevel,
                          isExpanded: true,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 13),
                          items: const [
                            DropdownMenuItem(value: 'Level 1', child: Text('Level 1')),
                            DropdownMenuItem(value: 'Level 2', child: Text('Level 2')),
                            DropdownMenuItem(value: 'Level 3', child: Text('Level 3')),
                            DropdownMenuItem(value: 'Level 4', child: Text('Level 4')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedLevel = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Active toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Langsung Aktifkan', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A), fontSize: 13)),
                  SizedBox(height: 4),
                  Text('Jika aktif, template langsung tersedia untuk dimainkan murid', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                ],
              ),
              Switch(
                value: _isActive,
                onChanged: (val) => setState(() => _isActive = val),
                activeColor: const Color(0xFF2563EB),
              ),
            ],
          ),
          const SizedBox(height: 32),

          const Text(
            'FILE GAMBAR TEMPLATE',
            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5, fontSize: 11),
          ),
          const SizedBox(height: 16),
          
          // Dropzone
          InkWell(
            onTap: _pickFile,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _selectedFile != null ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _selectedFile != null ? Icons.file_present_rounded : Icons.cloud_upload_outlined,
                    size: 44,
                    color: _selectedFile != null ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _selectedFile != null ? _selectedFile!.name : 'Klik untuk memilih file gambar outline',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _selectedFile != null ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Wajib berformat PNG Transparan. Maks. 5 MB.',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 48),

          // Action Row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => context.go('/konten?tab=2'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
                child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _showUploadConfirmDialog,
                icon: const Icon(Icons.cloud_upload_rounded, size: 16),
                label: const Text('Unggah Template', style: TextStyle(fontWeight: FontWeight.bold)),
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
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.02, end: 0, curve: Curves.easeOutQuad);
  }
}
