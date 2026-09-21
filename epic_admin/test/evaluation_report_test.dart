import 'dart:io';
import 'package:epic_admin/core/utils/evaluation_report.dart';
import 'package:epic_admin/features/evaluasi/widgets/response_detail_dialog.dart';
import 'package:epic_admin/features/evaluasi/widgets/student_responses_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final row = <String, dynamic>{
    'nama': 'Siswa Contoh',
    'username': 'contoh',
    'email': 'contoh@example.test',
    'sekolah': 'SD Negeri Contoh Dengan Nama Sekolah Panjang',
    'kelas': '4 SD',
    'kategori_level': 'BATIK - Level 2',
    'tanggal': '21/09/2026 10:15',
    'emotikon': '🤩 Bangga Banget!',
    'emotikon_note': 'Senang karena berhasil 😄',
    'responses': [
      {
        'questionIndex': 1,
        'questionText': 'Bagaimana pola berikutnya?',
        'manualText': 'Jawaban kedua'
      },
      {
        'questionIndex': 0,
        'questionText': 'Mengapa memilih pola ini?',
        'manualText': 'Jawaban pertama',
        'transcript': 'Teks lama'
      },
    ],
  };
  test('Profile grade excludes teacher class and falls back to saved grade',
      () {
    expect(EvaluationReport.schoolGrade({'kelas': '4 SD'}), '4 SD');
    expect(
        EvaluationReport.schoolGrade({'kelas': '-'}, {'kelas': '6'}), '6 SD');
    expect(EvaluationReport.schoolGrade({'kelas': 'Kelas Bu Guru'}),
        'Belum diisi');
  });
  test('Question order, single answer, CSV columns and emoji are preserved',
      () {
    final sorted = EvaluationReport.ordered(row['responses']);
    expect(sorted.first['questionIndex'], 0);
    expect(EvaluationReport.answer(sorted.first), 'Jawaban pertama');
    final csv = EvaluationReport.csv([row]);
    expect(csv.startsWith('\uFEFF'), true);
    expect(csv.indexOf('Jawaban 1'), lessThan(csv.indexOf('Jawaban 2')));
    expect(
        csv.indexOf('Jawaban pertama'), lessThan(csv.indexOf('Jawaban kedua')));
    expect(csv.contains('🤩'), true);
    expect(csv.contains(' | '), false);
  });
  test('PDF handles long answers across pages and renders emoji', () async {
    final longRow = {
      ...row,
      'nama': 'Uji Jawaban Panjang',
      'responses': [
        {
          'questionIndex': 0,
          'questionText': 'Jelaskan pola secara lengkap.',
          'manualText':
              List.filled(140, 'Pola berulang dengan urutan warna dan bentuk.')
                  .join(' ')
        },
      ]
    };
    final bytes = await EvaluationReport.pdf([row, longRow],
        scope: 'CONTOH DATA - Pengujian urutan, emoji, dan pemisahan halaman',
        textFont: ByteData.sublistView(
            File('assets/fonts/NotoSans-Regular.ttf').readAsBytesSync()),
        emojiFont: ByteData.sublistView(
            File('assets/fonts/NotoColorEmoji.ttf').readAsBytesSync()));
    expect(bytes.length, greaterThan(1000));
    Directory('output/pdf').createSync(recursive: true);
    File('output/pdf/contoh_laporan_evaluasi.pdf').writeAsBytesSync(bytes);
  });
  for (final width in [320.0, 390.0, 768.0, 1280.0]) {
    testWidgets('Response list fits width $width', (tester) async {
      tester.view.physicalSize = Size(width, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Padding(
                  padding: const EdgeInsets.all(12),
                  child: StudentResponsesTab(
                      isLoading: false,
                      filteredResponses: [row],
                      searchQuery: '',
                      filterCategory: 'Semua Kategori',
                      filterLevel: 'Semua Level',
                      onSearchChanged: (_) {},
                      onCategoryChanged: (_) {},
                      onLevelChanged: (_) {})))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
    testWidgets('Response dialog fits width $width with large text',
        (tester) async {
      tester.view.physicalSize = Size(width, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
              data: MediaQueryData(
                  size: Size(width, 850),
                  textScaler: const TextScaler.linear(1.2)),
              child: Scaffold(body: ResponseDetailDialog(row: row)))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
          tester.getTopLeft(find.text('Mengapa memilih pola ini?')).dy,
          lessThan(
              tester.getTopLeft(find.text('Bagaimana pola berikutnya?')).dy));
    });
  }
}
