import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class LaporanPdfGenerator {
  static Future<Uint8List> generateReport({
    required String title,
    required String dateRange,
    required String classFilter,
    required String schoolFilter,
    required List<String> headers,
    required List<double> columnWidths,
    required List<List<String>> rows,
  }) async {
    final pdf = pw.Document();

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
                          'LAPORAN SISTEM MONITORING - PLATFORM EPIC',
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
                            color: PdfColor.fromHex('#475569'),
                          ),
                        ),
                      ],
                    ),
                    pw.Text(
                      'TANGGAL CETAK: ${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#475569'),
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
            // Metadata Parameters Block
            pw.Container(
              margin: const pw.EdgeInsets.only(top: 8, bottom: 20),
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F8FAFC'),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0'), width: 0.5),
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildMetaText('Jenis Laporan', title),
                        pw.SizedBox(height: 4),
                        _buildMetaText('Rentang Waktu', dateRange),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildMetaText('Filter Kelas', classFilter),
                        pw.SizedBox(height: 4),
                        _buildMetaText('Filter Sekolah', schoolFilter),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Data Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColor.fromHex('#E2E8F0'), width: 0.5),
              columnWidths: {
                for (int i = 0; i < columnWidths.length; i++)
                  i: pw.FlexColumnWidth(columnWidths[i]),
              },
              children: [
                // Table Header Row
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColor.fromHex('#1E3A8A')),
                  children: headers.map((h) {
                    return pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                      child: pw.Text(
                        h,
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 8.5,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    );
                  }).toList(),
                ),

                // Table Data Rows
                ...List.generate(rows.length, (index) {
                  final rowData = rows[index];
                  final isEven = index % 2 == 0;
                  final rowBgColor = isEven ? PdfColors.white : PdfColor.fromHex('#F8FAFC');

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: rowBgColor),
                    children: rowData.map((cellText) {
                      return pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                        child: pw.Text(
                          cellText,
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                      );
                    }).toList(),
                  );
                }),
              ],
            ),

            // Licensing block at bottom
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
                    'Laporan ini diterbitkan secara resmi oleh Platform EPIC. Hak Cipta © 2026. Data di dalam laporan ini bersifat konfidensial untuk pemantauan evaluasi pendidikan sekolah mitra.',
                    style: pw.TextStyle(
                      fontSize: 7,
                      color: PdfColor.fromHex('#475569'),
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

  static pw.Widget _buildMetaText(String label, String value) {
    return pw.RichText(
      text: pw.TextSpan(
        text: '$label: ',
        style: pw.TextStyle(fontSize: 8.5, color: PdfColor.fromHex('#64748B'), fontWeight: pw.FontWeight.bold),
        children: [
          pw.TextSpan(
            text: value,
            style: pw.TextStyle(fontSize: 8.5, color: PdfColor.fromHex('#1E293B'), fontWeight: pw.FontWeight.normal),
          ),
        ],
      ),
    );
  }
}
