import 'package:epic_admin/core/utils/evaluation_report.dart';
import 'package:epic_admin/core/theme/admin_colors.dart';
import 'package:flutter/material.dart';

class ResponseDetailDialog extends StatelessWidget {
  final Map<String, dynamic> row;

  const ResponseDetailDialog({super.key, required this.row});

  static void show(BuildContext context, Map<String, dynamic> row) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Tutup detail respons',
      barrierColor: Colors.black.withValues(alpha: .45),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => ResponseDetailDialog(row: row),
      transitionBuilder: (_, animation, __, child) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: .97, end: 1).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final responses = EvaluationReport.ordered(row['responses']);
    final width = MediaQuery.sizeOf(context).width;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: width < 600 ? 16 : 40,
        vertical: 24,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 760),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DialogHeader(row: row),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(width < 600 ? 16 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _Badge(
                          text: row['kategori_level']?.toString() ?? '-',
                        ),
                        _Meta(
                          icon: Icons.schedule_rounded,
                          text: row['tanggal']?.toString() ?? '-',
                        ),
                        _Meta(
                          icon: Icons.school_outlined,
                          text:
                              '${row['sekolah'] ?? '-'} · Kelas ${row['kelas'] ?? '-'}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const SizedBox(height: 22),
                    const Text(
                      'Jawaban Siswa',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Jawaban teks dan hasil live transkrip ditampilkan sebagai satu jawaban.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (responses.isEmpty)
                      const _NoAnswers()
                    else
                      ...responses.asMap().entries.map((entry) {
                        final response = entry.value;
                        return _AnswerCard(
                          index: entry.key,
                          response: response,
                        );
                      }),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        '${row['emotikon'] ?? '-'}${_emotionNote(row)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _emotionNote(Map<String, dynamic> data) {
    final note = data['emotikon_note']?.toString().trim() ?? '';
    return note.isEmpty ? '' : ' — “$note”';
  }
}

class _DialogHeader extends StatelessWidget {
  final Map<String, dynamic> row;

  const _DialogHeader({required this.row});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: AdminColors.primary.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  Icon(Icons.assignment_outlined, color: AdminColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row['nama']?.toString() ?? 'Detail Respons',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '@${row['username']} · ${row['email']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Tutup',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      );
}

class EvaluationResponseCard extends StatelessWidget {
  final Map<String, dynamic> row;
  const EvaluationResponseCard({super.key, required this.row});

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => ResponseDetailDialog.show(context, row),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${row['nama'] ?? '-'}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                  '${row['sekolah'] ?? '-'} • ${row['kelas'] ?? 'Belum diisi'}'),
              const SizedBox(height: 6),
              Text('${row['kategori_level'] ?? '-'}\n${row['tanggal'] ?? '-'}'),
              const SizedBox(height: 8),
              Wrap(spacing: 12, runSpacing: 6, children: [
                Text('${row['emotikon'] ?? '-'}'),
                const Text('Lihat jawaban →',
                    style: TextStyle(color: Colors.blue)),
              ]),
            ]),
          ),
        ),
      );
}

class _AnswerCard extends StatelessWidget {
  final int index;
  final Map<String, dynamic> response;

  const _AnswerCard({required this.index, required this.response});

  @override
  Widget build(BuildContext context) {
    final question = response['questionText']?.toString().trim();
    final manual = response['manualText']?.toString().trim() ?? '';
    final transcript = response['transcript']?.toString().trim() ?? '';
    final answer = manual.isNotEmpty ? manual : transcript;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AdminColors.primary.withValues(alpha: .1),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: AdminColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  question?.isNotEmpty == true
                      ? question!
                      : 'Pertanyaan ${index + 1}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              answer.isEmpty ? 'Belum ada jawaban.' : answer,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: answer.isEmpty
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF334155),
                fontStyle: answer.isEmpty ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;

  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7DF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFFB45309),
            fontWeight: FontWeight.w800,
            fontSize: 10,
          ),
        ),
      );
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Meta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF64748B)),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ),
        ],
      );
}

class _NoAnswers extends StatelessWidget {
  const _NoAnswers();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Tidak ada rincian pertanyaan dan jawaban.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF64748B)),
        ),
      );
}
