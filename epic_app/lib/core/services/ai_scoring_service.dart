// AI Scoring Service — Gemini API Real Scoring
// Menggantikan mock scoring dengan Gemini Generative Language API.
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:epic_app/core/services/gemini_token_service.dart';
import 'package:epic_app/data/models/scoring_instrument_model.dart';
import 'package:epic_app/data/models/artwork_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui' as ui;

/// Exception untuk menandakan limit token Gemini habis (Error 429).
class QuotaExhaustedException implements Exception {
  final String message;
  QuotaExhaustedException([this.message = 'Limit penggunaan AI habis (429).']);

  @override
  String toString() => message;
}

/// Hasil penilaian dari AI.
class AIScoringResult {
  final int skor;
  final String grade;
  final String feedback;
  final Map<String, dynamic> detailPenilaian;
  final String modelUsed;    // Model AI yang digunakan

  AIScoringResult({
    required this.skor,
    required this.grade,
    required this.feedback,
    required this.detailPenilaian,
    required this.modelUsed,
  });
}

/// Service AI scoring menggunakan Gemini API per-user OAuth.
class AIScoringService extends GetxService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GeminiTokenService _tokenService = GeminiTokenService.instance;

  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  /// Evaluasi karya siswa menggunakan Gemini API.
  /// Jika quota habis (429), akan melempar QuotaExhaustedException.
  /// Retry otomatis 2x untuk network error (timeout, connection error).
  Future<AIScoringResult> evaluateArtwork({
    required Uint8List imageBytes,
    required String kategori,
    required int level,
    int? strokeCount,
    int? waktuPengerjaan,
  }) async {
    // Kompres gambar ke max 512x512, quality 70%
    final compressedImage = await _compressImage(imageBytes);

    // Ambil instrumen penilaian dari Firestore (atau fallback ke default)
    final instrument = await _getInstrument(kategori, level);

    try {
      // Coba scoring via Gemini dengan retry logic secara langsung di sisi client
      return await _retryEvaluate(
        compressedImage,
        instrument,
        waktuPengerjaan,
        maxRetries: 2,
      );
    } catch (e) {
      debugPrint('⚠️ Client-side scoring failed: $e. Falling back to Cloud Function...');
      // Fallback ke Cloud Function yang memiliki akses ke Server API Key baru
      return await _scoreWithCloudFunction(
        compressedImage,
        instrument,
        waktuPengerjaan,
      );
    }
  }

  /// Retry dengan exponential backoff (1s, 2s, 4s).
  /// Throw QuotaExhaustedException atau error lainnya jika semua attempt gagal.
  Future<AIScoringResult> _retryEvaluate(
    Uint8List imageBytes,
    ScoringInstrumentModel instrument,
    int? waktuPengerjaan, {
    int maxRetries = 2,
  }) async {
    int attempt = 0;
    while (attempt <= maxRetries) {
      try {
        return await _scoreWithGemini(imageBytes, instrument, waktuPengerjaan);
      } on QuotaExhaustedException {
        // Quota error - jangan retry, rethrow langsung
        rethrow;
      } on TimeoutException {
        attempt++;
        if (attempt > maxRetries) {
          throw TimeoutException('AI tidak merespons setelah ${maxRetries + 1} kali coba.');
        }
        final delayMs = (1000 * (attempt)).toInt(); // 1s, 2s, 4s...
        debugPrint('⏰ Retry scoring attempt $attempt (delay ${delayMs}ms)');
        await Future.delayed(Duration(milliseconds: delayMs));
      } catch (e) {
        attempt++;
        if (attempt > maxRetries) {
          rethrow;
        }
        final delayMs = (1000 * attempt).toInt();
        debugPrint('⏰ Retry scoring attempt $attempt (delay ${delayMs}ms): $e');
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }
    throw Exception('Semua retry attempt gagal');
  }

  /// Scoring menggunakan Firebase Cloud Function evaluateArtwork.
  /// Bypasses direct Gemini client quota limitations by falling back to Server API Key on the backend.
  Future<AIScoringResult> _scoreWithCloudFunction(
    Uint8List imageBytes,
    ScoringInstrumentModel instrument,
    int? waktuPengerjaan,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Harap login terlebih dahulu.');
    }

    try {
      final base64Image = base64Encode(imageBytes);

      // Panggil Firebase Cloud Function menggunakan SDK Resmi
      final callable = FirebaseFunctions.instance
          .httpsCallable(
            'evaluateArtwork',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
          );

      final response = await callable.call({
        'imageBase64': base64Image,
        'kategori': instrument.kategori,
        'level': instrument.level,
        'waktuPengerjaan': waktuPengerjaan ?? 0,
      });

      final result = response.data;
      if (result == null || result['success'] != true) {
        throw Exception('Hasil penilaian kosong atau tidak valid.');
      }

      final skor = result['skor'] is int
          ? result['skor'] as int
          : int.tryParse(result['skor'].toString()) ?? 70;
      
      final grade = result['grade']?.toString() ?? _calculateGrade(skor);
      final feedback = result['feedback']?.toString() ?? 'Karya yang bagus!';
      final modelUsed = result['modelUsed']?.toString() ?? instrument.modelAI;

      return AIScoringResult(
        skor: skor.clamp(0, 100),
        grade: grade,
        feedback: feedback,
        detailPenilaian: {
          'modelUsed': modelUsed,
          'scoredAt': DateTime.now().toIso8601String(),
        },
        modelUsed: modelUsed,
      );
    } on FirebaseFunctionsException catch (e) {
      final message = e.message ?? e.toString();
      if (e.code == 'resource-exhausted' || message.contains('QUOTA_EXCEEDED') || message.contains('resource-exhausted')) {
        throw QuotaExhaustedException();
      }
      throw Exception('Error dari server penilaian: $message');
    } catch (e) {
      if (e is TimeoutException) {
        throw TimeoutException('Permintaan penilaian ke server timeout (>120s)');
      }
      if (e is QuotaExhaustedException) {
        rethrow;
      }
      throw Exception('Gagal menghubungi server penilaian: $e');
    }
  }


  /// Scoring menggunakan Gemini API.
  Future<AIScoringResult> _scoreWithGemini(
    Uint8List imageBytes,
    ScoringInstrumentModel instrument,
    int? waktuPengerjaan,
  ) async {
    // Ambil access token
    final accessToken = await _tokenService.getAccessToken();
    if (accessToken == null) {
      throw Exception('Gemini token tidak tersedia. User belum grant permission.');
    }

    // Build request
    final modelName = instrument.modelAI;
    final url = Uri.parse('$_baseUrl/$modelName:generateContent');

    final base64Image = base64Encode(imageBytes);
    final prompt = instrument.buildPrompt(waktuPengerjaan ?? 0);

    final requestBody = {
      'contents': [
        {
          'parts': [
            {'text': prompt},
            {
              'inlineData': {
                'mimeType': 'image/png',
                'data': base64Image,
              }
            },
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.3,
        'responseMimeType': 'application/json',
        'responseSchema': {
          'type': 'OBJECT',
          'properties': {
            'skor': {'type': 'INTEGER'},
            'grade': {'type': 'STRING'},
            'feedback': {'type': 'STRING'}
          },
          'required': ['skor', 'grade', 'feedback']
        }
      },
    };

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(requestBody),
    ).timeout(const Duration(seconds: 60), onTimeout: () {
      throw TimeoutException('Permintaan ke AI timeout (>60s)');
    });

    if (response.statusCode == 429) {
      throw QuotaExhaustedException();
    }

    if (response.statusCode != 200) {
      throw Exception(
          'Gemini API error ${response.statusCode}: ${response.body}');
    }

    // Parse response
    final responseJson = jsonDecode(response.body);
    final candidates = responseJson['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('Gemini tidak mengembalikan hasil.');
    }

    final content = candidates[0]['content'];
    final parts = content['parts'] as List?;
    if (parts == null || parts.isEmpty) {
      throw Exception('Gemini response kosong.');
    }

    final text = parts[0]['text']?.toString() ?? '';

    // Parse JSON dari respons Gemini
    return _parseGeminiResponse(text, instrument.modelAI);
  }

  /// Parse respons JSON dari Gemini.
  AIScoringResult _parseGeminiResponse(String text, String modelName) {
    try {
      // Coba parse JSON langsung
      Map<String, dynamic> json;
      
      // Bersihkan jika ada markdown code block
      String cleaned = text.trim();
      if (cleaned.startsWith('```json')) {
        cleaned = cleaned.substring(7);
      }
      if (cleaned.startsWith('```')) {
        cleaned = cleaned.substring(3);
      }
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3);
      }
      cleaned = cleaned.trim();

      json = jsonDecode(cleaned);

      final skor = (json['skor'] is int)
          ? json['skor'] as int
          : (json['skor'] is double)
              ? (json['skor'] as double).round()
              : 70;

      final grade = json['grade']?.toString() ?? _calculateGrade(skor);
      final feedback =
          json['feedback']?.toString() ?? 'Karya yang bagus! Terus berlatih!';

      return AIScoringResult(
        skor: skor.clamp(0, 100),
        grade: grade,
        feedback: feedback,
        detailPenilaian: {
          'ai_raw': json,
          'model': modelName,
          'timestamp': DateTime.now().toIso8601String(),
        },
        modelUsed: modelName,
      );
    } catch (e) {
      debugPrint('⚠️ Gagal parse Gemini response: $e\nText: $text');
      throw Exception('Gagal parse respons Gemini.');
    }
  }

  /// Ambil instrumen penilaian dari Firestore.
  /// Fallback ke default jika tidak ada di Firestore.
  Future<ScoringInstrumentModel> _getInstrument(
      String kategori, int level) async {
    try {
      final doc = await _db
          .collection('app_config')
          .doc('game_settings')
          .collection('instruments')
          .doc('${kategori}_$level')
          .get();

      if (doc.exists && doc.data() != null) {
        return ScoringInstrumentModel.fromJson(doc.data()!);
      }
    } catch (e) {
      debugPrint('⚠️ Error ambil instrumen dari Firestore: $e');
    }

    // Fallback ke default
    return ScoringInstrumentModel.getDefault(kategori, level);
  }

  /// Kompres gambar ke max 512x512px.
  Future<Uint8List> _compressImage(Uint8List imageBytes) async {
    try {
      final codec = await ui.instantiateImageCodec(
        imageBytes,
        targetWidth: 512,
        targetHeight: 512,
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData != null) {
        return byteData.buffer.asUint8List();
      }
    } catch (e) {
      debugPrint('⚠️ Gagal kompres gambar: $e');
    }

    // Fallback: return original
    return imageBytes;
  }

  /// Hitung grade dari skor.
  String _calculateGrade(int? skor) {
    return ArtworkModel.calculateGrade(skor);
  }
}
