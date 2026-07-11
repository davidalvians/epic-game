import 'dart:math';
import 'package:flutter/material.dart';

/// Halaman Route khusus yang melakukan efek transisi "Circular Reveal" (bukaan lingkaran)
/// dari titik koordinat tertentu (misalnya dari tengah tombol yang ditekan),
/// diiringi oleh efek slide-up dan fade-in lembut untuk halaman tujuan.
class CircularRevealPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final Offset centerOffset;

  CircularRevealPageRoute({
    required this.page,
    required this.centerOffset,
    super.transitionDuration = const Duration(milliseconds: 600),
    super.reverseTransitionDuration = const Duration(milliseconds: 500),
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // 1. Animasi untuk bukaan lingkaran warna dasar/gradasi oranye
            final circularRevealValue = CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.75, curve: Curves.easeInOutCubic),
            );

            // 2. Animasi memudar lembut untuk konten halaman baru
            final contentFade = Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: const Interval(0.35, 1.0, curve: Curves.easeOut),
              ),
            );

            // 3. Animasi bergerak naik (slide-up) sedikit untuk konten halaman baru
            final contentSlide = Tween<Offset>(
              begin: const Offset(0.0, 0.05),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: const Interval(0.35, 1.0, curve: Curves.easeOutCubic),
              ),
            );

            return Stack(
              children: [
                // Lapisan 1: Gelombang lingkaran oranye gradasi dari posisi tombol
                AnimatedBuilder(
                  animation: circularRevealValue,
                  builder: (context, _) {
                    return ClipPath(
                      clipper: CircularRevealClipper(
                        revealPercent: circularRevealValue.value,
                        center: centerOffset,
                      ),
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFFF9900), Color(0xFFFF5500)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // Lapisan 2: Halaman utama yang memudar & bergeser naik
                FadeTransition(
                  opacity: contentFade,
                  child: SlideTransition(
                    position: contentSlide,
                    child: child,
                  ),
                ),
              ],
            );
          },
        );
}

/// Custom Clipper untuk memotong area berbentuk lingkaran yang meluas secara dinamis
class CircularRevealClipper extends CustomClipper<Path> {
  final double revealPercent;
  final Offset center;

  CircularRevealClipper({
    required this.revealPercent,
    required this.center,
  });

  @override
  Path getClip(Size size) {
    final path = Path();
    if (revealPercent == 0.0) {
      return path;
    }

    // Hitung jarak maksimum dari titik pusat ke sudut layar terjauh
    final double maxRadius = _getMaxRadius(size, center);
    final double radius = maxRadius * revealPercent;

    path.addOval(Rect.fromCircle(center: center, radius: radius));
    return path;
  }

  double _getMaxRadius(Size size, Offset center) {
    final d1 = (center - const Offset(0, 0)).distance;
    final d2 = (center - Offset(size.width, 0)).distance;
    final d3 = (center - Offset(0, size.height)).distance;
    final d4 = (center - Offset(size.width, size.height)).distance;

    return [d1, d2, d3, d4].reduce(max);
  }

  @override
  bool shouldReclip(covariant CircularRevealClipper oldClipper) {
    return oldClipper.revealPercent != revealPercent || oldClipper.center != center;
  }
}
