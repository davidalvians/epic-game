// Repository untuk Auth menggunakan Firebase Authentication + Firestore
// EPIC v2: Google Sign-In only + QR Code + Kode 6 Digit
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:epic_app/data/models/user_model.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:epic_app/core/services/google_sign_in_client.dart';

/// Repository untuk Autentikasi menggunakan Firebase.
/// Hanya mendukung Google Sign-In, QR Code, dan Kode 6 Digit.
class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Koleksi Firestore
  static const String _usersCollection = 'users';
  static const String _usernamesCollection = 'usernames';
  static const String _guruVerifikasiCollection = 'guru_verifikasi';

  // HIGH-02 Fix: Pakai shared singleton agar sesi OAuth tidak konflik
  // dengan GeminiTokenService yang menggunakan instance yang sama.
  GoogleSignIn get _googleSignIn => googleSignInInstance;

  // ─── GOOGLE SIGN-IN ──────────────────────────────────────────────────────

  /// Login atau daftar dengan Google.
  /// Mengembalikan UserModel. Jika user baru, isProfileComplete = false.
  Future<UserModel> signInWithGoogle() async {
    try {
      debugPrint('🌐 Memulai Google Sign-In...');

      UserCredential userCredential;
      bool geminiGranted = true;

      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        provider.addScope('https://www.googleapis.com/auth/generative-language.retriever');
        userCredential = await _auth.signInWithPopup(provider);
      } else {
        // ROOT-FIX-2: Coba silent sign-in dulu (tidak tampilkan UI, gunakan Google token tersimpan)
        // Ini penting saat app di-kill dari Recent Apps:
        // _googleSignIn.currentUser akan null (in-memory cleared), tapi Google
        // menyimpan token di Android Credential Manager sehingga silent sign-in berhasil.
        GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();
        if (googleUser == null) {
          // Silent sign-in gagal — tampilkan account picker
          // Bersihkan state lama sebelum request sign-in baru
          await _googleSignIn.signOut();
          googleUser = await _googleSignIn.signIn();
        }
        if (googleUser == null) {
          throw Exception('Google Sign-In dibatalkan oleh user.');
        }

        // Gemini scope di-request melalui GoogleSignIn scopes.
        // Verifikasi aktual dilakukan saat pertama kali memanggil Gemini API.
        geminiGranted = true;

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        userCredential = await _auth.signInWithCredential(credential);
      }

      final uid = userCredential.user?.uid;
      if (uid == null) {
        throw Exception('Login Google gagal: UID tidak ditemukan.');
      }

      // Cek apakah user sudah ada di Firestore
      final doc = await _db.collection(_usersCollection).doc(uid).get();

      if (!doc.exists || doc.data() == null) {
        // User baru — buat profil dasar dengan isProfileComplete = false
        final now = DateTime.now();
        final newUser = UserModel(
          uid: uid,
          namaLengkap: userCredential.user?.displayName ?? '',
          namaPanggilan:
              (userCredential.user?.displayName ?? '').split(' ').first,
          email: userCredential.user?.email ?? '',
          avatarUrl: userCredential.user?.photoURL ?? '',
          role: 'murid',
          isProfileComplete: false,
          geminiPermission: geminiGranted,
          poin: 0,
          nyawa: UserModel.maxNyawa,
          nyawaLastReset: now,
          karakterAktif: 'epi_default',
          karakterDimiliki: const ['epi_default', 'ipeh_default'],
          createdAt: now,
          sekolah: '',
        );

        await _db.collection(_usersCollection).doc(uid).set(newUser.toJson());
        debugPrint('✅ User baru terdaftar via Google: ${newUser.email}');
        return newUser;
      }

      // User lama — ambil data dari Firestore
      final userModel =
          UserModel.fromJson({...doc.data()!, 'uid': uid});

      // Update avatar dari Google jika belum diatur
      if (userCredential.user?.photoURL != null &&
          userModel.avatarUrl.isEmpty) {
        await _db.collection(_usersCollection).doc(uid).update({
          'avatarUrl': userCredential.user!.photoURL,
        });
        return userModel.copyWith(
            avatarUrl: userCredential.user!.photoURL);
      }

      return userModel;
    } on FirebaseAuthException catch (e) {
      debugPrint(
          '❌ FirebaseAuthException saat Google Sign-In: code=${e.code}, msg=${e.message}');
      throw Exception(_parseAuthError(e.code));
    } catch (e) {
      debugPrint('❌ Error tak terduga saat Google Sign-In: $e');
      rethrow;
    }
  }

  // ─── USERNAME ────────────────────────────────────────────────────────────

  /// Cek apakah username tersedia (belum dipakai user lain).
  /// Dipakai hanya untuk real-time preview di form — bukan untuk reservasi.
  Future<bool> checkUsernameAvailable(String username) async {
    final doc =
        await _db.collection(_usernamesCollection).doc(username.toLowerCase()).get();
    return !doc.exists;
  }

  /// Reservasi username secara ATOMIK menggunakan Firestore Transaction.
  ///
  /// CRIT-03 Fix: Sebelumnya check + reserve dilakukan dalam 2 langkah terpisah
  /// (checkUsernameAvailable → reserveUsername), sehingga ada jeda di mana
  /// dua user bisa lolos validasi bersamaan dan mengklaim username yang sama.
  ///
  /// Sekarang check + write dilakukan dalam satu Transaction:
  /// - Jika dokumen sudah ada → transaction dibatalkan dengan Exception
  /// - Jika belum ada → tulis atomik, tidak ada race condition
  Future<void> _reserveUsernameAtomic(String username, String uid) async {
    final usernameRef = _db
        .collection(_usernamesCollection)
        .doc(username.toLowerCase());

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(usernameRef);
      if (snapshot.exists) {
        throw Exception('Username "$username" sudah dipakai. Pilih yang lain ya!');
      }
      transaction.set(usernameRef, {
        'uid': uid,
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });
    });
  }

  // ─── ONBOARDING / COMPLETE PROFILE ───────────────────────────────────────

  /// Lengkapi profil setelah Google Sign-In pertama kali.
  Future<UserModel> completeOnboarding({
    required String uid,
    required String namaLengkap,
    required String username,
    required String sekolah,
    required String role,
    String kelas = '',
    String provinsi = '',
    String kabupaten = '',
    String kecamatan = '',
    String? mataPelajaran,
    String? buktiMengajarUrl,
  }) async {
    // CRIT-03 Fix: Reservasi username secara atomik via Firestore Transaction.
    // Jika username sudah diambil user lain di saat yang bersamaan, exception
    // akan dilempar dan onboarding dibatalkan — tidak ada duplikat username.
    await _reserveUsernameAtomic(username, uid);

    // Update profil di Firestore
    final updates = <String, dynamic>{
      'namaLengkap': namaLengkap,
      'namaPanggilan': namaLengkap.split(' ').first,
      'username': username.toLowerCase(),
      'sekolah': sekolah,
      'role': role,
      'isProfileComplete': true,
      'kelas': kelas,
      'provinsi': provinsi,
      'kabupaten': kabupaten,
      'kecamatan': kecamatan,
    };

    if (mataPelajaran != null) {
      updates['mataPelajaran'] = mataPelajaran;
    }

    await _db.collection(_usersCollection).doc(uid).update(updates);

    // Jika guru, kirim permohonan verifikasi
    if (role == 'guru') {
      await _submitGuruVerifikasi(
        uid: uid,
        namaGuru: namaLengkap,
        sekolah: sekolah,
        buktiUrl: buktiMengajarUrl,
      );

      // Set status verifikasi ke pending
      await _db.collection(_usersCollection).doc(uid).update({
        'guruStatus': 'pending',
        if (buktiMengajarUrl != null) 'buktiUrl': buktiMengajarUrl,
      });
      updates['guruStatus'] = 'pending';
    }

    // Ambil data user yang sudah diupdate
    final doc = await _db.collection(_usersCollection).doc(uid).get();
    return UserModel.fromJson({...doc.data()!, 'uid': uid});
  }

  /// Submit permohonan verifikasi guru.
  Future<void> _submitGuruVerifikasi({
    required String uid,
    required String namaGuru,
    required String sekolah,
    String? buktiUrl,
  }) async {
    final requestId = _db.collection(_guruVerifikasiCollection).doc().id;
    await _db.collection(_guruVerifikasiCollection).doc(requestId).set({
      'requestId': requestId,
      'uid': uid,
      'namaGuru': namaGuru,
      'sekolah': sekolah,
      'buktiUrl': buktiUrl ?? '',
      'status': 'pending',
      'catatanAdmin': null,
      'createdAt': Timestamp.fromDate(DateTime.now()),
      'processedAt': null,
    });
    debugPrint('✅ Permohonan verifikasi guru dikirim: $requestId');
  }

  /// Memulihkan sesi Firebase secara otomatis (khusus Android Firebase bug di mana token hilang)
  /// menggunakan silent sign-in Google.
  Future<bool> restoreSessionIfPossible() async {
    try {
      if (_auth.currentUser != null) return true;

      debugPrint('🔄 Mencoba memulihkan sesi dengan Google Silent Sign-In...');
      GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();
      
      if (googleUser != null) {
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await _auth.signInWithCredential(credential);
        debugPrint('✅ Sesi Firebase berhasil dipulihkan secara otomatis.');
        return true;
      }
    } catch (e) {
      debugPrint('⚠️ Gagal memulihkan sesi secara otomatis: $e');
    }
    return false;
  }

  // ─── SESSION ─────────────────────────────────────────────────────────────

  /// Mengecek apakah user sudah login (pakai state Firebase).
  /// ROOT-FIX-2: Cache-first strategy — baca dari cache Firestore lokal dulu (instan),
  /// baru fetch dari server. Ini mencegah race condition antara splash screen
  /// timeout (7.5 detik) vs Firestore server response time (bisa >8 detik).
  Future<UserModel?> getCurrentUser() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;

    try {
      // ─── STEP 1: CACHE FIRST (zero latency, tidak butuh jaringan) ───────────
      // Firestore persistence diaktifkan di main.dart (100MB cache).
      // Jika user pernah login sebelumnya, dokumen pasti ada di cache.
      try {
        final cachedDoc = await _db
            .collection(_usersCollection)
            .doc(firebaseUser.uid)
            .get(const GetOptions(source: Source.cache));
        if (cachedDoc.exists && cachedDoc.data() != null) {
          debugPrint('💾 [getCurrentUser] Cache hit — user dimuat dari Firestore lokal (offline/fast path).');
          return UserModel.fromJson({...cachedDoc.data()!, 'uid': firebaseUser.uid});
        }
        debugPrint('ℹ️ [getCurrentUser] Cache kosong, mencoba server...');
      } catch (_) {
        // Cache tidak tersedia (fresh install / data dihapus), lanjut ke server
        debugPrint('ℹ️ [getCurrentUser] Cache tidak tersedia, lanjut ke server...');
      }

      // ─── STEP 2: SERVER (saat fresh install atau cache miss) ─────────────────
      DocumentSnapshot<Map<String, dynamic>> doc;
      try {
        doc = await _db
            .collection(_usersCollection)
            .doc(firebaseUser.uid)
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 10));
        debugPrint('📡 [getCurrentUser] Server hit — user dimuat dari Firestore server.');
      } catch (serverError) {
        // Server tidak dapat dijangkau (offline/lambat) dan tidak ada cache.
        // Kembalikan null — jangan logout! Firebase Auth token tetap valid.
        debugPrint('⚠️ [getCurrentUser] Server Firestore tidak dapat dijangkau: $serverError');
        return null;
      }

      // ─── STEP 3: RETRY untuk user baru (race condition saat Google Sign-In) ───
      if (!doc.exists) {
        DocumentSnapshot<Map<String, dynamic>> retryDoc = doc;
        int retryCount = 0;
        while (!retryDoc.exists && retryCount < 3) {
          retryCount++;
          debugPrint('⏳ Dokumen user belum ada, retry $retryCount/3...');
          await Future.delayed(const Duration(seconds: 1));
          retryDoc = await _db
              .collection(_usersCollection)
              .doc(firebaseUser.uid)
              .get();
        }
        doc = retryDoc;
      }

      if (!doc.exists || doc.data() == null) {
        debugPrint('⚠️ [getCurrentUser] Dokumen user tidak ada di Firestore (akun mungkin dihapus).');
        return null;
      }

      return UserModel.fromJson({...doc.data()!, 'uid': firebaseUser.uid});
    } catch (e) {
      debugPrint('⚠️ [getCurrentUser] Error: $e');
      return null;
    }
  }

  /// Memperbarui data profil user (nama, sekolah, domisili) di Firestore.
  Future<UserModel> updateProfile(UserModel user) async {
    await _db.collection(_usersCollection).doc(user.uid).update({
      'namaLengkap': user.namaLengkap,
      'namaPanggilan': user.namaPanggilan,
      'avatarUrl': user.avatarUrl,
      'sekolah': user.sekolah,
      'provinsi': user.provinsi,
      'kabupaten': user.kabupaten,
      'kecamatan': user.kecamatan,
    });

    // Sinkronisasikan nama baru ke koleksi kelas secara langsung (jika ada kelas miliknya)
    final String newName = user.namaLengkap.trim().isNotEmpty
        ? user.namaLengkap.trim()
        : (user.namaPanggilan.trim().isNotEmpty 
            ? user.namaPanggilan.trim() 
            : 'Guru');
            
    final classesQuery = await _db
        .collection('kelas')
        .where('guruUid', isEqualTo: user.uid)
        .get();
        
    if (classesQuery.docs.isNotEmpty) {
      final batch = _db.batch();
      for (final doc in classesQuery.docs) {
        batch.update(doc.reference, {'guruNama': newName});
      }
      await batch.commit();
      debugPrint('✅ Nama guru disinkronkan ke ${classesQuery.docs.length} kelas milik ${user.uid}');
    }

    debugPrint('✅ Profil user ${user.uid} berhasil diperbarui');
    return user;
  }

  /// Logout dari Firebase dan Google.
  Future<void> logout() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _auth.signOut();
    debugPrint('✅ User logout berhasil');
  }

  /// Mengonversi kode error Firebase ke pesan bahasa Indonesia.
  String _parseAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Akun tidak ditemukan. Silakan daftar dengan Google!';
      case 'email-already-in-use':
        return 'Email ini sudah terdaftar.';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan. Coba lagi beberapa saat!';
      case 'network-request-failed':
        return 'Tidak ada koneksi internet. Periksa jaringanmu!';
      case 'account-exists-with-different-credential':
        return 'Akun sudah ada dengan metode login berbeda.';
      default:
        return 'Terjadi kesalahan. Coba lagi! (Kode: $code)';
    }
  }
}
