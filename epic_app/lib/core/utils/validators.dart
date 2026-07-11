// Validasi form input untuk EPIC
import 'package:epic_app/core/constants/app_strings.dart';

/// Validator untuk semua form input di aplikasi EPIC.
class Validators {
  Validators._();

  /// Validasi email format.
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppStrings.errorEmpty;
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return AppStrings.errorEmailFormat;
    }
    return null;
  }

  /// Validasi password minimal 6 karakter.
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return AppStrings.errorEmpty;
    }
    if (value.length < 6) {
      return AppStrings.errorPasswordShort;
    }
    return null;
  }

  /// Validasi konfirmasi password harus sama.
  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return AppStrings.errorEmpty;
    }
    if (value != password) {
      return AppStrings.errorPasswordMatch;
    }
    return null;
  }

  /// Validasi nama minimal 3 karakter.
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppStrings.errorEmpty;
    }
    if (value.trim().length < 3) {
      return AppStrings.errorNameShort;
    }
    return null;
  }
}
