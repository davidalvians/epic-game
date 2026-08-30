import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:cloud_firestore/cloud_firestore.dart';

class KelasPdfGenerator {
  static Future<Uint8List> generateReport({
    required String className,
    required String classCode,
    required String teacherName,
    required String school,
    required String createdDate,
    required List<Map<String, dynamic>> studentRows,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> classArtworksDocs,
  }) async {
    final pdf = pw.Document();

    // Calculate executive summary metrics
    final int totalStudents = studentRows.length;
    final int totalPoin = studentRows.fold<int>(0, (sum, s) => sum + (s['points'] as int));
    final int totalKarya = classArtworksDocs.length;
    double avgSkorAI = 0.0;
    if (totalKarya > 0) {
      double sumAI = classArtworksDocs.fold<double>(0.0, (sum, doc) {
        final data = doc.data();
        final score = data['skorAI'] is int ? data['skorAI'] as int : 0;
        return sum + score;
      });
      avgSkorAI = sumAI / totalKarya;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 16),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'LAPORAN DATA KELAS - PLATFORM EPIC',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#1E3A8A'),
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'EPIC: Ecocultural Pattern Innovation Creator',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.normal,
                            color: PdfColor.fromHex('#475569'),
                          ),
                        ),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#EFF6FF'),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                        border: pw.Border.all(color: PdfColor.fromHex('#3B82F6'), width: 0.5),
                      ),
                      child: pw.Text(
                        'KODE KELAS: $classCode',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#1E40AF'),
                        ),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.Container(height: 1.5, color: PdfColor.fromHex('#2563EB')),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            // Metadata Grid Section
            pw.Container(
              margin: const pw.EdgeInsets.only(top: 8, bottom: 20),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 1,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildMetadataText('Nama Kelas', className, isBold: true),
                        _buildMetadataText('Wali/Guru Kelas', teacherName),
                        _buildMetadataText('Nama Sekolah', school),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildMetadataText('Tanggal Pembuatan', createdDate),
                        _buildMetadataText('Jumlah Siswa', '$totalStudents Murid'),
                        _buildMetadataText('Tanggal Cetak', '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Executive summary metrics row
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 24),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _buildPdfMetricCard('TOTAL MURID AKTIF', totalStudents.toString(), PdfColor.fromHex('#EFF6FF'), PdfColor.fromHex('#1E40AF')),
                  _buildPdfMetricCard('TOTAL POIN KELAS', totalPoin.toString(), PdfColor.fromHex('#FEF3C7'), PdfColor.fromHex('#92400E')),
                  _buildPdfMetricCard('TOTAL KARYA DISUBMIT', totalKarya.toString(), PdfColor.fromHex('#F5F3FF'), PdfColor.fromHex('#5B21B6')),
                  _buildPdfMetricCard('RATA-RATA SKOR AI KELAS', avgSkorAI.toStringAsFixed(1), PdfColor.fromHex('#ECFDF5'), PdfColor.fromHex('#065F46')),
                ],
              ),
            ),

            // Section title
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 10),
              child: pw.Text(
                'RINCIAN DATA KINERJA MURID',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#0F172A'),
                ),
              ),
            ),

            // Table of students
            pw.Table(
              border: pw.TableBorder.all(color: PdfColor.fromHex('#E2E8F0'), width: 0.5),
              columnWidths: const {
                0: pw.FixedColumnWidth(22),  // No
                1: pw.FixedColumnWidth(28),  // Rank
                2: pw.FlexColumnWidth(3),    // Nama Lengkap
                3: pw.FlexColumnWidth(2),    // Nama Panggilan
                4: pw.FlexColumnWidth(2),    // Username
                5: pw.FixedColumnWidth(35),  // Poin
                6: pw.FixedColumnWidth(30),  // Karya
                7: pw.FixedColumnWidth(40),  // Lvl Keris
                8: pw.FixedColumnWidth(40),  // Lvl Batik
                9: pw.FixedColumnWidth(40),  // Lvl Anyaman
                10: pw.FixedColumnWidth(40), // Rata AI
                11: pw.FixedColumnWidth(35), // Grade
                12: pw.FixedColumnWidth(50), // Aktif
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#1E3A8A'),
                  ),
                  children: [
                    'No',
                    'Rank',
                    'Nama Lengkap',
                    'Nama Panggil',
                    'Username',
                    'Poin',
                    'Karya',
                    'Lvl Keris',
                    'Lvl Batik',
                    'Lvl Anyaman',
                    'Rata AI',
                    'Grade',
                    'Aktif'
                  ].map((header) {
                    return pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      child: pw.Text(
                        header,
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 7.5,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    );
                  }).toList(),
                ),

                // Data rows
                ...List.generate(studentRows.length, (index) {
                  final student = studentRows[index];
                  final uid = student['uid'] ?? '';
                  final rank = student['rank'] != null ? '#${student['rank']}' : '#${index + 1}';
                  final name = student['name'] ?? '';
                  final nickname = student['namaPanggilan'] ?? '-';
                  final username = student['username'] ?? '-';
                  final points = student['points'] ?? 0;
                  final artworksCount = student['artworks'] ?? 0;
                  final topGrade = student['grade'] ?? '-';
                  final lastActive = student['active'] ?? '-';

                  // Filter artworks by this student
                  final studentArt = classArtworksDocs.where((doc) {
                    final data = doc.data();
                    return data['uid'] == uid;
                  }).toList();

                  final kerisArts = studentArt.where((a) => (a.data()['kategori'] ?? '').toString().toLowerCase() == 'keris').toList();
                  final maxKeris = kerisArts.isEmpty ? '-' : kerisArts.map((a) => a.data()['level'] is int ? a.data()['level'] as int : 0).reduce((a, b) => a > b ? a : b).toString();

                  final batikArts = studentArt.where((a) => (a.data()['kategori'] ?? '').toString().toLowerCase() == 'batik').toList();
                  final maxBatik = batikArts.isEmpty ? '-' : batikArts.map((a) => a.data()['level'] is int ? a.data()['level'] as int : 0).reduce((a, b) => a > b ? a : b).toString();

                  final anyamanArts = studentArt.where((a) => (a.data()['kategori'] ?? '').toString().toLowerCase() == 'anyaman').toList();
                  final maxAnyaman = anyamanArts.isEmpty ? '-' : anyamanArts.map((a) => a.data()['level'] is int ? a.data()['level'] as int : 0).reduce((a, b) => a > b ? a : b).toString();

                  final double avgAI = studentArt.isEmpty
                      ? 0.0
                      : studentArt.fold<int>(0, (acc, a) => acc + (a.data()['skorAI'] is int ? a.data()['skorAI'] as int : 0)) / studentArt.length;

                  final rowBgColor = index % 2 == 0 ? PdfColor.fromHex('#FFFFFF') : PdfColor.fromHex('#F8FAFC');

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: rowBgColor,
                    ),
                    children: [
                      (index + 1).toString(),
                      rank,
                      name,
                      nickname,
                      username,
                      points.toString(),
                      artworksCount.toString(),
                      maxKeris,
                      maxBatik,
                      maxAnyaman,
                      avgAI.toStringAsFixed(1),
                      topGrade,
                      lastActive,
                    ].map((text) {
                      final isNum = int.tryParse(text) != null || double.tryParse(text) != null || text == '-';
                      return pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                        child: pw.Text(
                          text,
                          style: const pw.TextStyle(fontSize: 7),
                          textAlign: isNum ? pw.TextAlign.center : pw.TextAlign.left,
                        ),
                      );
                    }).toList(),
                  );
                }),
              ],
            ),

            // Licensing block at bottom of document
            pw.Container(
              margin: const pw.EdgeInsets.only(top: 24),
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F1F5F9'),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                border: pw.Border.all(color: PdfColor.fromHex('#CBD5E1'), width: 0.5),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'LISENSI PENGGUNAAN & HAK CIPTA EPIC (ECOCULTURAL PATTERN INNOVATION CREATOR)',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#1E293B'),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Laporan ini diterbitkan secara otomatis oleh Platform EPIC (Ecocultural Pattern Innovation Creator). Hak Cipta © 2026. Semua Hak Dilindungi Undang-Undang. Data siswa, skor, dan karya seni yang terangkum dalam laporan ini bersifat konfidensial dan dilisensikan khusus untuk kepentingan evaluasi pendidikan dan pemantauan guru wali kelas di bawah pengawasan kurikulum terkait.',
                    style: pw.TextStyle(
                      fontSize: 7,
                      color: PdfColor.fromHex('#475569'),
                      lineSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ];
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 16),
            child: pw.Text(
              'Halaman ${context.pageNumber} dari ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildMetadataText(String label, String value, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.RichText(
        text: pw.TextSpan(
          text: '$label: ',
          style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#64748B'), fontWeight: pw.FontWeight.bold),
          children: [
            pw.TextSpan(
              text: value,
              style: pw.TextStyle(
                fontSize: 8, 
                color: PdfColor.fromHex('#1E293B'), 
                fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildPdfMetricCard(String label, String value, PdfColor bgColor, PdfColor textColor) {
    return pw.Container(
      width: 175,
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: pw.BoxDecoration(
        color: bgColor,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: PdfColor(textColor.red, textColor.green, textColor.blue, 0.18), width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor(textColor.red, textColor.green, textColor.blue, 0.75),
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
