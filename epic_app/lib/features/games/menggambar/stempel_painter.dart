import 'dart:math' as math;
import 'package:flutter/material.dart';

enum StempelShape {
  // Garis & Bangun Datar
  garisLurus,
  segitiga,
  persegi,
  persegiPanjang,
  belahKetupat,
  segiLima,
  segiEnam,
  lingkaran,
  
  // Batik/Lainnya
  bintang,
  bunga,
  daun,
  air,
  awan,
  api,
  petir,
  hati,
  bulanSabit,
  silang,
  ceklis,
  panah,
}

class StempelShapePainter extends CustomPainter {
  final StempelShape shape;
  final Color color;
  final double strokeWidth;
  final double opacity;

  StempelShapePainter({
    required this.shape,
    required this.color,
    required this.strokeWidth,
    this.opacity = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double alpha = (color.a * opacity).clamp(0.0, 1.0);
    final paint = Paint()
      ..color = color.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final w = size.width;
    final h = size.height;

    switch (shape) {
      case StempelShape.garisLurus:
        path.moveTo(0, h / 2);
        path.lineTo(w, h / 2);
        break;
      case StempelShape.segitiga:
        path.moveTo(w / 2, 0);
        path.lineTo(w, h);
        path.lineTo(0, h);
        path.close();
        break;
      case StempelShape.persegi:
      case StempelShape.persegiPanjang:
        path.addRect(Rect.fromLTWH(0, 0, w, h));
        break;
      case StempelShape.belahKetupat:
        path.moveTo(w / 2, 0);
        path.lineTo(w, h / 2);
        path.lineTo(w / 2, h);
        path.lineTo(0, h / 2);
        path.close();
        break;
      case StempelShape.segiLima:
        _drawPolygon(path, w, h, 5);
        break;
      case StempelShape.segiEnam:
        _drawPolygon(path, w, h, 6);
        break;
      case StempelShape.lingkaran:
        path.addOval(Rect.fromLTWH(0, 0, w, h));
        break;
      case StempelShape.bintang:
        _drawStar(path, w, h);
        break;
      case StempelShape.bunga:
        _drawFlower(path, w, h);
        break;
      case StempelShape.daun:
        path.moveTo(w / 2, 0);
        path.quadraticBezierTo(w, h / 2, w / 2, h);
        path.quadraticBezierTo(0, h / 2, w / 2, 0);
        path.close();
        break;
      case StempelShape.air:
        path.moveTo(w / 2, 0);
        path.quadraticBezierTo(w, h * 0.7, w / 2, h);
        path.quadraticBezierTo(0, h * 0.7, w / 2, 0);
        path.close();
        break;
      case StempelShape.awan:
        path.moveTo(w * 0.2, h * 0.7);
        path.quadraticBezierTo(0, h * 0.7, 0, h * 0.9);
        path.quadraticBezierTo(0, h, w * 0.2, h);
        path.lineTo(w * 0.8, h);
        path.quadraticBezierTo(w, h, w, h * 0.9);
        path.quadraticBezierTo(w, h * 0.7, w * 0.8, h * 0.7);
        path.quadraticBezierTo(w * 0.8, h * 0.3, w * 0.5, h * 0.3);
        path.quadraticBezierTo(w * 0.2, h * 0.3, w * 0.2, h * 0.7);
        path.close();
        break;
      case StempelShape.api:
        path.moveTo(w / 2, 0);
        path.quadraticBezierTo(w * 0.2, h * 0.4, w * 0.4, h * 0.6);
        path.quadraticBezierTo(0, h * 0.6, w / 2, h);
        path.quadraticBezierTo(w, h * 0.6, w * 0.6, h * 0.6);
        path.quadraticBezierTo(w * 0.8, h * 0.4, w / 2, 0);
        path.close();
        break;
      case StempelShape.petir:
        path.moveTo(w * 0.7, 0);
        path.lineTo(0, h * 0.6);
        path.lineTo(w * 0.4, h * 0.6);
        path.lineTo(w * 0.3, h);
        path.lineTo(w, h * 0.4);
        path.lineTo(w * 0.6, h * 0.4);
        path.close();
        break;
      case StempelShape.hati:
        path.moveTo(w / 2, h * 0.3);
        path.cubicTo(w * 0.1, -0.1 * h, -0.2 * w, h * 0.4, w / 2, h);
        path.cubicTo(w * 1.2, h * 0.4, w * 0.9, -0.1 * h, w / 2, h * 0.3);
        path.close();
        break;
      case StempelShape.bulanSabit:
        path.addArc(Rect.fromLTWH(0, 0, w, h), math.pi / 2, math.pi);
        path.addArc(Rect.fromLTWH(w * 0.2, 0, w * 0.8, h), -math.pi / 2, -math.pi);
        path.fillType = PathFillType.evenOdd;
        break;
      case StempelShape.silang:
        path.moveTo(0, 0);
        path.lineTo(w, h);
        path.moveTo(w, 0);
        path.lineTo(0, h);
        break;
      case StempelShape.ceklis:
        path.moveTo(0, h * 0.5);
        path.lineTo(w * 0.3, h);
        path.lineTo(w, 0);
        break;
      case StempelShape.panah:
        path.moveTo(0, h * 0.4);
        path.lineTo(w * 0.6, h * 0.4);
        path.lineTo(w * 0.6, 0);
        path.lineTo(w, h / 2);
        path.lineTo(w * 0.6, h);
        path.lineTo(w * 0.6, h * 0.6);
        path.lineTo(0, h * 0.6);
        path.close();
        break;
    }

    canvas.drawPath(path, paint);
  }

  void _drawPolygon(Path path, double w, double h, int sides) {
    final cx = w / 2;
    final cy = h / 2;
    final r = math.min(w, h) / 2;
    final angle = 2 * math.pi / sides;
    // Mulai dari atas (rotasi -90 derajat)
    for (int i = 0; i < sides; i++) {
      final x = cx + r * math.cos(i * angle - math.pi / 2);
      final y = cy + r * math.sin(i * angle - math.pi / 2);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
  }

  void _drawStar(Path path, double w, double h) {
    final cx = w / 2;
    final cy = h / 2;
    final outerRadius = math.min(w, h) / 2;
    final innerRadius = outerRadius * 0.4;
    const points = 5;
    const angle = math.pi / points;

    for (int i = 0; i < 2 * points; i++) {
      final r = (i.isEven) ? outerRadius : innerRadius;
      final x = cx + r * math.cos(i * angle - math.pi / 2);
      final y = cy + r * math.sin(i * angle - math.pi / 2);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
  }

  void _drawFlower(Path path, double w, double h) {
    final cx = w / 2;
    final cy = h / 2;
    final r = math.min(w, h) / 2;
    const petals = 6;
    for (int i = 0; i < petals; i++) {
      final angle = (i * 2 * math.pi) / petals;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      path.addOval(Rect.fromCircle(center: Offset((cx + x) / 2, (cy + y) / 2), radius: r / 2));
    }
    path.addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r / 3));
  }

  @override
  bool shouldRepaint(covariant StempelShapePainter oldDelegate) {
    return oldDelegate.shape != shape ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.opacity != opacity;
  }
}
