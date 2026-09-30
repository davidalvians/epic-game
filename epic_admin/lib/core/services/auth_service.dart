import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service autentikasi untuk Admin Panel.
///
/// CATATAN KEAMANAN:
/// - Semua debugPrint yang mengandung data user dibungkus dengan kDebugMode
///   agar tidak bocor ke production logs.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Stream perubahan status auth — dipakai GoRouter untuk redirect guard.
  Stream<User?> get userStream => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  // Sign in with Google Web (popup flow — cocok untuk Flutter Web)
  Future<UserCredential> signInWithGoogleWeb() async {
    final GoogleAuthProvider provider = GoogleAuthProvider();
    provider.addScope('email');
    provider.addScope('profile');
    final UserCredential userCredential = await _auth.signInWithPopup(provider);
    return userCredential;
  }

  // Sign in with Email and Password
  Future<UserCredential> signInWithEmailPassword(String email, String password) async {
    final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return userCredential;
  }

  /// Validasi apakah user yang login memiliki role admin yang aktif.
  ///
  /// Cek dilakukan dalam urutan:
  /// 1. Koleksi `admins` by UID
  /// 2. Koleksi `admins` by email (fallback untuk data admin lama)
  Future<bool> validateAdminRole(String uid) async {
    final User? user = _auth.currentUser;
    final String? email = user?.email;

    if (kDebugMode) {
      debugPrint('[AuthService] validateAdminRole untuk UID: $uid');
    }

    // 1. Cek koleksi 'admins' by UID. Jangan pernah mempercayai field role
    // pada profil users karena profil tersebut dikelola oleh aplikasi klien.
    try {
      final DocumentSnapshot adminDoc = await _db.collection('admins').doc(uid).get();
      if (adminDoc.exists) {
        final data = adminDoc.data() as Map<String, dynamic>?;
        if (data != null) {
          final String? role = data['role'];
          final bool? isActive = data['isActive'];
          if (role == 'admin' && isActive == true) {
            if (kDebugMode) debugPrint('[AuthService] ✅ Admin tervalidasi via koleksi admins (UID)');
            return true;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[AuthService] ⚠️ Error cek admins by UID: $e');
    }

    // 2. Fallback: cek koleksi 'admins' by email
    try {
      if (email != null && email.isNotEmpty) {
        final querySnap = await _db
            .collection('admins')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (querySnap.docs.isNotEmpty) {
          final data = querySnap.docs.first.data();
          final String? role = data['role'];
          final bool? isActive = data['isActive'];
          if (role == 'admin' && isActive == true) {
            if (kDebugMode) debugPrint('[AuthService] ✅ Admin tervalidasi via admins (email)');
            return true;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[AuthService] ⚠️ Error cek admins by email: $e');
    }

    if (kDebugMode) debugPrint('[AuthService] ❌ Bukan admin atau tidak aktif');
    return false;
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
