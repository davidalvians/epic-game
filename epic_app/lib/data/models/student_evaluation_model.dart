import 'package:cloud_firestore/cloud_firestore.dart';

/// Respons jawaban per butir soal evaluasi penalaran
class QuestionResponseItem {
  final int questionIndex;
  final String questionText;
  final String? audioUrl;
  final String transcript;
  final String manualText;

  const QuestionResponseItem({
    required this.questionIndex,
    required this.questionText,
    this.audioUrl,
    this.transcript = '',
    this.manualText = '',
  });

  /// Jawaban gabungan (prioritas manualText jika ada, atau transcript suara)
  String get combinedAnswer {
    if (manualText.trim().isNotEmpty && transcript.trim().isNotEmpty) {
      if (manualText.trim() == transcript.trim()) return manualText.trim();
      return '$manualText (Suara: "$transcript")';
    }
    if (manualText.trim().isNotEmpty) return manualText;
    return transcript;
  }

  factory QuestionResponseItem.fromMap(Map<String, dynamic> map) {
    return QuestionResponseItem(
      questionIndex: (map['questionIndex'] as num?)?.toInt() ?? 0,
      questionText: map['questionText']?.toString() ?? '',
      audioUrl: map['audioUrl']?.toString(),
      transcript: map['transcript']?.toString() ?? '',
      manualText: map['manualText']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'questionIndex': questionIndex,
      'questionText': questionText,
      'audioUrl': audioUrl,
      'transcript': transcript,
      'manualText': manualText,
    };
  }
}

/// Emotikon perasaan dan catatan afektif siswa
class StudentEmotionItem {
  final String type; // 'bangga', 'senang', 'mikir_keras', 'pantang_menyerah'
  final String icon; // 🤩, 😄, 🤔, 💪
  final String
      label; // Bangga Banget!, Senang Sekali, Mikir Keras, Pantang Menyerah
  final String note;

  const StudentEmotionItem({
    required this.type,
    required this.icon,
    required this.label,
    this.note = '',
  });

  factory StudentEmotionItem.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const StudentEmotionItem(
        type: 'senang',
        icon: '😄',
        label: 'Senang Sekali',
        note: '',
      );
    }
    return StudentEmotionItem(
      type: map['type']?.toString() ?? 'senang',
      icon: map['icon']?.toString() ?? '😄',
      label: map['label']?.toString() ?? 'Senang Sekali',
      note: map['note']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'icon': icon,
      'label': label,
      'note': note,
    };
  }
}

/// Model keseluruhan respons refleksi penalaran matematis siswa per level
class StudentEvaluationModel {
  final String id; // format: {studentId}_{categoryId}_{levelId}
  final String studentId;
  final String studentName;
  final String sekolah;
  final String kelas;
  final List<String> kelasIds;
  final String avatarGender; // 'laki-laki' atau 'perempuan'
  final String categoryId;
  final int levelId;
  final DateTime submittedAt;
  final StudentEmotionItem emotion;
  final List<QuestionResponseItem> responses;

  const StudentEvaluationModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.sekolah,
    required this.kelas,
    this.kelasIds = const [],
    this.avatarGender = 'laki-laki',
    required this.categoryId,
    required this.levelId,
    required this.submittedAt,
    required this.emotion,
    required this.responses,
  });

  factory StudentEvaluationModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return StudentEvaluationModel.fromMap(data, docId: doc.id);
  }

  factory StudentEvaluationModel.fromMap(
    Map<String, dynamic> map, {
    String? docId,
  }) {
    DateTime submitted = DateTime.now();
    if (map['submittedAt'] is Timestamp) {
      submitted = (map['submittedAt'] as Timestamp).toDate();
    } else if (map['submittedAt'] is String) {
      submitted = DateTime.tryParse(map['submittedAt']) ?? submitted;
    }

    final rawResponses = map['responses'];
    List<QuestionResponseItem> respList = [];
    if (rawResponses is List) {
      respList = rawResponses
          .whereType<Map<String, dynamic>>()
          .map((e) => QuestionResponseItem.fromMap(e))
          .toList();
    }

    return StudentEvaluationModel(
      id: docId ?? map['id']?.toString() ?? '',
      studentId: map['studentId']?.toString() ?? '',
      studentName: map['studentName']?.toString() ?? '',
      sekolah: map['sekolah']?.toString() ?? '',
      kelas: map['kelas']?.toString() ?? '',
      kelasIds: map['kelasIds'] is List
          ? (map['kelasIds'] as List)
              .map((item) => item.toString())
              .where((item) => item.isNotEmpty)
              .toList()
          : const [],
      avatarGender: map['avatarGender']?.toString() ?? 'laki-laki',
      categoryId: map['categoryId']?.toString() ?? '',
      levelId: (map['levelId'] as num?)?.toInt() ?? 1,
      submittedAt: submitted,
      emotion: StudentEmotionItem.fromMap(
        map['emotion'] is Map<String, dynamic>
            ? map['emotion'] as Map<String, dynamic>
            : null,
      ),
      responses: respList,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'studentId': studentId,
      'studentName': studentName,
      'sekolah': sekolah,
      'kelas': kelas,
      'kelasIds': kelasIds,
      'avatarGender': avatarGender,
      'categoryId': categoryId,
      'levelId': levelId,
      'submittedAt': FieldValue.serverTimestamp(),
      'emotion': emotion.toMap(),
      'responses': responses.map((r) => r.toMap()).toList(),
    };
  }
}
