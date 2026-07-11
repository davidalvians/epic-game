// Service untuk upload/download Firebase Storage
import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:get/get.dart';

/// Service untuk upload dan hapus file di Firebase Storage.
class StorageService extends GetxService {

  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload file ke Firebase Storage dan kembalikan download URL.
  Future<String> uploadFile(String path, File file) async {
    final ref = _storage.ref().child(path);
    final uploadTask = await ref.putFile(file);
    final downloadUrl = await uploadTask.ref.getDownloadURL();
    return downloadUrl;
  }

  /// Upload data (byte) ke Firebase Storage (Mendukung Web).
  Future<String> uploadBytes(String path, Uint8List data) async {
    final ref = _storage.ref().child(path);
    // Tambahkan contentType agar Firebase Storage rules bisa validasi isImage()
    final metadata = SettableMetadata(contentType: 'image/png');
    final uploadTask = await ref.putData(data, metadata);
    final downloadUrl = await uploadTask.ref.getDownloadURL();
    return downloadUrl;
  }

  /// Hapus file dari Firebase Storage berdasarkan download URL.
  Future<void> deleteFile(String url) async {
    if (url.isEmpty) return;
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (e) {
      // Abaikan jika file tidak ditemukan
    }
  }
}
