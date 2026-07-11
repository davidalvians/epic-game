import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Overlay transisi layar penuh yang mewah dan interaktif saat mengumpulkan karya.
class EpicTransitionOverlay extends StatefulWidget {
  final String kategori;
  final VoidCallback onComplete;

  const EpicTransitionOverlay({
    super.key,
    required this.kategori,
    required this.onComplete,
  });

  /// Menampilkan overlay transisi secara statis menggunakan Navigator/Overlay
  static void show({
    required BuildContext context,
    required String kategori,
    required VoidCallback onComplete,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (context, anim1, anim2) {
        return EpicTransitionOverlay(
          kategori: kategori,
          onComplete: () {
            Navigator.of(context).pop();
            onComplete();
          },
        );
      },
    );
  }

  @override
  State<EpicTransitionOverlay> createState() => _EpicTransitionOverlayState();
}

class _EpicTransitionOverlayState extends State<EpicTransitionOverlay>
    with TickerProviderStateMixin {
  
  // Animation controllers
  late AnimationController _rotationCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _scaleCtrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _pulseAnim;

  // Text cycle
  Timer? _textTimer;
  int _textIndex = 0;
  late final List<String> _loadingTexts;

  @override
  void initState() {
    super.initState();

    // Teks estetik disesuaikan kategori
    if (widget.kategori.toLowerCase() == 'anyaman') {
      _loadingTexts = [
        'Merapikan sela Anyaman...',
        'Menyusun pola anyaman Madura...',
        'Menghitung geometri kelipatan grid...',
        'Mengirimkan ke Juri AI...',
        'Mempersiapkan lembar apresiasi...',
      ];
    } else if (widget.kategori.toLowerCase() == 'batik') {
      _loadingTexts = [
        'Menyalin goresan Batik...',
        'Mengecek simetri cermin warna...',
        'Meniup lilin malam Madura...',
        'Menyerahkan ke Juri AI...',
        'Mempersiapkan kanvas emas...',
      ];
    } else {
      _loadingTexts = [
        'Menghaluskan bilah Keris...',
        'Menganalisis lekukan geometris...',
        'Mencocokkan proporsi gagang keris...',
        'Menyambung ke Juri AI...',
        'Mempersiapkan ulasan eksklusif...',
      ];
    }

    // Setup animations
    _rotationCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scaleAnim = CurvedAnimation(
      parent: _scaleCtrl,
      curve: Curves.easeOutBack,
    );

    // Mulai animasi masuk
    _scaleCtrl.forward();

    // Jalankan timer pergantian teks
    _textTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (mounted) {
        setState(() {
          _textIndex = (_textIndex + 1) % _loadingTexts.length;
        });
        
        // Selesaikan setelah 3 detik total loading agar pas
        if (timer.tick >= 4) {
          timer.cancel();
          _fadeOutAndComplete();
        }
      }
    });
  }

  void _fadeOutAndComplete() async {
    await _scaleCtrl.reverse();
    if (mounted) {
      widget.onComplete();
    }
  }

  @override
  void dispose() {
    _rotationCtrl.dispose();
    _pulseCtrl.dispose();
    _scaleCtrl.dispose();
    _textTimer?.cancel();
    super.dispose();
  }

  Color get _kategoriColor {
    switch (widget.kategori.toLowerCase()) {
      case 'batik': return const Color(0xFF8B5CF6);
      case 'anyaman': return const Color(0xFF10B981);
      default: return const Color(0xFFEA580C);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = _kategoriColor;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Frosted Glass Blur Background
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                color: const Color(0xFF0F172A).withValues(alpha: 0.82),
              ),
            ),
          ),

          // Central Visual Artwork Showcase
          Center(
            child: FadeTransition(
              opacity: _scaleAnim,
              child: ScaleTransition(
                scale: _scaleAnim,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Glowing Rotating Ecocultural Mandala
                    ScaleTransition(
                      scale: _pulseAnim,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Neon outer glow aura
                          Container(
                            width: 170,
                            height: 170,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: themeColor.withValues(alpha: 0.35),
                                  blurRadius: 40,
                                  spreadRadius: 8,
                                ),
                              ],
                            ),
                          ),

                          // Rotating outer ornamental dashed circle
                          RotationTransition(
                            turns: _rotationCtrl,
                            child: CustomPaint(
                              size: const Size(160, 160),
                              painter: _MandalaDashedPainter(color: themeColor.withValues(alpha: 0.4)),
                            ),
                          ),

                          // Reverse rotating inner batik ornament
                          RotationTransition(
                            turns: ReverseAnimation(_rotationCtrl),
                            child: CustomPaint(
                              size: const Size(120, 120),
                              painter: _MandalaBatikPainter(color: themeColor),
                            ),
                          ),

                          // Glowing Inner Core with Category Icon
                          Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              shape: BoxShape.circle,
                              border: Border.all(color: themeColor, width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                  color: themeColor.withValues(alpha: 0.5),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                widget.kategori.toLowerCase() == 'anyaman'
                                    ? Icons.grid_on_rounded
                                    : widget.kategori.toLowerCase() == 'batik'
                                        ? Icons.palette_rounded
                                        : Icons.brush_rounded,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Title
                    Text(
                      'PENGEMASAN KARYA',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.5,
                        color: themeColor,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Rotating dynamic playful text with smooth AnimatedSwitcher
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: Text(
                          _loadingTexts[_textIndex],
                          key: ValueKey<int>(_textIndex),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white.withValues(alpha: 0.95),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),
                    
                    // High-quality micro-dot loading indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(3, (idx) {
                        return _buildLoadingDot(idx);
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingDot(int idx) {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, child) {
        double animVal = math.sin((_pulseCtrl.value * math.pi * 2) - (idx * math.pi / 3));
        double size = 6.0 + (animVal.clamp(-1.0, 1.0) + 1.0) * 2.0;
        double opacity = 0.3 + (animVal.clamp(-1.0, 1.0) + 1.0) * 0.35;
        
        return Container(
          width: size,
          height: size,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: _kategoriColor.withValues(alpha: opacity),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}

/// Custom painter to draw rotating dashed ecocultural borders
class _MandalaDashedPainter extends CustomPainter {
  final Color color;
  _MandalaDashedPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    const int dashCount = 24;
    const double dashAngle = (2 * math.pi) / dashCount;
    
    for (int i = 0; i < dashCount; i++) {
      double angle = i * dashAngle;
      if (i % 2 == 0) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          angle,
          dashAngle,
          false,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom painter to draw mystical, elegant Madura Batik mandala shapes
class _MandalaBatikPainter extends CustomPainter {
  final Color color;
  _MandalaBatikPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw 8 stylized Madurese batik leaf petals
    for (int i = 0; i < 8; i++) {
      double angle = i * (math.pi / 4);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);
      
      final path = Path();
      path.moveTo(0, 0);
      path.quadraticBezierTo(radius * 0.4, -radius * 0.3, radius * 0.8, 0);
      path.quadraticBezierTo(radius * 0.4, radius * 0.3, 0, 0);
      
      canvas.drawPath(path, paint);
      canvas.drawPath(path, strokePaint);
      
      // Decorative inner dot
      canvas.drawCircle(Offset(radius * 0.4, 0), 3.0, Paint()..color = color);
      
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
