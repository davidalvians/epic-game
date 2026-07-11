import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:epic_app/data/models/game_model.dart';

/// Repository untuk mengelola daftar Game dari Firestore.
class GameRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _collection = 'games';

  /// Mendapatkan semua game yang aktif, diurutkan berdasarkan field urutan.
  Future<List<GameModel>> getGames() async {
    final snapshot = await _db
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .orderBy('urutan')
        .get();

    return snapshot.docs.map((doc) {
      return GameModel.fromJson({...doc.data(), 'id': doc.id});
    }).toList();
  }

  /// Mendapatkan game berdasarkan ID.
  Future<GameModel?> getGameById(String id) async {
    final doc = await _db.collection(_collection).doc(id).get();
    if (doc.exists && doc.data() != null) {
      return GameModel.fromJson({...doc.data()!, 'id': doc.id});
    }
    return null;
  }

  /// Stream real-time daftar game aktif.
  Stream<List<GameModel>> watchGames() {
    return _db
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .orderBy('urutan')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              return GameModel.fromJson({...doc.data(), 'id': doc.id});
            }).toList());
  }
}
