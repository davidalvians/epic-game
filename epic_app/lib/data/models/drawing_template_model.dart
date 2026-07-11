// Model untuk template/kerangka gambar yang diambil dari Firestore
// Dikelola oleh admin melalui Admin Panel
import 'package:cloud_firestore/cloud_firestore.dart';

class DrawingTemplateModel {
  final String id;
  final String nama;           // Nama template, contoh: "Gagang Keris Madura A"
  final String kategori;       // keris / batik / anyaman
  final int level;             // 1-4
  final String outlineUrl;     // URL PNG transparan di Firebase Storage
  final String thumbnailUrl;   // URL thumbnail kecil untuk preview
  final String deskripsi;      // Deskripsi singkat
  final bool isActive;         // Admin bisa nonaktifkan

  const DrawingTemplateModel({
    required this.id,
    required this.nama,
    required this.kategori,
    required this.level,
    required this.outlineUrl,
    required this.thumbnailUrl,
    this.deskripsi = '',
    this.isActive = true,
  });

  factory DrawingTemplateModel.fromJson(Map<String, dynamic> json) {
    return DrawingTemplateModel(
      id: json['id']?.toString() ?? '',
      nama: json['nama']?.toString() ?? 'Template',
      kategori: json['kategori']?.toString() ?? 'keris',
      level: json['level'] as int? ?? 1,
      outlineUrl: json['outlineUrl']?.toString() ?? '',
      thumbnailUrl: json['thumbnailUrl']?.toString() ?? '',
      deskripsi: json['deskripsi']?.toString() ?? '',
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  factory DrawingTemplateModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DrawingTemplateModel.fromJson({...data, 'id': doc.id});
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nama': nama,
      'kategori': kategori,
      'level': level,
      'outlineUrl': outlineUrl,
      'thumbnailUrl': thumbnailUrl,
      'deskripsi': deskripsi,
      'isActive': isActive,
    };
  }
}
