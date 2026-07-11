// Repository untuk membaca template gambar dari Firestore
// Template dikelola admin melalui Admin Panel
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:epic_app/data/models/drawing_template_model.dart';

class TemplateRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _collection = 'drawing_templates';

  /// Ambil semua template aktif untuk kategori + level tertentu
  Future<List<DrawingTemplateModel>> getTemplates({
    required String kategori,
    required int level,
  }) async {
    try {
      final snapshot = await _db
          .collection(_collection)
          .where('kategori', isEqualTo: kategori)
          .where('level', isEqualTo: level)
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => DrawingTemplateModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      // Kembalikan list kosong jika belum ada template (admin belum upload)
      return [];
    }
  }

  /// Ambil template berdasarkan ID
  Future<DrawingTemplateModel?> getTemplateById(String id) async {
    try {
      final doc = await _db.collection(_collection).doc(id).get();
      if (!doc.exists) return null;
      return DrawingTemplateModel.fromFirestore(doc);
    } catch (e) {
      return null;
    }
  }
}
