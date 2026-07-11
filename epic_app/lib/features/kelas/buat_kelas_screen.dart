import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:epic_app/core/constants/app_colors.dart';
import 'package:epic_app/core/constants/app_fonts.dart';
import 'package:epic_app/features/kelas/kelas_controller.dart';
import 'package:epic_app/shared/controllers/session_controller.dart';
import 'package:epic_app/features/kelas/kelas_success_screen.dart';

class BuatKelasScreen extends StatefulWidget {
  const BuatKelasScreen({super.key});

  @override
  State<BuatKelasScreen> createState() => _BuatKelasScreenState();
}

class _BuatKelasScreenState extends State<BuatKelasScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _schoolCtrl = TextEditingController();
  final _academicYearCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();

  String _selectedTingkat = '4 SD';
  final List<String> _tingkatOptions = [
    '1 SD',
    '2 SD',
    '3 SD',
    '4 SD',
    '5 SD',
    '6 SD',
  ];

  @override
  void initState() {
    super.initState();
    final session = Get.find<SessionController>();
    _schoolCtrl.text = session.user?.sekolah ?? '';
    
    final currentYear = DateTime.now().year;
    _academicYearCtrl.text = '$currentYear/${currentYear + 1}';
    _subjectCtrl.text = 'Seni Budaya';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _schoolCtrl.dispose();
    _academicYearCtrl.dispose();
    _subjectCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<KelasController>();

    return Scaffold(
      backgroundColor: const Color(0xFFFFF9F0),
      appBar: AppBar(
        title: Text(
          'Buat Kelas Baru',
          style: AppFonts.heading2(color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Get.back(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          physics: const BouncingScrollPhysics(),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ilustrasi dekoratif kecil
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_home_work_rounded,
                      size: 48,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Form Field: Nama Kelas
                _buildLabel('Nama Kelas *'),
                TextFormField(
                  controller: _nameCtrl,
                  style: AppFonts.bodyText(weight: FontWeight.w700),
                  textCapitalization: TextCapitalization.words,
                  decoration: _buildInputDecoration(
                    hintText: 'Contoh: Kelas 4A',
                    prefixIcon: Icons.class_rounded,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nama kelas tidak boleh kosong';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Form Field: Tingkat Kelas
                _buildLabel('Tingkat Kelas *'),
                DropdownButtonFormField<String>(
                  initialValue: _selectedTingkat,
                  style: AppFonts.bodyText(weight: FontWeight.w700, color: AppColors.textPrimary),
                  decoration: _buildInputDecoration(
                    prefixIcon: Icons.grade_rounded,
                  ),
                  items: _tingkatOptions
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(t),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedTingkat = value);
                    }
                  },
                ),
                const SizedBox(height: 20),

                // Form Field: Nama Sekolah
                _buildLabel('Nama Sekolah'),
                TextFormField(
                  controller: _schoolCtrl,
                  enabled: false,
                  style: AppFonts.bodyText(weight: FontWeight.w600, color: AppColors.textSecondary),
                  decoration: _buildInputDecoration(
                    prefixIcon: Icons.school_rounded,
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9), // Slate 100
                  ),
                ),
                const SizedBox(height: 20),

                // Form Field: Tahun Ajaran
                _buildLabel('Tahun Ajaran'),
                TextFormField(
                  controller: _academicYearCtrl,
                  style: AppFonts.bodyText(weight: FontWeight.w700),
                  decoration: _buildInputDecoration(
                    hintText: 'Contoh: 2025/2026',
                    prefixIcon: Icons.calendar_month_rounded,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Tahun ajaran tidak boleh kosong';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Form Field: Mata Pelajaran
                _buildLabel('Mata Pelajaran'),
                TextFormField(
                  controller: _subjectCtrl,
                  style: AppFonts.bodyText(weight: FontWeight.w700),
                  decoration: _buildInputDecoration(
                    hintText: 'Contoh: Seni Budaya',
                    prefixIcon: Icons.palette_rounded,
                  ),
                ),
                const SizedBox(height: 36),

                // Tombol Buat Kelas
                Obx(() {
                  final isLoading = controller.isLoading.value;
                  return SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, Color(0xFFFF6B35)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          )
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: isLoading
                            ? const Center(child: CircularProgressIndicator(color: Colors.white))
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle_outline_rounded, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text(
                                    'Buat Kelas Sekarang',
                                    style: TextStyle(
                                      fontFamily: 'FredokaOne',
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'FredokaOne',
          fontSize: 14,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    String? hintText,
    IconData? prefixIcon,
    bool filled = false,
    Color? fillColor,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: AppFonts.bodySmall(color: const Color(0xFF94A3B8)),
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: AppColors.primary, size: 20) : null,
      filled: filled,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
    );
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final controller = Get.find<KelasController>();
      final kelasBaru = await controller.createKelas(
        nama: _nameCtrl.text.trim(),
        tingkat: _selectedTingkat,
        mataPelajaran: _subjectCtrl.text.trim(),
        tahunAjaran: _academicYearCtrl.text.trim(),
      );

      if (kelasBaru != null) {
        // Navigasi ke Layar Sukses secara off (hapus form dari tumpukan back)
        Get.off(() => KelasSuccessScreen(kelas: kelasBaru));
      }
    }
  }
}
