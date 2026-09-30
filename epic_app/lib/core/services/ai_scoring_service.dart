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
    Map<String, dynamic>? scoringMetadata,
  }) async {
    // Kompres gambar ke max 512x512, quality 70%
    final compressedImage = await _compressImage(imageBytes);

    // Ambil instrumen penilaian dari Firestore (atau fallback ke default)
    final instrument = await _getInstrument(kategori, level);

    try {
      // Coba scoring via Gemini dengan retry logic secara langsung di sisi client
      final result = await _retryEvaluate(
        compressedImage,
        instrument,
        waktuPengerjaan,
        scoringMetadata: scoringMetadata,
        maxRetries: 2,
      );
      return _applyObjectiveRules(result, instrument, scoringMetadata);
    } catch (e) {
      debugPrint('⚠️ Client-side scoring failed: $e. Falling back to Cloud Function...');
      // Fallback ke Cloud Function yang memiliki akses ke Server API Key baru
      final result = await _scoreWithCloudFunction(
        compressedImage,
        instrument,
        waktuPengerjaan,
        scoringMetadata,
      );
      return _applyObjectiveRules(result, instrument, scoringMetadata);
    }
  }

  AIScoringResult _applyObjectiveRules(
    AIScoringResult result,
    ScoringInstrumentModel instrument,
    Map<String, dynamic>? scoringMetadata,
  ) {
    if (result.detailPenilaian['objectiveRulesApplied'] == true) {
      return AIScoringResult(
        skor: result.skor,
        grade: _calculateGrade(result.skor),
        feedback: result.feedback,
        detailPenilaian: result.detailPenilaian,
        modelUsed: result.modelUsed,
      );
    }
    if (instrument.kategori.toLowerCase() != 'anyaman' ||
        instrument.level < 1 ||
        instrument.level > 4 ||
        scoringMetadata == null) {
      return AIScoringResult(
        skor: result.skor,
        grade: _calculateGrade(result.skor),
        feedback: result.feedback,
        detailPenilaian: result.detailPenilaian,
        modelUsed: result.modelUsed,
      );
    }

    final uniqueColorCount =
        (scoringMetadata['uniqueColorCount'] as num?)?.toInt();
    final fillPercentage =
        (scoringMetadata['fillPercentage'] as num?)?.toDouble();
    final objectiveScores = <int>[
      ((scoringMetadata['objectivePatternScore'] as num?) ?? 0)
          .round()
          .clamp(0, 100),
      ((scoringMetadata['objectiveCreativityScore'] as num?) ?? 0)
          .round()
          .clamp(0, 100),
      ((scoringMetadata['objectiveCompletenessScore'] as num?) ?? 0)
          .round()
          .clamp(0, 100),
    ];
    final rawCriteriaScores = result.detailPenilaian['criteriaScores'];
    final aiCriteriaScores = <int>[
      for (int index = 0; index < 3; index++)
        rawCriteriaScores is List &&
                index < rawCriteriaScores.length &&
                rawCriteriaScores[index] is num
            ? (rawCriteriaScores[index] as num).round().clamp(0, 100)
            : result.skor,
    ];
    final hybridCriteriaScores = <int>[
      for (int index = 0; index < 3; index++)
        (objectiveScores[index] * 0.75 + aiCriteriaScores[index] * 0.25)
            .round()
            .clamp(0, 100),
    ];
    final fallbackWeights = instrument.level == 1
        ? const <int>[40, 30, 30]
        : const <int>[35, 40, 25];
    final weights = <int>[
      for (int index = 0; index < 3; index++)
        index < instrument.criteria.length
            ? instrument.criteria[index].weight
            : fallbackWeights[index],
    ];
    final totalWeight = weights.fold<int>(0, (total, weight) => total + weight);
    var adjustedScore = totalWeight <= 0
        ? 0
        : (List.generate(
                    3,
                    (index) => hybridCriteriaScores[index] * weights[index],
                  ).fold<int>(0, (total, value) => total + value) /
                totalWeight)
            .round();
    final objectiveNotes = <String>[];

    if (uniqueColorCount != null && uniqueColorCount <= 1) {
      objectiveNotes.add(
        'Komposisi masih menggunakan satu warna sehingga variasi dan kreativitas warnanya belum terlihat kuat.',
      );
    }

    if (fillPercentage != null) {
      if (fillPercentage <= 0) {
        adjustedScore = 0;
        objectiveNotes.add('Bidang anyaman belum diwarnai.');
      } else if (fillPercentage < 0.10) {
        adjustedScore = adjustedScore.clamp(0, 15).toInt();
        objectiveNotes.add('Bilah yang diwarnai masih sangat sedikit.');
      } else if (fillPercentage < 0.25) {
        adjustedScore = adjustedScore.clamp(0, 30).toInt();
        objectiveNotes.add('Bilah yang diwarnai masih kurang dari seperempat pola.');
      } else if (fillPercentage < 0.50) {
        adjustedScore = adjustedScore.clamp(0, 50).toInt();
        objectiveNotes.add('Bilah yang diwarnai belum mencapai setengah pola.');
      } else if (fillPercentage < 0.75) {
        adjustedScore = adjustedScore.clamp(0, 70).toInt();
        objectiveNotes.add('Pewarnaan pola belum cukup lengkap.');
      }
    }

    return AIScoringResult(
      skor: adjustedScore,
      grade: _calculateGrade(adjustedScore),
      feedback: objectiveNotes.isEmpty
          ? result.feedback
          : '${result.feedback} ${objectiveNotes.join(' ')}',
      detailPenilaian: {
        ...result.detailPenilaian,
        'objectiveRulesApplied': true,
        'scoringVersion': scoringMetadata['scoringVersion'],
        'scoreBeforeObjectiveRules': result.skor,
        'aiCriteriaScores': aiCriteriaScores,
        'objectiveCriteriaScores': objectiveScores,
        'hybridCriteriaScores': hybridCriteriaScores,
        'criteriaWeights': weights,
        'uniqueColorCount': uniqueColorCount,
        'fillPercentage': fillPercentage,
        'dominantColorRatio': scoringMetadata['dominantColorRatio'],
        'colorBalance': scoringMetadata['colorBalance'],
        'colorRichness': scoringMetadata['colorRichness'],
        'patternConsistency': scoringMetadata['patternConsistency'],
        'transitionRatio': scoringMetadata['transitionRatio'],
      },
      modelUsed: result.modelUsed,
    );
  }

  /// Retry dengan exponential backoff (1s, 2s, 4s).
  /// Throw QuotaExhaustedException atau error lainnya jika semua attempt gagal.
  Future<AIScoringResult> _retryEvaluate(
    Uint8List imageBytes,
    ScoringInstrumentModel instrument,
    int? waktuPengerjaan, {
    Map<String, dynamic>? scoringMetadata,
    int maxRetries = 2,
  }) async {
    int attempt = 0;
    while (attempt <= maxRetries) {
      try {
        return await _scoreWithGemini(
          imageBytes,
          instrument,
          waktuPengerjaan,
          scoringMetadata,
        );
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
    Map<String, dynamic>? scoringMetadata,
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
        if (scoringMetadata != null) 'scoringMetadata': scoringMetadata,
      });

      final result = response.data;
      if (result == null || result['success'] != true) {
        throw Exception('Hasil penilaian kosong atau tidak valid.');
      }

      final skor = result['skor'] is num
          ? (result['skor'] as num).round()
          : int.tryParse(result['skor']?.toString() ?? '');
      if (skor == null) {
        throw Exception('Skor dari server tidak valid.');
      }
      
      final grade = _calculateGrade(skor);
      final feedback = result['feedback']?.toString() ?? 'Karya yang bagus!';
      final modelUsed = result['modelUsed']?.toString() ?? instrument.modelAI;

      return AIScoringResult(
        skor: skor.clamp(0, 100),
        grade: grade,
        feedback: feedback,
        detailPenilaian: {
          if (result['detailPenilaian'] is Map)
            ...Map<String, dynamic>.from(result['detailPenilaian'] as Map),
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
    Map<String, dynamic>? scoringMetadata,
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
    final prompt = instrument.buildPrompt(
      waktuPengerjaan ?? 0,
      scoringMetadata: scoringMetadata,
    );

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
            'nilaiKriteria': {
              'type': 'ARRAY',
              'items': {'type': 'INTEGER'},
            },
            'feedback': {'type': 'STRING'}
          },
          'required': ['skor', 'grade', 'nilaiKriteria', 'feedback']
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
    return _parseGeminiResponse(text, instrument.modelAI, instrument);
  }

  /// Parse respons JSON dari Gemini.
  AIScoringResult _parseGeminiResponse(
    String text,
    String modelName,
    ScoringInstrumentModel instrument,
  ) {
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

      final skor = json['skor'] is num
          ? (json['skor'] as num).round()
          : int.tryParse(json['skor']?.toString() ?? '');
      if (skor == null) {
        throw const FormatException('Respons AI tidak memiliki skor yang valid.');
      }

      final criteriaScores = json['nilaiKriteria'] is List
          ? (json['nilaiKriteria'] as List)
              .whereType<num>()
              .map((score) => score.round().clamp(0, 100))
              .toList()
          : <int>[];
      final grade = _calculateGrade(skor);
      final feedback =
          json['feedback']?.toString() ?? 'Karya yang bagus! Terus berlatih!';

      return AIScoringResult(
        skor: skor.clamp(0, 100),
        grade: grade,
        feedback: feedback,
        detailPenilaian: {
          'ai_raw': json,
          'criteriaScores': criteriaScores,
          'criteriaWeights': instrument.criteria
              .map((criterion) => criterion.weight)
              .toList(),
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
        final loadedInstrument = ScoringInstrumentModel.fromJson({
          ...doc.data()!,
          'kategori': kategori,
          'level': level,
        });
        if (_usesLegacyAnyamanScoringValues(loadedInstrument)) {
          return ScoringInstrumentModel.getDefault(kategori, level);
        }
        return loadedInstrument;
      }
    } catch (e) {
      debugPrint('⚠️ Error ambil instrumen dari Firestore: $e');
    }

    // Fallback ke default
    return ScoringInstrumentModel.getDefault(kategori, level);
  }

  bool _usesLegacyAnyamanScoringValues(ScoringInstrumentModel instrument) {
    if (instrument.kategori.toLowerCase() != 'anyaman' ||
        instrument.level < 1 ||
        instrument.level > 4) {
      return false;
    }
    final normalized = [
      instrument.konteksBudaya,
      instrument.materiMatematika,
      instrument.systemInstruction,
      ...instrument.criteria.map((criterion) => criterion.name),
    ].join(' ').toLowerCase();
    return normalized.contains('grid 12x12') ||
        normalized.contains('grid 14x14') ||
        normalized.contains('minimal 4 warna') ||
        normalized.contains('minimal menggunakan 4 warna') ||
        normalized.contains('lebih dari 3 warna') ||
        normalized.contains('anyaman bebas') ||
        normalized.contains('asisten simetri') ||
        normalized.contains('nilai akhir maksimal 55') ||
        normalized.contains('skor 10-30 pada kualitas pola');
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
