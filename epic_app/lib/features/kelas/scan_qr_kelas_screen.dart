import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:epic_app/core/constants/app_fonts.dart';

class ScanQRKelasScreen extends StatefulWidget {
  const ScanQRKelasScreen({super.key});

  @override
  State<ScanQRKelasScreen> createState() => _ScanQRKelasScreenState();
}

class _ScanQRKelasScreenState extends State<ScanQRKelasScreen> with SingleTickerProviderStateMixin {
  final MobileScannerController controller = MobileScannerController();
  late AnimationController _animationController;
  bool _hasScanned = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    controller.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _processQRResult(String rawValue) {
    setState(() => _hasScanned = true);
    String? code;

    // Check if it is JSON
    try {
      final Map<String, dynamic> data = jsonDecode(rawValue);
      if (data['type'] == 'epic_kelas') {
        code = data['kode'] ?? data['code'];
      }
    } catch (_) {
      // Not JSON, check if it's standard EPIC-XXXX format
      final cleanVal = rawValue.trim().toUpperCase();
      if (cleanVal.startsWith('EPIC-') && cleanVal.length >= 8) {
        code = cleanVal;
      } else if (cleanVal.length == 4) {
        code = 'EPIC-$cleanVal';
      }
    }

    if (code != null) {
      Get.back(result: code);
    } else {
      // Invalid code scanned
      setState(() => _hasScanned = false);
      Get.snackbar(
        'QR Tidak Valid ❌',
        'Kode QR ini tidak sesuai dengan kelas EPIC.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFEF4444),
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 16,
        duration: const Duration(seconds: 3),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera scanner
          MobileScanner(
            controller: controller,
            onDetect: (BarcodeCapture capture) {
              if (_hasScanned) return;
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                final String rawValue = barcodes.first.rawValue!;
                debugPrint('QR Scanned: $rawValue');
                _processQRResult(rawValue);
              }
            },
          ),

          // Semi-transparent overlay with cutout
          const Positioned.fill(
            child: CustomPaint(
              painter: ScannerOverlay(),
            ),
          ),

          // Animated laser line
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              final size = MediaQuery.of(context).size;
              final cutoutSize = size.width * 0.7;
              final topOffset = (size.height - cutoutSize) / 2;
              final laserPosition = topOffset + (cutoutSize * _animationController.value);

              return Positioned(
                top: laserPosition,
                left: (size.width - cutoutSize) / 2 + 10,
                width: cutoutSize - 20,
                height: 2.5,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF5100),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFFFF5100),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Controls & Back Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
                    onPressed: () => Get.back(),
                  ),
                ),
                Text(
                  'Pindai QR Kelas',
                  style: AppFonts.heading3(color: Colors.white),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: ValueListenableBuilder(
                    valueListenable: controller,
                    builder: (context, state, child) {
                      final bool isTorchOn = state.torchState == TorchState.on;
                      return IconButton(
                        icon: Icon(
                          isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                        onPressed: () => controller.toggleTorch(),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Bottom helper text
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 40,
            left: 32,
            right: 32,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: const Text(
                'Arahkan kamera ke QR Code kelas yang ditunjukkan oleh Gurumu.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xBFFFFFFF),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ScannerOverlay extends CustomPainter {
  const ScannerOverlay();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.5);
    final cutoutSize = size.width * 0.7;
    final left = (size.width - cutoutSize) / 2;
    final top = (size.height - cutoutSize) / 2;

    // Background mask with a rounded cutout hole
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()
          ..addRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(left, top, cutoutSize, cutoutSize),
              const Radius.circular(24),
            ),
          ),
      ),
      paint,
    );

    // Active borders around scanner frame
    final borderPaint = Paint()
      ..color = const Color(0xFFFF5100)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    // Draw active borders
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, cutoutSize, cutoutSize),
      const Radius.circular(24),
    );
    canvas.drawRRect(rrect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
