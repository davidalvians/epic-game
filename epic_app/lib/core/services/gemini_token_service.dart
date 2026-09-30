// Service untuk mengelola token OAuth Gemini AI per-user.
// Token diambil dari GoogleSignIn dan HANYA disimpan di memori RAM (tidak ke Firestore).
// Ini aman karena token hanya ada di perangkat murid sendiri.
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:epic_app/core/services/google_sign_in_client.dart';

/// Mengelola akses token Google untuk Generative Language API (Gemini).
///
/// ARSITEKTUR KEAMANAN:
/// - Token OAuth HANYA disimpan di memori RAM (_cachedAccessToken) — tidak pernah ke Firestore.
/// - Token di-reuse selama 50 menit (masa hidup token Google ~1 jam).
/// - Jika expired, signInSilently() otomatis refresh tanpa interaksi user.
/// - Jika signInSilently() gagal, caller harus fallback ke Cloud Function (server API key).
class GeminiTokenService {
  GeminiTokenService._();
  static final GeminiTokenService instance = GeminiTokenService._();

  static const String _geminiScope =
      'https://www.googleapis.com/auth/generative-language.retriever';

  // Digunakan hanya untuk update field `geminiPermission` (boolean, bukan token)
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // HIGH-02 Fix: Pakai shared singleton dari google_sign_in_client.dart
  // agar sesi OAuth tidak konflik dengan AuthRepository.
  GoogleSignIn get _googleSignIn => googleSignInInstance;

  // In-memory cache — hanya hidup selama app berjalan, hilang saat app ditutup
  String? _cachedAccessToken;
  DateTime? _tokenExpiry;
  Future<String?>? _refreshInFlight;

  /// Ambil access token untuk Gemini API.
  ///
  /// Flow:
  /// 1. Jika cache masih valid → return cache (tidak kontak Google)
  /// 2. Jika cache expired/kosong → signInSilently() untuk refresh token
  /// 3. Jika signInSilently() gagal → return null (caller fallback ke server key)
  ///
  /// Token TIDAK pernah disimpan ke Firestore.
  Future<String?> getAccessToken() async {
    // Cek cache RAM — reuse jika masih valid
    if (_cachedAccessToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      debugPrint(
          '✅ GeminiTokenService: Reusing cached token (expires: $_tokenExpiry)');
      return _cachedAccessToken;
    }

    // Beberapa layar dapat meminta token hampir bersamaan pada sesi baru.
    // Gunakan satu proses refresh bersama agar Google Sign-In tidak dipanggil
    // paralel dan menghasilkan token kosong/stale pada permintaan pertama.
    final activeRefresh = _refreshInFlight;
    if (activeRefresh != null) {
      return activeRefresh;
    }

    final refresh = _refreshAccessToken();
    _refreshInFlight = refresh;
    try {
      return await refresh;
    } finally {
      if (identical(_refreshInFlight, refresh)) {
        _refreshInFlight = null;
      }
    }
  }

  Future<String?> _refreshAccessToken() async {
    try {
      // Refresh token secara silent (tanpa popup ke user)
      final googleUser = await _googleSignIn.signInSilently();
      if (googleUser == null) {
        debugPrint(
            '⚠️ GeminiTokenService: signInSilently() returned null — user mungkin belum grant scope');
        return null;
      }

      final auth = await googleUser.authentication;
      final accessToken = auth.accessToken;
      if (accessToken == null || accessToken.isEmpty) {
        debugPrint(
            '⚠️ GeminiTokenService: Google tidak mengembalikan access token');
        return null;
      }
      _cachedAccessToken = accessToken;

      // Token Google OAuth2 valid ~1 jam. Set expiry 50 menit untuk safety margin.
      _tokenExpiry = DateTime.now().add(const Duration(minutes: 50));

      debugPrint(
          '✅ GeminiTokenService: Token di-refresh, valid hingga $_tokenExpiry');
      // CATATAN KEAMANAN: Token TIDAK disimpan ke Firestore.
      // Token hanya ada di RAM perangkat murid ini saja.
      return _cachedAccessToken;
    } catch (e) {
      debugPrint('❌ GeminiTokenService: Gagal mendapatkan access token: $e');
      return null;
    }
  }

  /// Cek apakah user sudah grant Gemini scope.
  Future<bool> hasGeminiPermission() async {
    // Selain memverifikasi izin, simpan token yang sama ke cache RAM agar
    // penilaian karya pertama tidak melakukan autentikasi kedua kalinya.
    return await getAccessToken() != null;
  }

  /// Minta Gemini scope tambahan via Google Sign-In.
  /// Return true jika user menyetujui.
  Future<bool> requestGeminiPermission() async {
    try {
      final googleUser = await _googleSignIn.signInSilently();
      if (googleUser == null) return false;

      // Request scope tambahan
      final granted = await _googleSignIn.requestScopes([_geminiScope]);

      if (granted) {
        // Token sebelum persetujuan scope mungkin belum memuat izin Gemini.
        // Segarkan dan cache token baru sebelum mengizinkan submit berlanjut.
        invalidateAccessToken();
        final accessToken = await getAccessToken();
        if (accessToken == null) {
          debugPrint(
              '❌ Gemini permission diberikan, tetapi token baru belum tersedia');
          return false;
        }

        // Hanya update status boolean (bukan token!) ke Firestore
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          await _db.collection('users').doc(uid).update({
            'geminiPermission': true,
          });
        }
        debugPrint('✅ Gemini permission granted');
      }

      return granted;
    } catch (e) {
      debugPrint('❌ Error requesting Gemini permission: $e');
      return false;
    }
  }

  /// Invalidate cached token (dipanggil saat logout).
  void clearCache() {
    invalidateAccessToken();
    debugPrint('🧹 GeminiTokenService: Cache token dihapus');
  }

  /// Buang token RAM tanpa mengubah sesi Google/Firebase. Digunakan ketika
  /// Gemini menolak token lama agar retry berikutnya mengambil token segar.
  void invalidateAccessToken() {
    _cachedAccessToken = null;
    _tokenExpiry = null;
  }
}
