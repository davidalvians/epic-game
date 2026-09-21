import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Shared ordering and export contract for all evaluation screens.
class EvaluationReport {
  static Map<String, dynamic> fromRaw(
      Map<String, dynamic> data, Map<String, dynamic> profile) {
    final emotion = data['emotion'] is Map ? data['emotion'] as Map : {};
    final rawDate = data['submittedAt'];
    final date = rawDate is Timestamp
        ? rawDate.toDate()
        : DateTime.tryParse(rawDate?.toString() ?? '');
    return {
      'nama': profile['namaLengkap'] ??
          profile['nama'] ??
          data['studentName'] ??
          '-',
      'username': profile['username'] ?? '-',
      'email': profile['email'] ?? '-',
      'sekolah': profile['sekolah'] ?? data['sekolah'] ?? '-',
      'kelas': schoolGrade(profile, data),
      'kategori_level':
          '${data['categoryId'] ?? '-'} - Level ${data['levelId'] ?? '-'}',
      'tanggal': date == null
          ? '-'
          : '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
      'emotikon': '${emotion['icon'] ?? ''} ${emotion['label'] ?? '-'}',
      'emotikon_note': emotion['note'] ?? '',
      'responses': ordered(data['responses']),
    };
  }

  static String schoolGrade(Map<String, dynamic> profile,
      [Map<String, dynamic> evaluation = const {}]) {
    for (final value in [profile['kelas'], evaluation['kelas']]) {
      final text = value?.toString().trim() ?? '';
      final match =
          RegExp(r'^(?:kelas\s*)?([1-6])(?:\s*sd)?$', caseSensitive: false)
              .firstMatch(text);
      if (match != null) return '${match.group(1)} SD';
    }
    return 'Belum diisi';
  }

  static List<Map<String, dynamic>> ordered(dynamic raw) {
    if (raw is! List) return [];
    final indexed = raw
        .whereType<Map>()
        .map((r) => Map<String, dynamic>.from(r))
        .toList()
        .asMap()
        .entries
        .toList();
    int order(MapEntry<int, Map<String, dynamic>> e) =>
        int.tryParse('${e.value['questionIndex']}') ?? e.key;
    indexed.sort((a, b) {
      final result = order(a).compareTo(order(b));
      return result == 0 ? a.key.compareTo(b.key) : result;
    });
    return indexed.map((e) => e.value).toList();
  }

  static String answer(Map<String, dynamic> item) {
    for (final key in ['manualText', 'transcript']) {
      final text = item[key]?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return 'Belum dijawab';
  }

  /// CSV has one question and answer column pair per question, then emotion.
  static String csv(List<Map<String, dynamic>> rows) {
    final questions = rows.map((r) => ordered(r['responses'])).toList();
    final maxCount =
        questions.fold<int>(0, (n, list) => list.length > n ? list.length : n);
    final headers = [
      'No',
      'Nama Siswa',
      'Username',
      'Email',
      'Sekolah',
      'Kelas',
      'Kategori & Level',
      'Waktu Pengisian',
      for (var q = 1; q <= maxCount; q++) ...['Pertanyaan $q', 'Jawaban $q'],
      'Emoji & Perasaan',
      'Jawaban Perasaan'
    ];
    String cell(dynamic value) {
      var text = value?.toString() ?? '';
      if (RegExp(r'^\s*[=+@-]').hasMatch(text)) text = "'$text";
      return '"${text.replaceAll('"', '""')}"';
    }

    final buffer = StringBuffer('\uFEFF')..writeln(headers.map(cell).join(','));
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      buffer.writeln([
        i + 1,
        row['nama'],
        row['username'],
        row['email'],
        row['sekolah'],
        row['kelas'],
        row['kategori_level'],
        row['tanggal'],
        for (var q = 0; q < maxCount; q++) ...[
          q < questions[i].length ? questions[i][q]['questionText'] : '',
          q < questions[i].length ? answer(questions[i][q]) : '',
        ],
        row['emotikon'],
        row['emotikon_note'],
      ].map(cell).join(','));
    }
    return buffer.toString();
  }

  static Future<Uint8List> pdf(List<Map<String, dynamic>> rows,
      {String scope = 'Semua respons terfilter',
      ByteData? textFont,
      ByteData? emojiFont}) async {
    final regular = pw.Font.ttf(
        textFont ?? await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
    final emoji = pw.Font.ttf(
        emojiFont ?? await rootBundle.load('assets/fonts/NotoColorEmoji.ttf'));
    final document = pw.Document();
    final widgets = <pw.Widget>[];
    pw.Widget text(String value, {double size = 10}) => pw.Text(value,
        style: pw.TextStyle(fontSize: size, fontFallback: [emoji]));
    // Short chunks keep long answers splittable across pages without clipping.
    List<String> chunks(String value) {
      final runes = value.runes.toList();
      final result = <String>[];
      var start = 0;
      while (start < runes.length) {
        var end = (start + 700).clamp(0, runes.length);
        if (end < runes.length) {
          var boundary = end;
          while (boundary > start + 350 &&
              runes[boundary - 1] != 32 &&
              runes[boundary - 1] != 10) {
            boundary--;
          }
          if (boundary > start + 350) end = boundary;
        }
        result.add(String.fromCharCodes(runes.sublist(start, end)));
        start = end;
      }
      return result;
    }

    void section(String title, String value) {
      widgets.add(pw.Table(
        border: pw.TableBorder.all(color: PdfColors.blueGrey200),
        children: [
          pw.TableRow(
              repeat: true,
              decoration: const pw.BoxDecoration(color: PdfColors.blue50),
              children: [
                pw.Padding(
                    padding: const pw.EdgeInsets.all(9), child: text(title))
              ]),
          for (final chunk in chunks(value.isEmpty ? 'Belum dijawab' : value))
            pw.TableRow(children: [
              pw.Padding(
                  padding: const pw.EdgeInsets.all(10), child: text(chunk))
            ]),
        ],
      ));
      widgets.add(pw.SizedBox(height: 10));
    }

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (i > 0) widgets.add(pw.NewPage());
      widgets.add(text('${i + 1}. ${row['nama'] ?? '-'}', size: 16));
      widgets.add(pw.SizedBox(height: 10));
      section(
          'Identitas Siswa',
          'Username: ${row['username'] ?? '-'}\nEmail: ${row['email'] ?? '-'}\n'
              'Sekolah: ${row['sekolah'] ?? '-'}\nKelas: ${row['kelas'] ?? 'Belum diisi'}\n'
              'Kategori & level: ${row['kategori_level'] ?? '-'}\nWaktu: ${row['tanggal'] ?? '-'}');
      final responses = ordered(row['responses']);
      for (var q = 0; q < responses.length; q++) {
        section(
            'Pertanyaan ${q + 1}', '${responses[q]['questionText'] ?? '-'}');
        section('Jawaban ${q + 1}', answer(responses[q]));
      }
      if (responses.isEmpty) section('Jawaban Siswa', 'Belum ada jawaban.');
      section('Perasaan Siswa', '${row['emotikon'] ?? '-'}');
      section('Jawaban Perasaan', '${row['emotikon_note'] ?? ''}');
    }
    document.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      maxPages: 10000,
      margin: const pw.EdgeInsets.all(32),
      theme: pw.ThemeData.withFont(
          base: regular, bold: regular, fontFallback: [emoji]),
      header: (_) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 18),
          child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                text('EPIC - Laporan Respons Evaluasi Siswa', size: 15),
                pw.SizedBox(height: 4),
                text(scope, size: 8),
                pw.Divider(color: PdfColors.blue700)
              ])),
      footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child:
              text('Halaman ${ctx.pageNumber} / ${ctx.pagesCount}', size: 8)),
      build: (_) => widgets,
    ));
    return document.save();
  }
}
