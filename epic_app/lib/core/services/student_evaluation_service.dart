import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:epic_app/data/models/evaluation_config_model.dart';
import 'package:epic_app/data/models/student_evaluation_model.dart';

class StudentEvaluationService {
  static final StudentEvaluationService _instance =
      StudentEvaluationService._internal();
  factory StudentEvaluationService() => _instance;
  StudentEvaluationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Mengambil konfigurasi evaluasi untuk level tertentu
  Future<EvaluationConfigModel?> fetchConfig(
    String categoryId,
    int levelId,
  ) async {
    try {
      final docId = '${categoryId.toLowerCase()}_$levelId';
      final doc =
          await _firestore.collection('evaluation_configs').doc(docId).get();
      if (!doc.exists) {
        return null;
      }
      return EvaluationConfigModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('⚠️ [StudentEvaluationService] Gagal memuat config: $e');
      return null;
    }
  }

  /// Memeriksa apakah siswa sudah pernah mengisi evaluasi pada level ini
  Future<bool> hasStudentSubmitted(
    String studentId,
    String categoryId,
    int levelId,
  ) async {
    if (studentId.isEmpty) return false;
    try {
      final docId = '${studentId}_${categoryId.toLowerCase()}_$levelId';
      final doc =
          await _firestore.collection('student_evaluations').doc(docId).get();
      return doc.exists;
    } catch (e) {
      debugPrint('⚠️ [StudentEvaluationService] Cek status evaluasi gagal: $e');
      return false;
    }
  }

  /// Mengunggah berkas audio rekaman jawaban ke Firebase Storage
  Future<String?> uploadAudioAnswer({
    required String studentId,
    required String categoryId,
    required int levelId,
    required int questionIndex,
    required String filePath,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('⚠️ [uploadAudioAnswer] File tidak ditemukan: $filePath');
        return null;
      }

      final ext = filePath.split('.').last;
      final ref = _storage.ref().child(
            'evaluations/$studentId/${categoryId.toLowerCase()}_${levelId}_q$questionIndex.$ext',
          );

      final uploadTask = await ref.putFile(
        file,
        SettableMetadata(contentType: 'audio/$ext'),
      );

      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('⚠️ [uploadAudioAnswer] Gagal mengunggah audio: $e');
      return null;
    }
  }

  /// Mentranskripsi file audio (.m4a) menjadi teks bahasa Indonesia menggunakan AI Gemini
  Future<String> transcribeAudioFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('⚠️ [transcribeAudioFile] File audio tidak ada: $filePath');
        return '';
      }
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        debugPrint('⚠️ [transcribeAudioFile] File audio kosong (0 bytes)');
        return '';
      }

      final base64Audio = base64Encode(bytes);

      // Jalur 1 (Utama): Direct Gemini REST API (Cepat ~1.5 detik, tanpa latensi backend)
      try {
        const apiKey = 'AIzaSyDLn7opTUt9Scim3UZf29_ITOYlD0Y4fT4';
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey',
        );
        final res = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {
                    'text':
                        'Dengarkan rekaman suara anak berikut. Tuliskan kata-kata yang diucapkan secara persis ke dalam teks bahasa Indonesia. JANGAN menambahkan kata-kata yang tidak diucapkan. Jika tidak ada suara manusia atau hanya desis/hening, balas dengan string kosong. Jangan ada tanda kutip atau penjelasan.',
                  },
                  {
                    'inlineData': {
                      'mimeType': 'audio/mp4',
                      'data': base64Audio,
                    }
                  }
                ]
              }
            ]
          }),
        ).timeout(const Duration(seconds: 25));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final candidates = data['candidates'] as List?;
          if (candidates != null && candidates.isNotEmpty) {
            final parts = candidates[0]['content']?['parts'] as List?;
            if (parts != null && parts.isNotEmpty) {
              final text = (parts[0]['text'] ?? '').toString().trim();
              if (text.isNotEmpty) {
                debugPrint('✅ [transcribeAudioFile] Direct Gemini API transkrip sukses: "$text"');
                return text;
              }
            }
          }
        }
      } catch (directErr) {
        debugPrint('⚠️ [transcribeAudioFile] Direct Gemini API error, mencoba Cloud Function: $directErr');
      }

      // Jalur 2 (Fallback): Panggil Firebase Cloud Function transcribeAudio
      try {
        final callable = FirebaseFunctions.instance.httpsCallable(
          'transcribeAudio',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 25)),
        );
        final response = await callable.call({
          'audioBase64': base64Audio,
          'mimeType': 'audio/mp4',
        });

        final result = response.data;
        if (result != null && result['success'] == true) {
          final text = (result['transcript'] ?? '').toString().trim();
          if (text.isNotEmpty) {
            debugPrint('✅ [transcribeAudioFile] Transkrip via Cloud Function berhasil: "$text"');
            return text;
          }
        }
      } catch (cfErr) {
        debugPrint('⚠️ [transcribeAudioFile] Cloud Function fallback error: $cfErr');
      }

      return '';
    } catch (e) {
      debugPrint('⚠️ [transcribeAudioFile] Gagal transkripsi audio: $e');
      return '';
    }
  }

  /// Menyimpan dokumen hasil evaluasi siswa ke Firestore
  Future<bool> saveEvaluation(StudentEvaluationModel evaluation) async {
    try {
      final docId =
          '${evaluation.studentId}_${evaluation.categoryId.toLowerCase()}_${evaluation.levelId}';
      await _firestore
          .collection('student_evaluations')
          .doc(docId)
          .set(evaluation.toMap(), SetOptions(merge: true));
      debugPrint('✅ [StudentEvaluationService] Respons evaluasi tersimpan ($docId)');
      return true;
    } catch (e) {
      debugPrint('❌ [StudentEvaluationService] Gagal menyimpan evaluasi: $e');
      return false;
    }
  }
}
