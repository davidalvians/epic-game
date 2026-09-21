import 'package:cloud_firestore/cloud_firestore.dart';

class EvaluationEmotionOption {
  final String type;
  final String icon;
  final String label;

  const EvaluationEmotionOption({
    required this.type,
    required this.icon,
    required this.label,
  });

  factory EvaluationEmotionOption.fromMap(Map<String, dynamic> map) {
    return EvaluationEmotionOption(
      type: map['type']?.toString() ?? 'senang',
      icon: map['icon']?.toString() ?? '😄',
      label: map['label']?.toString() ?? 'Senang',
    );
  }

  Map<String, dynamic> toMap() => {
        'type': type,
        'icon': icon,
        'label': label,
      };
}

/// Model konfigurasi evaluasi penalaran matematis per level dari Admin Panel
class EvaluationConfigModel {
  static const defaultEmotionOptions = <EvaluationEmotionOption>[
    EvaluationEmotionOption(type: 'bangga', icon: '🤩', label: 'Bangga Banget!'),
    EvaluationEmotionOption(type: 'senang', icon: '😄', label: 'Senang Sekali'),
    EvaluationEmotionOption(type: 'mikir_keras', icon: '🤔', label: 'Mikir Keras'),
    EvaluationEmotionOption(type: 'pantang_menyerah', icon: '💪', label: 'Pantang Menyerah'),
  ];

  final String categoryId; // 'keris', 'batik', 'anyaman'
  final int levelId; // 1, 2, 3, 4
  final String status; // 'mandatory', 'optional', 'disabled'
  final List<String> questions;
  final String feelingPrompt;
  final List<EvaluationEmotionOption> emotionOptions;
  final bool enableTts;
  final DateTime? updatedAt;

  const EvaluationConfigModel({
    required this.categoryId,
    required this.levelId,
    this.status = 'disabled',
    this.questions = const [],
    this.feelingPrompt = 'Bagaimana perasaanmu selama membuat karya ini tadi?',
    this.emotionOptions = defaultEmotionOptions,
    this.enableTts = true,
    this.updatedAt,
  });

  bool get isMandatory => status == 'mandatory';
  bool get isOptional => status == 'optional';
  bool get isDisabled => status == 'disabled';

  /// Evaluasi hanya diminta jika status aktif (mandatory/optional) dan terdapat minimal 1 butir soal terisi
  bool get hasValidQuestions =>
      questions.isNotEmpty && questions.any((q) => q.trim().isNotEmpty);

  bool get shouldShowEvaluation => !isDisabled && hasValidQuestions;

  /// Daftar pertanyaan yang sudah dibersihkan dari string kosong
  List<String> get activeQuestions =>
      questions.where((q) => q.trim().isNotEmpty).toList();

  factory EvaluationConfigModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return EvaluationConfigModel.fromMap(data, docId: doc.id);
  }

  factory EvaluationConfigModel.fromMap(
    Map<String, dynamic> data, {
    String? docId,
  }) {
    String cat = data['categoryId']?.toString() ?? '';
    int lvl = (data['levelId'] as num?)?.toInt() ?? 1;

    if (cat.isEmpty && docId != null && docId.contains('_')) {
      final parts = docId.split('_');
      cat = parts[0];
      lvl = int.tryParse(parts[1]) ?? lvl;
    }

    final rawQuestions = data['questions'];
    List<String> qList = [];
    if (rawQuestions is List) {
      qList = rawQuestions.map((e) => e.toString().trim()).toList();
    }

    final rawEmotions = data['emotionOptions'];
    final emotionOptions = rawEmotions is List
        ? rawEmotions
            .whereType<Map>()
            .map((item) => EvaluationEmotionOption.fromMap(
                  Map<String, dynamic>.from(item),
                ))
            .where((item) => item.icon.trim().isNotEmpty && item.label.trim().isNotEmpty)
            .toList()
        : const <EvaluationEmotionOption>[];

    DateTime? updated;
    if (data['updatedAt'] is Timestamp) {
      updated = (data['updatedAt'] as Timestamp).toDate();
    } else if (data['updatedAt'] is String) {
      updated = DateTime.tryParse(data['updatedAt']);
    }

    return EvaluationConfigModel(
      categoryId: cat,
      levelId: lvl,
      status: data['status']?.toString() ?? 'disabled',
      questions: qList,
      feelingPrompt: data['feelingPrompt']?.toString() ??
          'Bagaimana perasaanmu selama membuat karya ini tadi?',
      emotionOptions:
          emotionOptions.isEmpty ? defaultEmotionOptions : emotionOptions,
      enableTts: data['enableTts'] != false,
      updatedAt: updated,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'categoryId': categoryId,
      'levelId': levelId,
      'status': status,
      'questions': questions,
      'feelingPrompt': feelingPrompt,
      'emotionOptions': emotionOptions.map((item) => item.toMap()).toList(),
      'enableTts': enableTts,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  EvaluationConfigModel copyWith({
    String? categoryId,
    int? levelId,
    String? status,
    List<String>? questions,
    String? feelingPrompt,
    List<EvaluationEmotionOption>? emotionOptions,
    bool? enableTts,
    DateTime? updatedAt,
  }) {
    return EvaluationConfigModel(
      categoryId: categoryId ?? this.categoryId,
      levelId: levelId ?? this.levelId,
      status: status ?? this.status,
      questions: questions ?? this.questions,
      feelingPrompt: feelingPrompt ?? this.feelingPrompt,
      emotionOptions: emotionOptions ?? this.emotionOptions,
      enableTts: enableTts ?? this.enableTts,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
