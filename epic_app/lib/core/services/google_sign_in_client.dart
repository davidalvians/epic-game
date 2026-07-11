// Shared singleton GoogleSignIn untuk seluruh aplikasi EPIC.
//
// HIGH-02 Fix: Sebelumnya AuthRepository dan GeminiTokenService
// masing-masing membuat instance GoogleSignIn baru setiap kali getter
// dipanggil. Dua instance terpisah dapat menyebabkan konflik sesi OAuth.
// Solusi: satu instance kondisi yang dibagi (shared singleton).
import 'package:google_sign_in/google_sign_in.dart';

/// Scope yang dibutuhkan aplikasi EPIC untuk akses Gemini AI per-user.
const _kGeminiScope =
    'https://www.googleapis.com/auth/generative-language.retriever';

/// Singleton GoogleSignIn — dipakai bersama oleh AuthRepository
/// dan GeminiTokenService agar sesi OAuth tidak konflik.
final googleSignInInstance = GoogleSignIn(
  scopes: [
    'email',
    'profile',
    _kGeminiScope,
  ],
);
