import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:epic_admin/core/theme/admin_colors.dart';
import 'package:epic_admin/core/utils/artwork_download_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class KelasGalleryScreen extends StatefulWidget {
  final String classId;

  const KelasGalleryScreen({super.key, required this.classId});

  @override
  State<KelasGalleryScreen> createState() => _KelasGalleryScreenState();
}

class _KelasGalleryScreenState extends State<KelasGalleryScreen> {
  String _category = 'Semua';
  bool _downloading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.background,
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('kelas')
            .doc(widget.classId)
            .snapshots(),
        builder: (context, classSnapshot) {
          final className =
              classSnapshot.data?.data()?['namaKelas']?.toString() ??
                  'Galeri Kelas';
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('artworks')
                .where('kelasId', isEqualTo: widget.classId)
                .snapshots(),
            builder: (context, artworkSnapshot) {
              if (artworkSnapshot.hasError) {
                return _message(
                    'Galeri tidak dapat dimuat.', artworkSnapshot.error);
              }
              if (!artworkSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final all = artworkSnapshot.data!.docs.toList()
                ..sort((a, b) {
                  final aTime = a.data()['createdAt'];
                  final bTime = b.data()['createdAt'];
                  if (aTime is Timestamp && bTime is Timestamp) {
                    return bTime.compareTo(aTime);
                  }
                  return 0;
                });
              final filtered = all.where((doc) {
                if (_category == 'Semua') return true;
                return doc.data()['kategori']?.toString().toLowerCase() ==
                    _category.toLowerCase();
              }).toList();

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream:
                    FirebaseFirestore.instance.collection('users').snapshots(),
                builder: (context, userSnapshot) {
                  final users = <String, Map<String, dynamic>>{};
                  for (final doc in userSnapshot.data?.docs ?? const []) {
                    users[doc.id] = doc.data();
                    final uid = doc.data()['uid']?.toString();
                    if (uid?.isNotEmpty == true) users[uid!] = doc.data();
                  }

                  return LayoutBuilder(
                    builder: (context, pageConstraints) {
                      final isMobile = pageConstraints.maxWidth < 640;
                      return Padding(
                        padding: EdgeInsets.all(isMobile ? 12 : 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _header(context, className, all, isMobile),
                            SizedBox(height: isMobile ? 12 : 18),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: ['Semua', 'Batik', 'Keris', 'Anyaman']
                                    .map((item) => Padding(
                                          padding:
                                              const EdgeInsets.only(right: 8),
                                          child: ChoiceChip(
                                            label: Text(item),
                                            selected: _category == item,
                                            onSelected: (_) => setState(
                                                () => _category = item),
                                          ),
                                        ))
                                    .toList(),
                              ),
                            ),
                            SizedBox(height: isMobile ? 12 : 18),
                            Expanded(
                              child: filtered.isEmpty
                                  ? const Center(child: Text('Belum ada karya.'))
                                  : LayoutBuilder(
                                      builder: (context, constraints) {
                                        final columns = constraints.maxWidth >=
                                                1200
                                            ? 4
                                            : constraints.maxWidth >= 800
                                                ? 3
                                                : constraints.maxWidth >= 520
                                                    ? 2
                                                    : 1;
                                        return GridView.builder(
                                          itemCount: filtered.length,
                                          gridDelegate:
                                              SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: columns,
                                            crossAxisSpacing: isMobile ? 12 : 16,
                                            mainAxisSpacing: isMobile ? 12 : 16,
                                            childAspectRatio:
                                                isMobile ? 1.05 : .82,
                                          ),
                                          itemBuilder: (context, index) {
                                            final data = filtered[index].data();
                                            final studentName =
                                                _studentName(data, users);
                                            return _artworkCard(
                                                data, studentName);
                                          },
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _header(
    BuildContext context,
    String className,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> artworks,
    bool isMobile,
  ) {
    final title = Row(
      children: [
        IconButton(
          tooltip: 'Kembali ke detail kelas',
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                className,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              Text(
                '${artworks.length} karya di Galeri Kelas',
                style: const TextStyle(color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ],
    );
    final download = ElevatedButton.icon(
      onPressed: artworks.isEmpty || _downloading
          ? null
          : () => _downloadAll(className, artworks),
      icon: _downloading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.folder_zip_outlined),
      label: Text(_downloading ? 'Menyiapkan ZIP...' : 'Unduh Semua (ZIP)'),
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [title, const SizedBox(height: 12), download],
      );
    }
    return Row(
      children: [Expanded(child: title), const SizedBox(width: 20), download],
    );
  }

  Widget _artworkCard(Map<String, dynamic> data, String studentName) {
    final url = data['imageUrl']?.toString() ?? '';
    final category = data['kategori']?.toString() ?? 'Karya';
    final title = data['judulKarya']?.toString().trim();
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showArtworkDetail(data, studentName),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: const Color(0xFFF1F5F9),
                  child: url.isEmpty
                      ? const Icon(Icons.image_not_supported_outlined)
                      : Image.network(
                          url,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                              Icons.broken_image_outlined,
                              color: Color(0xFF94A3B8)),
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title?.isNotEmpty == true ? title! : category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      studentName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Nilai ${data['skorAI'] ?? 0} • Grade ${data['grade'] ?? '-'}',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ),
                        const Icon(Icons.open_in_full_rounded,
                            size: 16, color: Color(0xFF64748B)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showArtworkDetail(Map<String, dynamic> artwork, String studentName) {
    final category = artwork['kategori']?.toString() ?? 'Karya';
    final title = artwork['judulKarya']?.toString().trim();
    final displayTitle = title?.isNotEmpty == true ? title! : category;
    final imageUrl = artwork['imageUrl']?.toString() ?? '';
    final grade = artwork['grade']?.toString() ?? '-';
    final score = _intValue(artwork['skorAI']);
    final points = _intValue(artwork['poinDapat'] ?? artwork['points']);
    final level = _intValue(artwork['level'], fallback: 1);
    final duration = _intValue(
        artwork['waktuPengerjaan'] ?? artwork['durationSeconds']);
    final model = artwork['modelAI']?.toString() ?? 'AI';
    final feedback = _feedback(artwork);
    final detail = artwork['detailPenilaian'] is Map
        ? Map<String, dynamic>.from(artwork['detailPenilaian'] as Map)
        : <String, dynamic>{};
    final date = _dateLabel(artwork['createdAt']);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 980,
            maxHeight: MediaQuery.sizeOf(dialogContext).height * .92,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                color: const Color(0xFF1D4ED8),
                padding: const EdgeInsets.fromLTRB(18, 14, 10, 14),
                child: Row(
                  children: [
                    const Icon(Icons.palette_rounded, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(displayTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800)),
                          Text('$studentName • $date',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Color(0xFFDBEAFE), fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Tutup',
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxWidth < 760;
                    final image = _detailImage(imageUrl, grade, isCompact);
                    final info = _detailInfo(
                      score: score,
                      grade: grade,
                      points: points,
                      level: level,
                      duration: duration,
                      detail: detail,
                      feedback: feedback,
                      model: model,
                    );
                    return SingleChildScrollView(
                      padding: EdgeInsets.all(isCompact ? 14 : 24),
                      child: isCompact
                          ? Column(children: [
                              image,
                              const SizedBox(height: 16),
                              info,
                            ])
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 5, child: image),
                                const SizedBox(width: 24),
                                Expanded(flex: 6, child: info),
                              ],
                            ),
                    );
                  },
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Tutup'),
                    ),
                    ElevatedButton.icon(
                      onPressed: imageUrl.isEmpty
                          ? null
                          : () => _downloadOne(artwork, studentName),
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Unduh Karya'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailImage(String imageUrl, String grade, bool compact) {
    return Container(
      height: compact ? 260 : 420,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: imageUrl.isEmpty
                ? const Icon(Icons.image_not_supported_outlined,
                    size: 54, color: Colors.white38)
                : Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image_outlined,
                        size: 54,
                        color: Colors.white38),
                  ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .68),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('Grade $grade',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailInfo({
    required int score,
    required String grade,
    required int points,
    required int level,
    required int duration,
    required Map<String, dynamic> detail,
    required String feedback,
    required String model,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _metric('Skor AI', '$score/100', Icons.auto_awesome_rounded),
            _metric('Grade', grade, Icons.workspace_premium_rounded),
            _metric('Poin', '+$points', Icons.star_rounded),
            _metric('Level', '$level', Icons.trending_up_rounded),
            _metric('Waktu', '${duration}s', Icons.timer_outlined),
          ],
        ),
        if (detail.isNotEmpty) ...[
          const SizedBox(height: 22),
          const Text('Rincian Penilaian AI',
              style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: detail.entries.map((entry) {
                final value = _intValue(entry.value).clamp(0, 100);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(entry.key)),
                          Text('$value%',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 5),
                      LinearProgressIndicator(
                        value: value / 100,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
        const SizedBox(height: 22),
        const Text('Evaluasi & Komentar AI',
            style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.psychology_rounded,
                      size: 18, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Feedback Otomatis ($model)',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2563EB))),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(feedback,
                  style: const TextStyle(
                      height: 1.5, color: Color(0xFF334155))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metric(String label, String value, IconData icon) {
    return Container(
      width: 112,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: AdminColors.primary),
          const SizedBox(height: 5),
          Text(value,
              maxLines: 1,
              style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(label,
              style:
                  const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  String _studentName(Map<String, dynamic> artwork,
      Map<String, Map<String, dynamic>> users) {
    final id = (artwork['userId'] ?? artwork['studentId'] ?? artwork['uid'])
        ?.toString();
    final direct = (artwork['studentName'] ?? artwork['namaSiswa'])?.toString();
    final user = id == null ? null : users[id];
    return (direct?.trim().isNotEmpty == true
            ? direct
            : (user?['namaLengkap'] ?? user?['nama'] ?? user?['name']))
        ?.toString() ??
        'Murid';
  }

  String _feedback(Map<String, dynamic> artwork) {
    for (final key in ['feedback', 'feedbackAI', 'komentarAI']) {
      final value = artwork[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return 'Belum ada komentar AI untuk karya ini.';
  }

  String _dateLabel(dynamic value) {
    if (value is! Timestamp) return 'Tanggal tidak tersedia';
    final date = value.toDate();
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  int _intValue(dynamic value, {int fallback = 0}) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  Future<void> _downloadOne(
      Map<String, dynamic> artwork, String studentName) async {
    try {
      await ArtworkDownloadService.downloadOne(
        artwork,
        studentName: studentName,
      );
    } catch (error) {
      if (mounted) _snack('Gagal mengunduh karya: $error');
    }
  }

  Future<void> _downloadAll(
    String className,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> artworks,
  ) async {
    setState(() => _downloading = true);
    try {
      final count = await ArtworkDownloadService.downloadZip(
        artworks.map((doc) => doc.data()),
        archiveName: 'galeri_kelas_$className',
      );
      if (mounted) _snack('$count karya berhasil dimasukkan ke ZIP.');
    } catch (error) {
      if (mounted) _snack('Gagal membuat ZIP: $error');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Widget _message(String title, Object? error) => Center(
        child: Text('$title\n${error ?? ''}', textAlign: TextAlign.center),
      );

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
