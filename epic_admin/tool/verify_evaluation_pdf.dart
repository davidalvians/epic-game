import 'dart:io';

import 'package:epic_admin/core/utils/laporan_pdf_generator.dart';

Future<void> main() async {
  final bytes = await LaporanPdfGenerator.generateReport(
    title: 'Respons Evaluasi Siswa',
    dateRange: '01/09/2026 - 19/09/2026',
    classFilter: 'Semua Level',
    schoolFilter: 'Semua Kategori',
    headers: const [
      'No',
      'Siswa',
      'Sekolah / Kelas',
      'Kategori',
      'Waktu',
      'Perasaan',
      'Jawaban',
    ],
    columnWidths: const [0.5, 1.5, 2.0, 1.3, 1.3, 1.2, 3.2],
    rows: const [
      [
        '1',
        'Rizal Fauzi',
        'SD Negeri 1 / Kelas 4 SD',
        'KERIS - Level 2',
        '19/09/2026 17:28',
        'Pantang Menyerah',
        'Saya mencoba kembali pola yang belum sesuai sampai berhasil.',
      ],
      [
        '2',
        'Siti Aminah',
        'SD Negeri 2 / Kelas 5 SD',
        'BATIK - Level 1',
        '18/09/2026 13:43',
        'Bangga Banget!',
        'Saya menemukan pola berulang dan menjelaskan urutannya.',
      ],
    ],
  );
  final output = File('output/pdf/evaluasi_export_preview.pdf');
  await output.parent.create(recursive: true);
  await output.writeAsBytes(bytes);
}
