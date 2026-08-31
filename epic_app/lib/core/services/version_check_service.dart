// Service untuk memeriksa versi aplikasi dan menampilkan dialog pembaruan
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:epic_app/core/constants/app_colors.dart';
import 'package:epic_app/core/constants/app_fonts.dart';
import 'package:epic_app/core/utils/epic_notification.dart';

class VersionCheckService extends GetxService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String _defaultDownloadUrl =
      'https://epic-app1.web.app/download.html';

  final RxString currentAppVersion = ''.obs;
  final RxString latestAppVersion = ''.obs;
  final RxString minRequiredVersion = ''.obs;
  final RxString releaseNotes = ''.obs;
  final RxString downloadUrl = _defaultDownloadUrl.obs;
  final RxBool isForceUpdate = false.obs;

  bool _isDialogShowing = false;

  @override
  void onInit() {
    super.onInit();
    _initVersionInfo();
  }

  /// Inisialisasi info versi aplikasi lokal
  Future<void> _initVersionInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      currentAppVersion.value = info.version;
      debugPrint('ℹ️ Versi Aplikasi Lokal: ${currentAppVersion.value}');
    } catch (e) {
      debugPrint('⚠️ Gagal mengambil PackageInfo: $e');
      currentAppVersion.value = '1.0.0';
    }
  }

  /// Memeriksa pembaruan dari Firestore (app_config/system_settings)
  Future<void> checkUpdate({bool isManualCheck = false}) async {
    if (_isDialogShowing) return;

    try {
      if (currentAppVersion.value.isEmpty) {
        await _initVersionInfo();
      }

      final doc = await _db.collection('app_config').doc('system_settings').get();
      if (!doc.exists || doc.data() == null) {
        if (isManualCheck) _showUpToDateSnackbar();
        return;
      }

      final data = doc.data()!;
      final latest = data['latestVersion']?.toString() ?? currentAppVersion.value;
      final minReq = data['minRequiredVersion']?.toString() ?? '1.0.0';
      final force = data['forceUpdate'] == true;
      final notes = data['releaseNotes']?.toString() ??
          'Pembaruan fitur terbaru dan peningkatan performa aplikasi.';
      String rawUrl = data['downloadUrl']?.toString().trim() ?? '';
      // Jika URL di database kosong atau masih mengarah langsung ke file .apk, otomatis alihkan ke halaman web download.html
      if (rawUrl.isEmpty || rawUrl.endsWith('.apk')) {
        rawUrl = _defaultDownloadUrl;
      }

      latestAppVersion.value = latest;
      minRequiredVersion.value = minReq;
      isForceUpdate.value = force;
      releaseNotes.value = notes;
      downloadUrl.value = rawUrl;

      final bool hasNewUpdate = isVersionLower(currentAppVersion.value, latest);
      final bool mustForceUpdate = force || isVersionLower(currentAppVersion.value, minReq);

      if (hasNewUpdate) {
        _showUpdateDialog(
          currentVersion: currentAppVersion.value,
          newVersion: latest,
          notes: notes,
          url: downloadUrl.value,
          isForce: mustForceUpdate,
        );
      } else if (isManualCheck) {
        _showUpToDateSnackbar();
      }
    } catch (e) {
      debugPrint('⚠️ Gagal memeriksa pembaruan: $e');
      if (isManualCheck) {
        EpicNotification.error(
          'Pemeriksaan Gagal',
          'Tidak dapat terhubung ke server pembaruan.',
        );
      }
    }
  }

  /// Membandingkan 2 string versi semantik (e.g. 1.0.0 < 1.0.1)
  static bool isVersionLower(String current, String target) {
    if (current.isEmpty || target.isEmpty) return false;
    try {
      final cParts = current.split('.').map((e) => int.tryParse(e.split('-').first) ?? 0).toList();
      final tParts = target.split('.').map((e) => int.tryParse(e.split('-').first) ?? 0).toList();

      while (cParts.length < 3) {
        cParts.add(0);
      }
      while (tParts.length < 3) {
        tParts.add(0);
      }

      for (int i = 0; i < 3; i++) {
        if (cParts[i] < tParts[i]) return true;
        if (cParts[i] > tParts[i]) return false;
      }
      return false;
    } catch (e) {
      debugPrint('⚠️ Error perbandingan versi: $e');
      return false;
    }
  }

  void _showUpToDateSnackbar() {
    EpicNotification.success(
      'Aplikasi Terkini',
      'Kamu sudah menggunakan versi terbaru (${currentAppVersion.value}).',
    );
  }

  /// Menampilkan dialog popup pembaruan aplikasi
  void _showUpdateDialog({
    required String currentVersion,
    required String newVersion,
    required String notes,
    required String url,
    required bool isForce,
  }) {
    _isDialogShowing = true;

    Get.dialog(
      PopScope(
        canPop: !isForce,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) _isDialogShowing = false;
        },
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: AppColors.dark,
          elevation: 16,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.dark,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.secondary.withValues(alpha: 0.15),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header Icon
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.secondary, width: 2),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.rocket_launch_rounded,
                      color: AppColors.secondary,
                      size: 36,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Title
                Text(
                  isForce ? 'Pembaruan Wajib!' : 'Pembaruan Tersedia!',
                  style: AppFonts.heading3(color: AppColors.textOnDark),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // Version comparison chips
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'v$currentVersion',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.arrow_forward_rounded, color: Colors.white54, size: 16),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        'v$newVersion',
                        style: const TextStyle(
                          color: AppColors.secondary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Release Notes Container
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 140),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.cardDark,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.new_releases_outlined, color: AppColors.secondary, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Apa yang Baru:',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          notes,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12.5,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Actions
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: AppColors.dark,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () async {
                          final targetUrl = url.isNotEmpty ? url : _defaultDownloadUrl;
                          final uri = Uri.parse(targetUrl);
                          try {
                            final launched = await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                            if (!launched) {
                              await launchUrl(
                                uri,
                                mode: LaunchMode.platformDefault,
                              );
                            }
                          } catch (e) {
                            debugPrint('⚠️ Error launching update url: $e');
                            try {
                              await launchUrl(
                                uri,
                                mode: LaunchMode.platformDefault,
                              );
                            } catch (e2) {
                              debugPrint('⚠️ Fallback launch error: $e2');
                              EpicNotification.error(
                                'Gagal Membuka Link',
                                'Silakan buka browser dan kunjungi https://epic-app1.web.app/download.html secara manual.',
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.download_rounded, size: 20),
                        label: const Text(
                          'Unduh & Perbarui Sekarang',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    if (!isForce)
                      TextButton(
                        onPressed: () {
                          _isDialogShowing = false;
                          Get.back();
                        },
                        child: Text(
                          'Nanti Saja',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                          ),
                        ),
                      )
                    else
                      TextButton(
                        onPressed: () {
                          SystemNavigator.pop();
                        },
                        child: Text(
                          'Keluar Aplikasi',
                          style: TextStyle(
                            color: Colors.red.shade300,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      barrierDismissible: !isForce,
    ).then((_) {
      _isDialogShowing = false;
    });
  }
}
