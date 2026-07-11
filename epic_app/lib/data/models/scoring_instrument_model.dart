

/// Model criteria penilaian individual
class ScoringCriteria {
  final String name;
  final int weight;

  const ScoringCriteria({required this.name, required this.weight});

  factory ScoringCriteria.fromJson(Map<String, dynamic> json) {
    return ScoringCriteria(
      name: json['name']?.toString() ?? '',
      weight: json['weight'] is int ? json['weight'] : int.tryParse(json['weight']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'weight': weight,
    };
  }
}

/// Model instrumen penilaian AI per kategori dan level.
/// Disimpan di Firestore: app_config/game_settings/instruments/{kategori_level}
class ScoringInstrumentModel {
  final String id;
  final String kategori;        // 'batik' | 'anyaman'
  final int level;              // 1-4
  final String konteksBudaya;   // Deskripsi konteks budaya
  final String materiMatematika; // Materi matematika terkait
  final List<ScoringCriteria> criteria; // Kriteria penilaian dinamis
  final String modelAI;         // 'gemini-2.5-flash-lite' atau 'gemini-2.5-flash'
  final String systemInstruction; // Prompt/Instruction dasar dari Admin Panel

  ScoringInstrumentModel({
    this.id = '',
    required this.kategori,
    required this.level,
    required this.konteksBudaya,
    required this.materiMatematika,
    String? kriteria1,
    String? kriteria2,
    String? kriteria3,
    int bobot1 = 40,
    int bobot2 = 30,
    int bobot3 = 30,
    List<ScoringCriteria>? criteria,
    this.modelAI = 'gemini-2.5-flash-lite',
    this.systemInstruction = '',
  }) : criteria = criteria ?? [
          if (kriteria1 != null && kriteria1.isNotEmpty) ScoringCriteria(name: kriteria1, weight: bobot1),
          if (kriteria2 != null && kriteria2.isNotEmpty) ScoringCriteria(name: kriteria2, weight: bobot2),
          if (kriteria3 != null && kriteria3.isNotEmpty) ScoringCriteria(name: kriteria3, weight: bobot3),
        ];

  // Getters for compatibility
  String get kriteria1 => criteria.isNotEmpty ? criteria[0].name : '';
  String get kriteria2 => criteria.length > 1 ? criteria[1].name : '';
  String get kriteria3 => criteria.length > 2 ? criteria[2].name : '';
  int get bobot1 => criteria.isNotEmpty ? criteria[0].weight : 40;
  int get bobot2 => criteria.length > 1 ? criteria[1].weight : 30;
  int get bobot3 => criteria.length > 2 ? criteria[2].weight : 30;

  /// Validasi total bobot harus 100.
  bool get isValidBobot {
    if (criteria.isEmpty) return false;
    return criteria.fold(0, (sum, c) => sum + c.weight) == 100;
  }

  /// Build prompt AI lengkap dari instrumen ini.
  /// Prompt dirancang sangat ketat agar AI memberikan penilaian OBJEKTIF,
  /// tidak selalu memuji, dan memberikan skor rendah untuk karya yang memang jelek.
  String buildPrompt(int waktuPengerjaan) {
    final StringBuffer criteriaBuffer = StringBuffer();
    for (int i = 0; i < criteria.length; i++) {
      criteriaBuffer.writeln('${i + 1}. ${criteria[i].name} (Bobot: ${criteria[i].weight}%)');
    }

    final instructions = systemInstruction.isNotEmpty ? systemInstruction : konteksBudaya;

    return '''
Anda adalah juri kurator seni etnomatematika Madura yang profesional, jujur, namun mendidik dan komunikatif kepada anak SD (menyapa dengan panggilan "kamu").

WAKTU PENGERJAAN: $waktuPengerjaan detik. (Beri toleransi sewajarnya sesuai waktu pengerjaan).

PROMPT/INSTRUKSI SISTEM:
$instructions

MATERI MATEMATIKA:
$materiMatematika

KRITERIA PENILAIAN:
$criteriaBuffer

INSTRUKSI PENILAIAN YANG WAJIB DIIKUTI SECARA KETAT:
1. Analisis gambar yang diberikan secara SANGAT SEKSAMA dan OBJEKTIF.
2. JANGAN selalu memuji dan JANGAN mengatakan "karyamu bagus/sempurna" jika nilai akhir di bawah 80.
3. Panduan skor berdasarkan kualitas karya (WAJIB diikuti):
   - Gambar KOSONG / putih polos / hampir tidak ada karya: skor 0-5.
   - Karya SANGAT JELEK (asal-asalan, sembarangan, tidak ada usaha nyata): skor 6-25.
   - Karya BURUK (ada usaha tapi banyak kesalahan konsep besar): skor 26-40.
   - Karya CUKUP (ada usaha, beberapa kesalahan konsep, kurang rapi): skor 41-60.
   - Karya BAIK (konsep benar sebagian besar, cukup rapi): skor 61-79.
   - Karya SANGAT BAIK (konsep benar, rapi, kreatif): skor 80-89.
   - Karya LUAR BIASA/SEMPURNA (jarang sekali): skor 90-100.
4. Jika konsep matematika SALAH (warna tidak mengikuti aturan, pola tidak konsisten, simetri rusak): WAJIB berikan nilai sangat rendah (1-15) pada kriteria kepatuhan konsep tersebut.
5. Jangan gunakan sistem poin minus. Hanya nilai rentang 0-100 per kriteria.
6. Hitung total skor akhir (0-100) berdasarkan bobot kriteria di atas secara matematis.
7. Tentukan grade: S (90-100), A (80-89), B (70-79), C (60-69), D (50-59), E (0-49).
8. Feedback harus memuat 3 bagian dalam 2-3 kalimat yang JUJUR dan membangun:
   a. Apresiasi: Bagian goresan atau warna yang sudah baik (jika ada). Jika tidak ada, akui dengan jujur.
   b. Koreksi Jujur: Sebutkan kesalahan konsep atau ketidakrapian yang spesifik dan nyata.
   c. Saran Perbaikan: Langkah konkret yang bisa dilakukan untuk meningkatkan karya.

PENTING: Berikan respons dalam format JSON berikut SAJA:
{
  "skor": <skor_total_bulat_0_100>,
  "grade": "<S/A/B/C/D/E>",
  "feedback": "<Teks feedback gabungan apresiasi, koreksi, dan saran>"
}

Hanya berikan JSON, tanpa teks atau format markdown tambahan lainnya.
''';
  }

  factory ScoringInstrumentModel.fromJson(Map<String, dynamic> json) {
    List<ScoringCriteria>? parsedCriteria;
    if (json['criteria'] != null && json['criteria'] is List) {
      final list = json['criteria'] as List;
      parsedCriteria = list.map((item) => ScoringCriteria.fromJson(Map<String, dynamic>.from(item))).toList();
    }

    return ScoringInstrumentModel(
      id: json['id']?.toString() ?? '',
      kategori: json['kategori']?.toString() ?? '',
      level: json['level'] is int ? json['level'] : int.tryParse(json['level']?.toString() ?? '1') ?? 1,
      konteksBudaya: json['konteksBudaya']?.toString() ?? '',
      materiMatematika: json['materiMatematika']?.toString() ?? '',
      kriteria1: json['kriteria1']?.toString(),
      kriteria2: json['kriteria2']?.toString(),
      kriteria3: json['kriteria3']?.toString(),
      bobot1: json['bobot1'] is int ? json['bobot1'] : 40,
      bobot2: json['bobot2'] is int ? json['bobot2'] : 30,
      bobot3: json['bobot3'] is int ? json['bobot3'] : 30,
      criteria: parsedCriteria,
      modelAI: json['modelAI']?.toString() ?? 'gemini-2.5-flash-lite',
      systemInstruction: json['systemInstruction']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kategori': kategori,
      'level': level,
      'konteksBudaya': konteksBudaya,
      'materiMatematika': materiMatematika,
      'kriteria1': kriteria1,
      'kriteria2': kriteria2,
      'kriteria3': kriteria3,
      'bobot1': bobot1,
      'bobot2': bobot2,
      'bobot3': bobot3,
      'criteria': criteria.map((c) => c.toJson()).toList(),
      'modelAI': modelAI,
      'systemInstruction': systemInstruction,
    };
  }

  /// Instrumen default per kategori dan level (fallback jika Firestore kosong).
  static ScoringInstrumentModel getDefault(String kategori, int level) {
    switch ('${kategori}_$level') {
      case 'batik_1':
        return ScoringInstrumentModel(
          kategori: kategori,
          level: level,
          konteksBudaya: 'Batik Madura memiliki motif khas dengan pola geometris berulang. Level ini mengajarkan pola garis berulang.',
          materiMatematika: 'Pola bilangan, pengulangan, dan barisan sederhana.',
          kriteria1: 'Ketepatan pola pengulangan (garis teratur, berulang dengan ritme konsisten)',
          kriteria2: 'Penggunaan warna (minimal 2 warna, kontras, sesuai estetika Madura)',
          kriteria3: 'Kreativitas dan kerapihan (variasi dalam pola, garis bersih)',
        );
      case 'batik_2':
        return ScoringInstrumentModel(
          kategori: kategori,
          level: level,
          konteksBudaya: 'Batik Madura memiliki sifat simetri cermin pada banyak motifnya. Level ini mengajarkan simetri.',
          materiMatematika: 'Simetri cermin (refleksi), sumbu simetri, dan pencerminan bangun datar.',
          kriteria1: 'Ketepatan simetri cermin (sisi kanan = refleksi sisi kiri)',
          kriteria2: 'Kelengkapan motif (motif terisi penuh, tidak ada bagian kosong)',
          kriteria3: 'Estetika keseluruhan (warna harmonis, detail rapi)',
        );
      case 'batik_3':
        return ScoringInstrumentModel(
          kategori: kategori,
          level: level,
          konteksBudaya: 'Motif geometri khas Madura: gentongan, tanjung bumi, bangkalan. Level ini menggunakan bangun datar.',
          materiMatematika: 'Bangun datar: persegi, segitiga, lingkaran, belah ketupat. Minimal 3 jenis.',
          kriteria1: 'Penggunaan bangun datar (minimal 3 jenis, tepat bentuk)',
          kriteria2: 'Komposisi motif Madura (menyerupai motif tradisional)',
          kriteria3: 'Kerapihan dan kombinasi warna (warna khas Madura: merah, kuning, hijau)',
        );
      case 'batik_4':
        return ScoringInstrumentModel(
          kategori: kategori,
          level: level,
          konteksBudaya: 'Batik Madura asli — siswa bebas berkreasi dengan identitas budaya Madura.',
          materiMatematika: 'Gabungan semua konsep: pola, simetri, bangun datar, transformasi.',
          kriteria1: 'Orisinalitas dan kreativitas desain (ide unik, bukan copy)',
          kriteria2: 'Penerapan konsep matematika (minimal 2 konsep terlihat)',
        );
      case 'anyaman_1':
        return ScoringInstrumentModel(
          kategori: kategori,
          level: level,
          konteksBudaya: 'Anyaman tradisional Madura - Belajar menyusun kombinasi warna dasar.',
          materiMatematika: 'Pengenalan pola warna. Warnai grid 8x8 secara bebas menggunakan minimal 2 warna berbeda untuk membentuk motif anyaman.',
          kriteria1: 'Penggunaan warna (minimal menggunakan 2 warna berbeda pada grid)',
          kriteria2: 'Kreativitas gambar (keindahan motif anyaman yang dibentuk)',
          kriteria3: 'Kerapihan pengisian grid',
        );
      case 'anyaman_2':
        return ScoringInstrumentModel(
          kategori: kategori,
          level: level,
          konteksBudaya: 'Anyaman Madura - Desain ornamen dengan variasi warna yang lebih kaya.',
          materiMatematika: 'Kombinasi warna dan eksplorasi spasial. Warnai grid 10x10 secara bebas menggunakan minimal 3 warna berbeda.',
          kriteria1: 'Penggunaan warna (minimal menggunakan 3 warna berbeda pada grid)',
          kriteria2: 'Kreativitas desain (keunikan motif atau bentuk anyaman yang dibuat)',
          kriteria3: 'Kerapihan penataan warna keseluruhan',
        );
      case 'anyaman_3':
        return ScoringInstrumentModel(
          kategori: kategori,
          level: level,
          konteksBudaya: 'Anyaman tradisional Madura dengan anyaman multi-warna yang kompleks.',
          materiMatematika: 'Eksplorasi geometri dan warna. Warnai grid 12x12 secara bebas menggunakan minimal 4 warna berbeda.',
          kriteria1: 'Penggunaan warna (minimal menggunakan 4 warna berbeda pada grid)',
          kriteria2: 'Keindahan komposisi warna (harmonisasi gradasi warna)',
          kriteria3: 'Kerapihan dan detail motif yang dibentuk',
        );
      case 'anyaman_4':
        return ScoringInstrumentModel(
          kategori: kategori,
          level: level,
          konteksBudaya: 'Anyaman bebas Madura - Tingkat mahir dengan kreativitas tanpa batas.',
          materiMatematika: 'Desain etnomatematika tingkat lanjut. Warnai grid 14x14 menggunakan multi-warna (lebih dari 3 warna berbeda).',
          kriteria1: 'Penggunaan warna (menggunakan lebih dari 3 warna berbeda pada grid)',
          kriteria2: 'Orisinalitas desain (motif ornamen anyaman khas Madura)',
          kriteria3: 'Kerapihan dan keindahan artistik keseluruhan',
        );
      case 'keris_1':
        return ScoringInstrumentModel(
          kategori: kategori,
          level: level,
          konteksBudaya: 'Gagang keris Madura memiliki ukiran khas yang mencerminkan keberanian dan ketangguhan budaya Madura.',
          materiMatematika: 'Geometri dasar: garis lurus, garis lengkung, dan pola sederhana.',
          kriteria1: 'Kerapian dan ketepatan garis',
          bobot1: 40,
          kriteria2: 'Kreativitas penggunaan warna',
          bobot2: 30,
          kriteria3: 'Kelengkapan mengisi kanvas',
          bobot3: 30,
          modelAI: 'gemini-2.5-flash-lite',
        );
      case 'keris_2':
        return ScoringInstrumentModel(
          kategori: kategori,
          level: level,
          konteksBudaya: 'Bilah keris Madura biasanya memiliki luk (kelok) berjumlah ganjil yang melambangkan filosofi kehidupan dan kesempurnaan.',
          materiMatematika: 'Pola berulang, garis berkelok (luk), dan estetika keseimbangan.',
          kriteria1: 'Ketepatan luk bilah keris (ganjil/kelok berulang)',
          bobot1: 40,
          kriteria2: 'Kerapian hiasan pola berulang',
          bobot2: 30,
          kriteria3: 'Keharmonisan komposisi & estetika warna',
          bobot3: 30,
          modelAI: 'gemini-2.5-flash-lite',
        );
      case 'keris_3':
        return ScoringInstrumentModel(
          kategori: kategori,
          level: level,
          konteksBudaya: 'Warangka keris berfungsi sebagai pelindung dan lambang status sosial dengan ukiran geometris yang khas.',
          materiMatematika: 'Geometri & kombinasi minimal 3 jenis bangun datar berbeda.',
          kriteria1: 'Penggunaan bangun datar (minimal 3 jenis, tepat bentuk)',
          bobot1: 40,
          kriteria2: 'Kombinasi dan keselarasan bangun datar',
          bobot2: 30,
          kriteria3: 'Kerapian dan komposisi warna khas Madura',
          bobot3: 30,
          modelAI: 'gemini-2.5-flash',
        );
      case 'keris_4':
        return ScoringInstrumentModel(
          kategori: kategori,
          level: level,
          konteksBudaya: 'Keris Madura lengkap (gagang, bilah, warangka) mencerminkan mahakarya budaya Madura yang bernilai tinggi.',
          materiMatematika: 'Gabungan semua konsep matematika: pola, geometri, keselarasan proporsi.',
          kriteria1: 'Kelengkapan struktur keris (gagang, bilah, warangka)',
          bobot1: 40,
          kriteria2: 'Kreativitas & orisinalitas desain',
          bobot2: 30,
          kriteria3: 'Representasi budaya Madura (warna & motif)',
          bobot3: 30,
          modelAI: 'gemini-2.5-flash',
        );
      default:
        return ScoringInstrumentModel(
          kategori: kategori,
          level: level,
          konteksBudaya: 'Seni budaya Madura dan matematika.',
          materiMatematika: 'Konsep matematika dasar.',
          kriteria1: 'Ketepatan konsep',
          kriteria2: 'Kreativitas',
          kriteria3: 'Estetika',
        );
    }
  }
}
