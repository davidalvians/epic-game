// Definisi font family dan ukuran teks untuk EPIC
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Semua konfigurasi font yang digunakan di aplikasi EPIC.
class AppFonts {
  AppFonts._();

  /// Font judul/logo - playful, bulat, cocok untuk anak-anak
  static const String heading = 'FredokaOne';

  /// Font body/UI - ramah, mudah dibaca anak SD
  static const String body = 'Nunito';

  /// Ukuran font minimum (aksesibilitas anak)
  static const double minSize = 14.0;

  /// Ukuran font heading
  static const double sizeH1 = 28.0;
  static const double sizeH2 = 24.0;
  static const double sizeH3 = 20.0;
  static const double sizeH4 = 18.0;

  /// Ukuran font body
  static const double sizeBody = 16.0;
  static const double sizeBodySmall = 14.0;
  static const double sizeCaption = 12.0;

  /// Ukuran font tombol
  static const double sizeButton = 16.0;

  /// Ukuran font badge
  static const double sizeBadge = 11.0;

  /// TextStyle heading menggunakan Google Fonts (Fredoka One)
  static TextStyle heading1({Color? color}) => GoogleFonts.fredoka(
        fontSize: sizeH1,
        fontWeight: FontWeight.w700,
        color: color,
      );

  static TextStyle heading2({Color? color}) => GoogleFonts.fredoka(
        fontSize: sizeH2,
        fontWeight: FontWeight.w700,
        color: color,
      );

  static TextStyle heading3({Color? color}) => GoogleFonts.fredoka(
        fontSize: sizeH3,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle heading4({Color? color}) => GoogleFonts.fredoka(
        fontSize: sizeH4,
        fontWeight: FontWeight.w600,
        color: color,
      );

  /// TextStyle body menggunakan Google Fonts (Nunito)
  static TextStyle bodyText({Color? color, FontWeight? weight}) =>
      GoogleFonts.nunito(
        fontSize: sizeBody,
        fontWeight: weight ?? FontWeight.w400,
        color: color,
      );

  static TextStyle bodySmall({Color? color, FontWeight? weight}) =>
      GoogleFonts.nunito(
        fontSize: sizeBodySmall,
        fontWeight: weight ?? FontWeight.w400,
        color: color,
      );

  static TextStyle caption({Color? color}) => GoogleFonts.nunito(
        fontSize: sizeCaption,
        fontWeight: FontWeight.w400,
        color: color,
      );

  static TextStyle button({Color? color}) => GoogleFonts.nunito(
        fontSize: sizeButton,
        fontWeight: FontWeight.w700,
        color: color,
      );

  static TextStyle badge({Color? color}) => GoogleFonts.nunito(
        fontSize: sizeBadge,
        fontWeight: FontWeight.w700,
        color: color,
      );
}
