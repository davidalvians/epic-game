import 'package:archive/archive.dart';
import 'package:epic_admin/core/utils/file_download_helper.dart';
import 'package:http/http.dart' as http;

class ArtworkDownloadService {
  static Future<void> downloadOne(
    Map<String, dynamic> artwork, {
    String? studentName,
  }) async {
    final url = artwork['imageUrl']?.toString().trim() ?? '';
    if (url.isEmpty) throw StateError('Karya tidak memiliki gambar.');
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw StateError('Gagal mengunduh gambar (${response.statusCode}).');
    }
    final extension = _extension(response.headers['content-type'], url);
    final category = artwork['kategori']?.toString() ?? 'karya';
    final name =
        _safeName(studentName ?? artwork['uid']?.toString() ?? 'siswa');
    FileDownloadHelper.downloadBytes(
      response.bodyBytes,
      '${_safeName(category)}_$name.$extension',
      response.headers['content-type'] ?? 'image/$extension',
    );
  }

  static Future<int> downloadZip(
    Iterable<Map<String, dynamic>> artworks, {
    required String archiveName,
    String Function(Map<String, dynamic>)? studentName,
  }) async {
    final archive = Archive();
    var added = 0;
    for (final artwork in artworks) {
      final url = artwork['imageUrl']?.toString().trim() ?? '';
      if (url.isEmpty) continue;
      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode != 200) continue;
        final extension = _extension(response.headers['content-type'], url);
        final category = artwork['kategori']?.toString() ?? 'karya';
        final owner =
            studentName?.call(artwork) ?? artwork['uid']?.toString() ?? 'siswa';
        final fileName =
            '${(added + 1).toString().padLeft(3, '0')}_${_safeName(owner)}_${_safeName(category)}.$extension';
        archive.addFile(
          ArchiveFile(fileName, response.bodyBytes.length, response.bodyBytes),
        );
        added++;
      } catch (_) {
        // Satu gambar gagal tidak membatalkan unduhan karya lainnya.
      }
    }
    if (added == 0) throw StateError('Tidak ada gambar yang dapat diunduh.');
    final bytes = ZipEncoder().encode(archive);
    FileDownloadHelper.downloadBytes(
      bytes,
      '${_safeName(archiveName)}.zip',
      'application/zip',
    );
    return added;
  }

  static String _safeName(String value) {
    final cleaned = value
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    return cleaned.isEmpty ? 'karya' : cleaned;
  }

  static String _extension(String? contentType, String url) {
    final type = contentType?.toLowerCase() ?? '';
    if (type.contains('jpeg') || type.contains('jpg')) return 'jpg';
    if (type.contains('webp')) return 'webp';
    if (type.contains('gif')) return 'gif';
    if (url.toLowerCase().contains('.jpg') ||
        url.toLowerCase().contains('.jpeg')) {
      return 'jpg';
    }
    return 'png';
  }
}
