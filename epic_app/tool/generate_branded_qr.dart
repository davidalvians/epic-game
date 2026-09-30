import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;
import 'package:qr/qr.dart';

const targetUrl = 'https://epicapp.my.id/download.html';
const outputPath = 'public/qr-download-epic.png';
const logoPath = 'public/logo.png';

img.ColorRgb8 rgb(int red, int green, int blue) =>
    img.ColorRgb8(red, green, blue);

img.ColorRgb8 blend(img.ColorRgb8 start, img.ColorRgb8 end, double amount) {
  final t = amount.clamp(0.0, 1.0);
  return rgb(
    (start.r + (end.r - start.r) * t).round(),
    (start.g + (end.g - start.g) * t).round(),
    (start.b + (end.b - start.b) * t).round(),
  );
}

void fillGradient(
  img.Image canvas, {
  required img.ColorRgb8 start,
  required img.ColorRgb8 end,
}) {
  for (var y = 0; y < canvas.height; y++) {
    final color = blend(start, end, y / (canvas.height - 1));
    img.drawLine(
      canvas,
      x1: 0,
      y1: y,
      x2: canvas.width - 1,
      y2: y,
      color: color,
    );
  }
}

bool isFinderModule(int row, int column, int moduleCount) {
  final topLeft = row < 7 && column < 7;
  final topRight = row < 7 && column >= moduleCount - 7;
  final bottomLeft = row >= moduleCount - 7 && column < 7;
  return topLeft || topRight || bottomLeft;
}

void drawFinderEye(
  img.Image canvas, {
  required int left,
  required int top,
  required int moduleSize,
  required img.ColorRgb8 color,
}) {
  final outerSize = moduleSize * 7;
  img.fillRect(
    canvas,
    x1: left,
    y1: top,
    x2: left + outerSize - 1,
    y2: top + outerSize - 1,
    radius: moduleSize * 1.25,
    color: color,
  );
  img.fillRect(
    canvas,
    x1: left + moduleSize,
    y1: top + moduleSize,
    x2: left + outerSize - moduleSize - 1,
    y2: top + outerSize - moduleSize - 1,
    radius: moduleSize * 0.8,
    color: rgb(255, 255, 255),
  );
  img.fillRect(
    canvas,
    x1: left + moduleSize * 2,
    y1: top + moduleSize * 2,
    x2: left + outerSize - moduleSize * 2 - 1,
    y2: top + outerSize - moduleSize * 2 - 1,
    radius: moduleSize * 0.55,
    color: color,
  );
}

void main() {
  const canvasWidth = 1400;
  const canvasHeight = 1600;
  const cardLeft = 100;
  const cardTop = 235;
  const cardRight = 1300;
  const cardBottom = 1435;
  const quietZone = 4;

  final canvas = img.Image(width: canvasWidth, height: canvasHeight);
  fillGradient(
    canvas,
    start: rgb(21, 21, 24),
    end: rgb(38, 25, 54),
  );

  img.fillCircle(
    canvas,
    x: 120,
    y: 170,
    radius: 210,
    color: img.ColorRgba8(255, 117, 0, 28),
  );
  img.fillCircle(
    canvas,
    x: 1320,
    y: 220,
    radius: 260,
    color: img.ColorRgba8(139, 92, 246, 32),
  );

  img.fillRect(
    canvas,
    x1: cardLeft + 12,
    y1: cardTop + 22,
    x2: cardRight + 12,
    y2: cardBottom + 22,
    radius: 66,
    color: img.ColorRgba8(0, 0, 0, 48),
  );
  img.fillRect(
    canvas,
    x1: cardLeft,
    y1: cardTop,
    x2: cardRight,
    y2: cardBottom,
    radius: 66,
    color: rgb(255, 255, 255),
  );

  img.drawString(
    canvas,
    'SCAN & UNDUH EPIC',
    font: img.arial48,
    y: 94,
    color: rgb(255, 255, 255),
  );
  img.drawString(
    canvas,
    'Belajar budaya jadi lebih seru',
    font: img.arial24,
    y: 167,
    color: rgb(205, 196, 219),
  );

  final code = QrCode.fromData(
    data: targetUrl,
    errorCorrectLevel: QrErrorCorrectLevel.H,
  );
  final qr = QrImage(code);
  final moduleSize = 22;
  final qrSize = (qr.moduleCount + quietZone * 2) * moduleSize;
  final qrLeft = (canvasWidth - qrSize) ~/ 2;
  final qrTop = 280;
  final dataLeft = qrLeft + quietZone * moduleSize;
  final dataTop = qrTop + quietZone * moduleSize;
  final orange = rgb(196, 65, 0);
  final purple = rgb(76, 29, 149);

  for (var row = 0; row < qr.moduleCount; row++) {
    for (var column = 0; column < qr.moduleCount; column++) {
      if (!qr.isDark(row, column) ||
          isFinderModule(row, column, qr.moduleCount)) {
        continue;
      }

      final progress = (row + column) / (2 * (qr.moduleCount - 1));
      final moduleColor = blend(orange, purple, progress);
      final left = dataLeft + column * moduleSize + 1;
      final top = dataTop + row * moduleSize + 1;
      img.fillRect(
        canvas,
        x1: left,
        y1: top,
        x2: left + moduleSize - 3,
        y2: top + moduleSize - 3,
        radius: 5,
        color: moduleColor,
      );
    }
  }

  drawFinderEye(
    canvas,
    left: dataLeft,
    top: dataTop,
    moduleSize: moduleSize,
    color: orange,
  );
  drawFinderEye(
    canvas,
    left: dataLeft + (qr.moduleCount - 7) * moduleSize,
    top: dataTop,
    moduleSize: moduleSize,
    color: purple,
  );
  drawFinderEye(
    canvas,
    left: dataLeft,
    top: dataTop + (qr.moduleCount - 7) * moduleSize,
    moduleSize: moduleSize,
    color: blend(orange, purple, 0.62),
  );

  const logoPlateSize = 180;
  const logoSize = 154;
  final logoCenterX = canvasWidth ~/ 2;
  final logoCenterY = dataTop + (qr.moduleCount * moduleSize) ~/ 2;
  img.fillCircle(
    canvas,
    x: logoCenterX,
    y: logoCenterY,
    radius: logoPlateSize ~/ 2,
    color: rgb(255, 255, 255),
  );

  final sourceLogo = img.decodeImage(File(logoPath).readAsBytesSync());
  if (sourceLogo == null) {
    throw StateError('Logo EPIC tidak dapat dibaca dari $logoPath');
  }
  final circularLogo = img.copyCropCircle(sourceLogo);
  final resizedLogo = img.copyResize(
    circularLogo,
    width: logoSize,
    height: logoSize,
    interpolation: img.Interpolation.cubic,
  );
  img.compositeImage(
    canvas,
    resizedLogo,
    dstX: logoCenterX - logoSize ~/ 2,
    dstY: logoCenterY - logoSize ~/ 2,
  );

  img.drawString(
    canvas,
    'EPIC',
    font: img.arial48,
    y: 1290,
    color: rgb(34, 24, 46),
  );
  img.drawString(
    canvas,
    'epicapp.my.id/download.html',
    font: img.arial24,
    y: 1350,
    color: rgb(106, 89, 123),
  );
  img.drawString(
    canvas,
    'Ecocultural Pattern Innovation Creator',
    font: img.arial24,
    y: 1510,
    color: rgb(207, 198, 220),
  );

  File(outputPath).writeAsBytesSync(img.encodePng(canvas, level: 6));
  final sizeKb = math.max(1, File(outputPath).lengthSync() ~/ 1024);
  stdout.writeln('QR EPIC dibuat: $outputPath ($sizeKb KB)');
  stdout.writeln('Tujuan: $targetUrl');
  stdout.writeln('QR version: ${code.typeNumber}, modules: ${qr.moduleCount}');
}
