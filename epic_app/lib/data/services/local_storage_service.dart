// Wrapper SharedPreferences untuk data lokal/cache
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service untuk penyimpanan data lokal menggunakan SharedPreferences.
class LocalStorageService extends GetxService {
  late SharedPreferences _prefs;

  Future<LocalStorageService> init() async {
    _prefs = await SharedPreferences.getInstance();
    return this;
  }

  // ─── Keys ───────────────────────────────────────────
  static const String keyIsFirstLaunch = 'is_first_launch';
  static const String keyIsLoggedIn = 'is_logged_in';
  static const String keyCachedUser = 'cached_user';
  static const String keyMusicEnabled = 'music_enabled';
  static const String keySoundEnabled = 'sound_enabled';
  static const String keyNotifEnabled = 'notif_enabled';

  // ─── Getters ────────────────────────────────────────
  bool get isFirstLaunch => _prefs.getBool(keyIsFirstLaunch) ?? true;
  bool get isLoggedIn => _prefs.getBool(keyIsLoggedIn) ?? false;
  String? get cachedUser => _prefs.getString(keyCachedUser);
  bool get isMusicEnabled => _prefs.getBool(keyMusicEnabled) ?? true;
  bool get isSoundEnabled => _prefs.getBool(keySoundEnabled) ?? true;
  bool get isNotifEnabled => _prefs.getBool(keyNotifEnabled) ?? true;

  // ─── Setters ────────────────────────────────────────
  Future<bool> setFirstLaunch(bool value) => _prefs.setBool(keyIsFirstLaunch, value);
  Future<bool> setLoggedIn(bool value) => _prefs.setBool(keyIsLoggedIn, value);
  Future<bool> setCachedUser(String value) => _prefs.setString(keyCachedUser, value);
  Future<bool> setMusicEnabled(bool value) => _prefs.setBool(keyMusicEnabled, value);
  Future<bool> setSoundEnabled(bool value) => _prefs.setBool(keySoundEnabled, value);
  Future<bool> setNotifEnabled(bool value) => _prefs.setBool(keyNotifEnabled, value);

  // ─── Clear ──────────────────────────────────────────
  Future<bool> clearAll() => _prefs.clear();
}
