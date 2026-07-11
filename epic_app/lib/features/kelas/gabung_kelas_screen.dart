import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:epic_app/core/constants/app_colors.dart';
import 'package:epic_app/core/constants/app_fonts.dart';
import 'package:epic_app/features/kelas/kelas_controller.dart';
import 'package:epic_app/features/kelas/scan_qr_kelas_screen.dart';

class GabungKelasScreen extends StatelessWidget {
  final bool fromKelasScreen;
  const GabungKelasScreen({super.key, this.fromKelasScreen = false});

  @override
  Widget build(BuildContext context) {
    // Gunakan Get.put agar controller dibuat jika belum terdaftar (misal dari Home)
    final ctrl = Get.put(KelasController());
    ctrl.isFromKelasScreen = fromKelasScreen;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF9F0), // Latar belakang krem premium hangat
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Gabung Kelas',
          style: AppFonts.heading3(color: AppColors.textPrimary),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Text(
                'Minta kode atau QR dari gurumu untuk bergabung!',
                textAlign: TextAlign.center,
                style: AppFonts.bodySmall(color: AppColors.textSecondary, weight: FontWeight.w600),
              ),
              const SizedBox(height: 32),

              // ── SCAN QR KELAS ──
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)], // Sleek blue gradient
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.25),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      final scannedCode = await Get.to(() => const ScanQRKelasScreen());
                      if (scannedCode != null && scannedCode is String && scannedCode.isNotEmpty) {
                        String codeOnly = scannedCode;
                        if (codeOnly.startsWith('EPIC-')) {
                          codeOnly = codeOnly.substring(5);
                        }
                        ctrl.kodeKelasController.text = codeOnly;
                        if (context.mounted) {
                          ctrl.joinKelas(context);
                        }
                      }
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Pindai QR Kode Kelas',
                                  style: TextStyle(
                                    fontFamily: 'FredokaOne',
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Arahkan kamera ke QR Code kelas milik guru',
                                  style: TextStyle(
                                    fontFamily: 'Nunito',
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Divider "atau"
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'atau masukkan kode',
                      style: AppFonts.caption(color: Colors.grey.shade500).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
                ],
              ),

              const SizedBox(height: 24),

              // ── INPUT KODE KELAS ──
              const Text(
                'Ketik kode kelas:',
                style: TextStyle(
                  fontFamily: 'FredokaOne',
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.horizontal(left: Radius.circular(15)),
                      ),
                      child: const Text(
                        'EPIC-',
                        style: TextStyle(
                          fontFamily: 'FredokaOne',
                          fontSize: 18,
                          color: Color(0xFFEA580C),
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: ctrl.kodeKelasController,
                        style: const TextStyle(
                          fontFamily: 'FredokaOne',
                          fontSize: 18,
                          color: Color(0xFFEA580C),
                          letterSpacing: 3,
                        ),
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 4,
                        buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                        decoration: InputDecoration(
                          hintText: 'XXXX',
                          hintStyle: AppFonts.bodySmall(color: Colors.grey.shade400).copyWith(letterSpacing: 2),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // ── BUTTON GABUNG KELAS ──
              Obx(() {
                final isJoining = ctrl.isJoining.value;
                return SizedBox(
                  height: 56,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, Color(0xFFFF6B35)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: isJoining ? null : () => ctrl.joinKelas(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: isJoining
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle_rounded, color: Colors.white),
                      label: Text(
                        isJoining ? 'Memproses...' : 'Gabung Kelas',
                        style: const TextStyle(
                          fontFamily: 'FredokaOne',
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
